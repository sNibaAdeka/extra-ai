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

/// Boots Window 2 — the frameless, transparent, always-on-top hotkey overlay.
/// Runs in its own engine with its own AppState, scoped to [userId] so its
/// Hive data matches the main window.
Future<void> bootstrapOverlayWindow(String userId) async {
  // Make THIS engine's window frameless + transparent + floating.
  const options = WindowOptions(
    backgroundColor: Colors.transparent,
    skipTaskbar: true,
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: false,
    alwaysOnTop: true,
    fullScreen: true,
  );
  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.setAsFrameless();
    await windowManager.setBackgroundColor(Colors.transparent);
    await windowManager.setAlwaysOnTop(true);
    await windowManager.setSkipTaskbar(true);
  });

  final services = await AppServices.create(
    userId: userId,
    geminiApiKey: kGeminiApiKey,
    azureEndpoint: kAzureEndpoint,
    azureKey: kAzureKey,
    azureDeployment: kAzureDeployment,
    demoFallbackEnabled: kDemoFallbackEnabled,
  );
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

  runApp(OverlayWindowApp(state: services.state));
}

/// The overlay's root widget: transparent scaffold hosting [OverlayRoot],
/// with Escape to hide the window.
class OverlayWindowApp extends StatelessWidget {
  const OverlayWindowApp({super.key, required this.state});

  final AppState state;

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
            state: state,
            onDismiss: () => windowManager.hide(),
          ),
        ),
      ),
    );
  }
}
