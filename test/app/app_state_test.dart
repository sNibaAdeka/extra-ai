import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:extra_ai/app/app_state.dart';
import 'package:extra_ai/models/extra_ai_response.dart';
import 'package:extra_ai/models/user_profile.dart';
import 'package:extra_ai/services/gemini_service.dart';
import 'package:extra_ai/services/history_service.dart';
import 'package:extra_ai/services/knowledge_base_service.dart';
import 'package:extra_ai/services/profile_service.dart';
import 'package:extra_ai/services/project_context_service.dart';

class _FakeModel implements PromptModel {
  _FakeModel(this.response);
  final String response;
  int calls = 0;
  @override
  Future<String?> generate(String prompt, {List<int>? screenshotBytes}) async {
    calls++;
    return response;
  }
}

UserProfile _profile() => UserProfile(
      experienceLevel: ExperienceLevel.developer,
      primaryTools: const ['Cursor'],
      projectFocus: ProjectFocus.saas,
      tonePreference: ToneLevel.technical,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  late Box profileBox;
  late Box projectBox;

  setUpAll(() async {
    Hive.init('${Directory.systemTemp.path}/extra_ai_test_hive');
    await KnowledgeBaseService.loadAll(loader: (_) async => '{}');
  });

  setUp(() async {
    profileBox = await Hive.openBox('profile_${DateTime.now().microsecondsSinceEpoch}');
    projectBox = await Hive.openBox('project_${DateTime.now().microsecondsSinceEpoch}');
  });

  tearDown(() async {
    await profileBox.deleteFromDisk();
    await projectBox.deleteFromDisk();
  });

  AppState build({required PromptModel model, bool withProfile = true}) {
    final profiles = ProfileService(profileBox);
    if (withProfile) profiles.save(_profile());
    return AppState(
      profileService: profiles,
      projectService: ProjectContextService(projectBox),
      historyService: HistoryService(store: InMemoryHistoryStore()),
      geminiService: GeminiService(model: model),
    );
  }

  const goodJson =
      '{"improved_prompt": "Do X precisely in @app.js.", "issues": ["a", "b"], "clarifying_question": null}';

  test('starts in onboarding when no profile exists', () {
    final state = build(model: _FakeModel(goodJson), withProfile: false);
    expect(state.view, OverlayView.onboarding);
  });

  test('starts in input when a profile exists', () {
    final state = build(model: _FakeModel(goodJson));
    expect(state.view, OverlayView.input);
  });

  test('completing onboarding moves to the home shell and persists', () async {
    final state = build(model: _FakeModel(goodJson), withProfile: false);
    await state.completeOnboarding(_profile());
    expect(state.view, OverlayView.home);
  });

  test('empty prompt fails with a message, stays on input', () async {
    final state = build(model: _FakeModel(goodJson));
    await state.analyze('   ');
    expect(state.errorMessage, isNotNull);
    expect(state.view, OverlayView.input);
  });

  test('valid analyze produces a response and shows results', () async {
    final model = _FakeModel(goodJson);
    final state = build(model: model);
    state.setFiles({'app.js': 'console.log(1)'}, projectPath: '/p');
    await state.analyze('make the dashboard load faster');
    expect(model.calls, 1);
    expect(state.view, OverlayView.results);
    expect(state.response, isA<ExtraAIResponse>());
    expect(state.response!.improvedPrompt, contains('@app.js'));
  });

  test('records redaction count when files contain a secret', () {
    final state = build(model: _FakeModel(goodJson));
    state.setFiles({'c.js': 'apiKey = "abcdefghijklmnop1234"'});
    expect(state.redactedCount, greaterThanOrEqualTo(1));
    expect(state.fileCount, 1);
  });

  test('invalid Gemini JSON surfaces a friendly error', () async {
    final state = build(model: _FakeModel('not json'));
    state.setFiles({'a.js': 'x'});
    await state.analyze('improve the layout');
    expect(state.view, OverlayView.input);
    expect(state.errorMessage, isNotNull);
  });

  test('settings opens as a modal over the shell and closes back', () {
    final state = build(model: _FakeModel(goodJson));
    expect(state.settingsOpen, isFalse);
    state.openSettings(SettingsTab.profile);
    expect(state.settingsOpen, isTrue);
    expect(state.settingsTab, SettingsTab.profile);
    expect(state.view, OverlayView.home); // modal lives over the shell
    state.closeSettings();
    expect(state.settingsOpen, isFalse);
  });

  test('template hotkey prefills the input view once', () {
    final state = build(model: _FakeModel(goodJson));
    state.startTemplateAnalysis('Run a security check on this code');
    expect(state.view, OverlayView.input);
    expect(state.takePrefillPrompt(), 'Run a security check on this code');
    expect(state.takePrefillPrompt(), isNull); // consumed
  });
}
