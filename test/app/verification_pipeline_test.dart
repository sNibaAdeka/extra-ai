import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:extra_ai/app/app_state.dart';
import 'package:extra_ai/models/user_profile.dart';
import 'package:extra_ai/services/gemini_service.dart';
import 'package:extra_ai/services/health_check_service.dart';
import 'package:extra_ai/services/history_service.dart';
import 'package:extra_ai/services/knowledge_base_service.dart';
import 'package:extra_ai/services/profile_service.dart';
import 'package:extra_ai/services/project_context_service.dart';
import 'package:extra_ai/services/verification_service.dart';

class _ScriptedGemini implements PromptModel {
  _ScriptedGemini(this.replies);
  final List<String?> replies;
  int calls = 0;

  @override
  Future<String?> generate(String prompt, {List<int>? screenshotBytes}) async {
    final reply = calls < replies.length ? replies[calls] : replies.last;
    calls++;
    return reply;
  }
}

class _ScriptedCritic implements CriticModel {
  _ScriptedCritic({this.reply, this.error});
  final String? reply;
  final Object? error;

  @override
  bool get isConfigured => true;

  @override
  Future<String?> chat(String prompt, {bool jsonMode = true}) async {
    if (error != null) throw error!;
    return reply;
  }
}

UserProfile _profile() => UserProfile(
  experienceLevel: ExperienceLevel.developer,
  primaryTools: const ['Cursor'],
  projectFocus: ProjectFocus.saas,
  tonePreference: ToneLevel.technical,
  createdAt: DateTime(2026, 1, 1),
);

const _goodDraft =
    '{"improved_prompt": "Fix .cta in @style.css.", "issues": ["a"], "clarifying_question": null}';
const _correctedDraft =
    '{"improved_prompt": "Fix .cta-button in @style.css.", "issues": ["a"], "clarifying_question": null}';
const _passVerdict =
    '{"passed": true, "failed_checks": [], "correction_instruction": null}';
const _failVerdict =
    '{"passed": false, "failed_checks": ["1"], "correction_instruction": "Use real class names."}';

void main() {
  late Box profileBox;
  late Box projectBox;

  setUpAll(() async {
    Hive.init('${Directory.systemTemp.path}/extra_ai_verify_test_hive');
    await KnowledgeBaseService.loadAll(loader: (_) async => '{}');
  });

  setUp(() async {
    final n = DateTime.now().microsecondsSinceEpoch;
    profileBox = await Hive.openBox('vp_$n');
    projectBox = await Hive.openBox('vc_$n');
  });

  tearDown(() async {
    await profileBox.deleteFromDisk();
    await projectBox.deleteFromDisk();
  });

  AppState build({
    required PromptModel gemini,
    CriticModel? critic,
    bool demoFallback = false,
  }) {
    final profiles = ProfileService(profileBox)..save(_profile());
    return AppState(
      profileService: profiles,
      projectService: ProjectContextService(projectBox),
      historyService: HistoryService(store: InMemoryHistoryStore()),
      geminiService: GeminiService(model: gemini),
      verificationService: critic == null
          ? null
          : VerificationService(critic: critic),
      demoFallbackEnabled: demoFallback,
    );
  }

  test('critic passes → status verified, draft untouched', () async {
    final state = build(
      gemini: _ScriptedGemini(const [_goodDraft]),
      critic: _ScriptedCritic(reply: _passVerdict),
    );
    state.setFiles({'style.css': '.cta {}'});
    await state.analyze('make the button pop');
    expect(state.view, OverlayView.results);
    expect(state.verification, VerificationStatus.verified);
    expect(state.response!.improvedPrompt, contains('.cta'));
  });

  test(
    'critic flags → one corrective pass → status corrected with fixed draft',
    () async {
      final gemini = _ScriptedGemini(const [_goodDraft, _correctedDraft]);
      final state = build(
        gemini: gemini,
        critic: _ScriptedCritic(reply: _failVerdict),
      );
      state.setFiles({'style.css': '.cta-button {}'});
      await state.analyze('make the button pop');
      expect(gemini.calls, 2); // generation + exactly one corrective pass
      expect(state.verification, VerificationStatus.corrected);
      expect(state.response!.improvedPrompt, contains('.cta-button'));
    },
  );

  test(
    'critic down → degrade gracefully: draft shown, status unavailable',
    () async {
      final state = build(
        gemini: _ScriptedGemini(const [_goodDraft]),
        critic: _ScriptedCritic(error: Exception('azure down')),
      );
      state.setFiles({'style.css': '.cta {}'});
      await state.analyze('make the button pop');
      expect(state.view, OverlayView.results); // never blocked
      expect(state.verification, VerificationStatus.unavailable);
      expect(state.response, isNotNull);
    },
  );

  test(
    'failed correction keeps the original draft (best-effort, honest note)',
    () async {
      final gemini = _ScriptedGemini(const [_goodDraft, 'garbage', 'garbage']);
      final state = build(
        gemini: gemini,
        critic: _ScriptedCritic(reply: _failVerdict),
      );
      state.setFiles({'style.css': '.cta {}'});
      await state.analyze('make the button pop');
      expect(state.verification, VerificationStatus.unavailable);
      expect(state.response!.improvedPrompt, contains('.cta')); // original kept
    },
  );

  test('no critic configured → status skipped, no note', () async {
    final state = build(gemini: _ScriptedGemini(const [_goodDraft]));
    state.setFiles({'style.css': '.cta {}'});
    await state.analyze('make the button pop');
    expect(state.verification, VerificationStatus.skipped);
  });

  test(
    'DEMO-ONLY fallback uses the current request when generation fails entirely',
    () async {
      final state = build(
        gemini: _ScriptedGemini(const [null, null]),
        demoFallback: true,
      );
      state.setFiles({'style.css': '.cta {}'});
      await state.analyze('make the button pop');
      expect(state.view, OverlayView.results);
      expect(state.verification, VerificationStatus.demoFallback);
      expect(state.response!.improvedPrompt, contains('make the button pop'));
      expect(state.response!.issues, isNotEmpty);
    },
  );

  test('health check maps probe results to statuses', () async {
    final checker = HealthCheckService(
      generatorProbe: () async => true,
      criticProbe: () async => false,
    );
    final health = await checker.check();
    expect(health.generator, ServiceStatus.healthy);
    expect(health.critic, ServiceStatus.degraded);
    expect(health.isDegraded, isTrue);

    final unconfigured = await HealthCheckService().check();
    expect(unconfigured.generator, ServiceStatus.unconfigured);
    expect(unconfigured.isDegraded, isFalse);
  });
}
