import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:window_manager/window_manager.dart';

import '../main.dart';
import '../theme/app_theme.dart';
import 'app_state.dart';
import 'overlay_root.dart';
import 'services_bundle.dart';
import 'window_ipc.dart';

/// Boots Window 2 — the frameless, transparent, always-on-top hotkey overlay.
/// Runs in its own engine with its own AppState, scoped to [userId] so its
/// Hive data matches the main window.
Future<void> bootstrapOverlayWindow(String userId) async {
  // Make THIS engine's window frameless + transparent + floating.
  const options = WindowOptions(
    size: Size(720, 260),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: true,
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: false,
    alwaysOnTop: true,
  );
  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.setAsFrameless();
    await windowManager.setBackgroundColor(Colors.transparent);
    await windowManager.setAlwaysOnTop(true);
    await windowManager.setSkipTaskbar(true);
    await windowManager.setResizable(false);
    await windowManager.setMovable(true);
    await windowManager.center();
  });

  final services = await AppServices.create(
    userId: userId,
    geminiApiKey: kGeminiApiKey,
    geminiModelName: kGeminiModelName,
    azureEndpoint: kAzureEndpoint,
    azureKey: kAzureKey,
    azureDeployment: kAzureDeployment,
    demoFallbackEnabled: kDemoFallbackEnabled,
    mockDataEnabled: kMockDataEnabled,
    mockProjectPath: kMockProjectPath,
  );
  debugPrint('[overlay] engine started (Window 2)');

  // IPC: dual model per the diagnose prompt — the main window PUSHES
  // stateSync on every show, and the overlay PULLS once at startup so it
  // never renders before the initial state arrives.
  final state = services.state;
  await WindowIpc.overlayChannel.setMethodCallHandler((call) async {
    if (call.method == 'stateSync') {
      final decoded = WindowIpc.decodeState(call.arguments as String);
      debugPrint(
        '[overlay] stateSync received '
        '(${decoded.projects.length} projects)',
      );
      state.applyProjectsSnapshot(decoded.projects, decoded.selectedHash);
    }
    return null;
  });
  final pulled = await WindowIpc.fetchStateFromMain();
  if (pulled != null) {
    debugPrint(
      '[overlay] initial state pulled '
      '(${pulled.projects.length} projects)',
    );
    state.applyProjectsSnapshot(pulled.projects, pulled.selectedHash);
    await state.normalizeSelectedProject();
  }

  // Writes flow back to the main window (the single Hive writer for
  // settings/selection) and dashboards learn about new analyses instantly.
  state.remoteSelectionSink = WindowIpc.notifyProjectSelected;
  state.onAnalysisPersisted = WindowIpc.notifyAnalysisSaved;

  // The overlay opens straight into the analysis input (never onboarding —
  // that belongs to Window 1). Pick up any quick-template prefill handed off
  // by the main window via the shared Hive box.
  services.state.showInput();
  final handoff = await Hive.openBox('overlay_handoff');
  final prefill = handoff.get('prefill') as String?;
  if (prefill != null) {
    services.state.startTemplateAnalysis(prefill);
    await handoff.delete('prefill');
  }
  unawaited(services.state.runHealthCheck());
  unawaited(services.state.refreshBackendSync());

  runApp(OverlayWindowApp(state: services.state));
}

/// The overlay's root widget: transparent scaffold hosting [OverlayRoot],
/// with Escape to hide the window.
class OverlayWindowApp extends StatefulWidget {
  const OverlayWindowApp({super.key, required this.state});

  final AppState state;

  @override
  State<OverlayWindowApp> createState() => _OverlayWindowAppState();
}

class _OverlayWindowAppState extends State<OverlayWindowApp> {
  OverlayView? _lastView;
  bool _didInitialPlacement = false;

  @override
  void initState() {
    super.initState();
    widget.state.addListener(_syncWindowSize);
    unawaited(_syncWindowSize());
  }

  @override
  void dispose() {
    widget.state.removeListener(_syncWindowSize);
    super.dispose();
  }

  Future<void> _syncWindowSize() async {
    final view = widget.state.view;
    if (_lastView == view) return;
    _lastView = view;
    final size = switch (view) {
      OverlayView.input => const Size(740, 370),
      OverlayView.loading => const Size(660, 460),
      OverlayView.results => const Size(760, 720),
      OverlayView.onboarding || OverlayView.home => const Size(740, 370),
    };
    await windowManager.setSize(size);
    if (!_didInitialPlacement) {
      _didInitialPlacement = true;
      await windowManager.center();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Extra AI',
      theme: AppTheme.dark,
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: Focus(
          autofocus: true,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.escape) {
              windowManager.hide();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: OverlayRoot(
            state: widget.state,
            onDismiss: () => windowManager.hide(),
          ),
        ),
      ),
    );
  }
}
