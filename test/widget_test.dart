import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:extra_ai/app/app_state.dart';
import 'package:extra_ai/app/main_flow.dart';
import 'package:extra_ai/app/window_args.dart';
import 'package:extra_ai/models/user_profile.dart';
import 'package:extra_ai/services/auth_service.dart';
import 'package:extra_ai/services/gemini_service.dart';
import 'package:extra_ai/services/history_service.dart';
import 'package:extra_ai/services/knowledge_base_service.dart';
import 'package:extra_ai/services/profile_service.dart';
import 'package:extra_ai/services/project_context_service.dart';
import 'package:extra_ai/services/settings_service.dart';

class _NoopModel implements PromptModel {
  @override
  Future<String?> generate(String prompt, {List<int>? screenshotBytes}) async =>
      null;
}

UserProfile _profile() => UserProfile(
  experienceLevel: ExperienceLevel.developer,
  primaryTools: const ['Cursor'],
  projectFocus: ProjectFocus.saas,
  tonePreference: ToneLevel.technical,
  createdAt: DateTime(2026, 1, 1),
);

void main() {
  group('WindowArgs', () {
    test('empty arguments → main window', () {
      expect(WindowArgs.parse('').kind, WindowKind.main);
    });

    test('encodes and parses the overlay window with a user id', () {
      final raw = WindowArgs.encodeOverlay(activeUserId: 'u_abc');
      final parsed = WindowArgs.parse(raw);
      expect(parsed.kind, WindowKind.overlay);
      expect(parsed.activeUserId, 'u_abc');
    });

    test('malformed arguments fall back to main', () {
      expect(WindowArgs.parse('{not json').kind, WindowKind.main);
    });
  });

  group('MainFlowController stage routing', () {
    late Box profileBox;
    late Box projectBox;
    late Box settingsBox;

    setUpAll(() async {
      Hive.init('${Directory.systemTemp.path}/extra_ai_flow_test_hive');
      await KnowledgeBaseService.loadAll(loader: (_) async => '{}');
    });

    setUp(() async {
      final n = DateTime.now().microsecondsSinceEpoch;
      profileBox = await Hive.openBox('fp_$n');
      projectBox = await Hive.openBox('fc_$n');
      settingsBox = await Hive.openBox('fs_$n');
    });

    tearDown(() async {
      await profileBox.deleteFromDisk();
      await projectBox.deleteFromDisk();
      await settingsBox.deleteFromDisk();
    });

    MainFlowController build({bool withProfile = false}) {
      final profiles = ProfileService(profileBox);
      if (withProfile) profiles.save(_profile());
      final settings = SettingsService(settingsBox);
      final state = AppState(
        profileService: profiles,
        projectService: ProjectContextService(projectBox),
        historyService: HistoryService(store: InMemoryHistoryStore()),
        geminiService: GeminiService(model: _NoopModel()),
        settings: settings,
      );
      final auth = AuthService(store: InMemoryAccountStore());
      return MainFlowController(
        auth: auth,
        appState: state,
        settings: settings,
      );
    }

    test('signed-out user starts at the auth gate', () {
      expect(build().stage, MainStage.auth);
    });

    test('advances auth → linking → onboarding → app', () async {
      final flow = build();
      await flow.auth.register(
        fullName: 'Ada',
        email: 'ada@x.com',
        password: 'password1',
        confirm: 'password1',
      );
      flow.onAuthenticated();
      expect(flow.stage, MainStage.linking);

      await flow.onLinkingComplete();
      expect(flow.stage, MainStage.onboarding);

      await flow.appState.completeOnboarding(_profile());
      flow.onOnboardingComplete();
      expect(flow.stage, MainStage.app);
    });

    test('a fully set-up returning user lands straight in the app', () async {
      final flow = build(withProfile: true);
      await flow.settings.setLinkingComplete(true);
      await flow.auth.register(
        fullName: 'Ada',
        email: 'ada@x.com',
        password: 'password1',
        confirm: 'password1',
      );
      flow.onAuthenticated();
      expect(flow.stage, MainStage.app);
    });

    test('sign out returns to the auth gate', () async {
      final flow = build(withProfile: true);
      await flow.settings.setLinkingComplete(true);
      await flow.auth.register(
        fullName: 'Ada',
        email: 'ada@x.com',
        password: 'password1',
        confirm: 'password1',
      );
      flow.onAuthenticated();
      await flow.signOut();
      expect(flow.stage, MainStage.auth);
    });
  });
}
