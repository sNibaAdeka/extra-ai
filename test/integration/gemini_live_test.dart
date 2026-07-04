import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:extra_ai/app/app_state.dart';
import 'package:extra_ai/models/user_profile.dart';
import 'package:extra_ai/services/gemini_service.dart';
import 'package:extra_ai/services/history_service.dart';
import 'package:extra_ai/services/knowledge_base_service.dart';
import 'package:extra_ai/services/profile_service.dart';
import 'package:extra_ai/services/project_context_service.dart';

/// LIVE integration test — hits the real Gemini API through the exact
/// production code path (GeminiService → GeminiPromptModel → JSON validate →
/// history persist). Runs ONLY when a key is injected:
///
///   flutter test test/integration/gemini_live_test.dart \
///     --dart-define=GEMINI_API_KEY=... [--dart-define=GEMINI_MODEL=...]
///
/// Skipped silently in the normal suite (no key → no network calls in CI).
const _apiKey = String.fromEnvironment('GEMINI_API_KEY');
const _model = String.fromEnvironment(
  'GEMINI_MODEL',
  defaultValue: 'gemini-2.5-flash',
);

void main() {
  if (_apiKey.isEmpty) {
    test('live Gemini test skipped (no GEMINI_API_KEY dart-define)', () {});
    return;
  }

  setUpAll(() async {
    Hive.init('${Directory.systemTemp.path}/extra_ai_live_hive');
    await KnowledgeBaseService.loadAll(loader: (_) async => '{}');
  });

  test(
    'real API: analyze returns a valid improved prompt and saves to history',
    () async {
      final n = DateTime.now().microsecondsSinceEpoch;
      final profileBox = await Hive.openBox('lp_$n');
      final projectBox = await Hive.openBox('lc_$n');
      addTearDown(() async {
        await profileBox.deleteFromDisk();
        await projectBox.deleteFromDisk();
      });

      final profiles = ProfileService(profileBox)
        ..save(
          UserProfile(
            experienceLevel: ExperienceLevel.developer,
            primaryTools: const ['Cursor'],
            projectFocus: ProjectFocus.saas,
            tonePreference: ToneLevel.technical,
            createdAt: DateTime(2026, 1, 1),
          ),
        );
      final history = HistoryService(store: InMemoryHistoryStore());

      final state = AppState(
        profileService: profiles,
        projectService: ProjectContextService(projectBox),
        historyService: history,
        geminiService: GeminiService(
          model: GeminiPromptModel(apiKey: _apiKey, modelName: _model),
        ),
      );

      state.setFiles({
        'style.css': '.cta-button { background: gray; color: white; }',
        'index.html':
            '<button class="cta-button">Buy now</button><img src="hero.png">',
      }, projectPath: '/live-test');

      await state.analyze('make the buy button stand out more');

      // Check 7 — a real response came back (not an error, not a hang).
      expect(
        state.errorMessage,
        isNull,
        reason: 'live API returned error: ${state.errorMessage}',
      );
      expect(state.view, OverlayView.results);
      expect(state.response, isNotNull);
      expect(state.response!.improvedPrompt.trim(), isNotEmpty);

      // Check 8 — the result was persisted to history.
      final entries = history.allEntries();
      expect(entries, hasLength(1));
      expect(entries.first.roughPrompt, 'make the buy button stand out more');

      // Surface the actual model output for the verification report.
      // ignore: avoid_print
      print('LIVE improved_prompt => ${state.response!.improvedPrompt}');
      // ignore: avoid_print
      print('LIVE issues => ${state.response!.issues}');
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
