import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:extra_ai/app/app_state.dart';
import 'package:extra_ai/main.dart';
import 'package:extra_ai/services/gemini_service.dart';
import 'package:extra_ai/services/history_service.dart';
import 'package:extra_ai/services/knowledge_base_service.dart';
import 'package:extra_ai/services/profile_service.dart';
import 'package:extra_ai/services/project_context_service.dart';

class _NoopModel implements PromptModel {
  @override
  Future<String?> generate(String prompt, {List<int>? screenshotBytes}) async =>
      null;
}

/// OverlayController owns the show/hide visibility that main.dart wires to
/// window_manager. We test its state transitions directly (window_manager
/// calls are no-ops off-platform, so we only assert the visibility flag and
/// that hiding returns the app to the input view).
void main() {
  late Box profileBox;
  late Box projectBox;
  late Box historyBox;

  setUpAll(() async {
    Hive.init('${Directory.systemTemp.path}/extra_ai_ctrl_test_hive');
    await KnowledgeBaseService.loadAll(loader: (_) async => '{}');
  });

  setUp(() async {
    final n = DateTime.now().microsecondsSinceEpoch;
    profileBox = await Hive.openBox('p_$n');
    projectBox = await Hive.openBox('c_$n');
    historyBox = await Hive.openBox('h_$n');
  });

  tearDown(() async {
    await profileBox.deleteFromDisk();
    await projectBox.deleteFromDisk();
    await historyBox.deleteFromDisk();
  });

  AppState buildState() => AppState(
        profileService: ProfileService(profileBox),
        projectService: ProjectContextService(projectBox),
        historyService: HistoryService(store: HiveHistoryStore(historyBox)),
        geminiService: GeminiService(model: _NoopModel()),
      );

  OverlayController buildController(AppState state) => OverlayController(
        state,
        showWindow: () async {},
        hideWindow: () async {},
      );

  test('OverlayController starts hidden', () {
    expect(buildController(buildState()).visible, isFalse);
  });

  test('show() then hide() toggles visibility', () async {
    final controller = buildController(buildState());
    await controller.show();
    expect(controller.visible, isTrue);
    await controller.hide();
    expect(controller.visible, isFalse);
  });

  test('hide() resets the view back to input', () async {
    final state = buildState();
    state.openSettings();
    final controller = buildController(state);
    await controller.hide();
    expect(state.view, OverlayView.input);
  });
}
