import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'package:flutter/services.dart';

import 'app/main_flow.dart';
import 'app/main_window_app.dart';
import 'app/overlay_window_app.dart';
import 'app/services_bundle.dart';
import 'app/window_args.dart';
import 'services/auth_service.dart';
import 'services/hive_account_store.dart';
import 'services/hotkey_combo.dart';
import 'services/template_bindings_service.dart';

/// All credentials are injected at build/run time and never committed:
///   flutter run -d macos \
///     --dart-define=GEMINI_API_KEY=your_key \
///     --dart-define=AZURE_OPENAI_ENDPOINT=https://res.openai.azure.com \
///     --dart-define=AZURE_OPENAI_KEY=your_azure_key
const String kGeminiApiKey = String.fromEnvironment('GEMINI_API_KEY');
const String kAzureEndpoint = String.fromEnvironment('AZURE_OPENAI_ENDPOINT');
const String kAzureKey = String.fromEnvironment('AZURE_OPENAI_KEY');
const String kAzureDeployment = String.fromEnvironment(
  'AZURE_OPENAI_DEPLOYMENT',
  defaultValue: 'gpt-4o-mini',
);

/// DEMO-ONLY (see demo_fallback.dart): --dart-define=DEMO_FALLBACK=true
const bool kDemoFallbackEnabled = bool.fromEnvironment('DEMO_FALLBACK');

/// Entry point for BOTH windows. desktop_multi_window runs this same main() in
/// every engine; each window learns its identity from its launch arguments and
/// branches to the right app. The main app window (Window 1) launches with
/// empty arguments; the overlay (Window 2) is created on demand with encoded
/// [WindowArgs].
Future<void> main(List<String> cmdArgs) async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  final controller = await WindowController.fromCurrentEngine();
  final args = WindowArgs.parse(controller.arguments);

  await Hive.initFlutter();

  switch (args.kind) {
    case WindowKind.main:
      await bootstrapMainWindow();
    case WindowKind.overlay:
      await bootstrapOverlayWindow(args.activeUserId ?? '');
  }
}

/// Boots Window 1 — the normal, titled, resizable app window.
Future<void> bootstrapMainWindow() async {
  const options = WindowOptions(
    size: Size(1100, 720),
    center: true,
    minimumSize: Size(900, 600),
    backgroundColor: AppThemeColors.bgVoid,
    titleBarStyle: TitleBarStyle.normal, // a real window, not the overlay
    title: 'Extra AI',
  );
  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  // Auth is device-local; the account box is shared (not user-scoped) since it
  // stores the session pointer that decides which user's boxes to open.
  final accountsBox = await Hive.openBox(HiveAccountStore.boxName);
  final auth = AuthService(store: HiveAccountStore(accountsBox));

  final services = await AppServices.create(
    userId: auth.activeUserId ?? '',
    geminiApiKey: kGeminiApiKey,
    azureEndpoint: kAzureEndpoint,
    azureKey: kAzureKey,
    azureDeployment: kAzureDeployment,
    demoFallbackEnabled: kDemoFallbackEnabled,
  );
  final appState = services.state;
  unawaited(appState.runHealthCheck());

  final flow = MainFlowController(
    auth: auth,
    appState: appState,
    settings: appState.settings!,
  );

  final overlay = _OverlayWindowManager(
    activeUserId: () => auth.activeUserId,
  );

  Future<void> registerHotkeys() async {
    await hotKeyManager.unregisterAll();
    final analysisCombo =
        parseCombo(appState.settings?.hotkeyCombo ?? '⌘⇧E') ??
            HotKey(
              key: PhysicalKeyboardKey.keyE,
              modifiers: [HotKeyModifier.meta, HotKeyModifier.shift],
              scope: HotKeyScope.system,
            );
    await hotKeyManager.register(
      analysisCombo,
      keyDownHandler: (_) => overlay.toggle(),
    );

    // Quick-template bindings still open the overlay; the prefill is passed
    // through IPC when the overlay window is (re)created.
    for (final entry in appState.templateBindings?.all.entries ??
        const Iterable<MapEntry<String, String>>.empty()) {
      final hk = parseCombo(entry.value);
      if (hk == null) continue;
      final template = kQuickTemplates.firstWhere(
        (t) => t.id == entry.key,
        orElse: () => kQuickTemplates.first,
      );
      try {
        await hotKeyManager.register(hk,
            keyDownHandler: (_) => overlay.toggle(prefill: template.cannedPrompt));
      } catch (_) {
        // Combo taken by the OS/another app — best-effort.
      }
    }
  }

  await registerHotkeys();

  runApp(MainWindowApp(
    flow: flow,
    auth: auth,
    state: appState,
    onNewAnalysis: () => overlay.toggle(),
    onBindingsChanged: () => unawaited(registerHotkeys()),
  ));
}

/// Creates and toggles the overlay sub-window (Window 2) on demand. The first
/// hotkey press creates it; subsequent presses show/hide it (faster than
/// recreating). Visibility is tracked here since desktop_multi_window 0.3.0
/// has no isVisible(). The active user id is passed so the overlay scopes its
/// Hive data to the signed-in account. A quick-template prefill is handed off
/// via a shared Hive value (robust across engines — both open the same Hive).
class _OverlayWindowManager {
  _OverlayWindowManager({required this.activeUserId});

  static const _handoffBox = 'overlay_handoff';
  static const _prefillKey = 'prefill';

  final String? Function() activeUserId;
  WindowController? _controller;
  bool _visible = false;

  Future<void> toggle({String? prefill}) async {
    await _writePrefill(prefill);
    if (_controller == null) {
      _controller = await WindowController.create(
        WindowConfiguration(
          arguments: WindowArgs.encodeOverlay(activeUserId: activeUserId()),
        ),
      );
      await _controller!.show();
      _visible = true;
      return;
    }
    if (_visible) {
      await _controller!.hide();
      _visible = false;
    } else {
      await _controller!.show();
      _visible = true;
    }
  }

  Future<void> _writePrefill(String? prefill) async {
    final box = await Hive.openBox(_handoffBox);
    if (prefill == null) {
      await box.delete(_prefillKey);
    } else {
      await box.put(_prefillKey, prefill);
    }
  }
}

/// Colors referenced at window-config time (before a MaterialApp exists), kept
/// separate from AppTheme to avoid importing Flutter widgets into a const.
class AppThemeColors {
  const AppThemeColors._();
  static const Color bgVoid = Color(0xFF170D12);
}
