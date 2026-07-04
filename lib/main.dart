import 'dart:async';
import 'dart:convert';

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
import 'app/window_ipc.dart';
import 'models/prompt_history_entry.dart';
import 'services/auth_service.dart';
import 'services/hive_account_store.dart';
import 'services/hotkey_combo.dart';
import 'services/template_bindings_service.dart';

/// All credentials are injected at build/run time and never committed:
///   flutter run -d macos \
///     --dart-define=GEMINI_API_KEY=your_key \
///     --dart-define=GEMINI_MODEL=gemini-2.5-flash \
///     --dart-define=AZURE_OPENAI_ENDPOINT=https://res.openai.azure.com \
///     --dart-define=AZURE_OPENAI_KEY=your_azure_key
const String kGeminiApiKey = String.fromEnvironment('GEMINI_API_KEY');
const String kGeminiModelName = String.fromEnvironment(
  'GEMINI_MODEL',
  defaultValue: 'gemini-2.5-flash',
);
const String kAzureEndpoint = String.fromEnvironment('AZURE_OPENAI_ENDPOINT');
const String kAzureKey = String.fromEnvironment('AZURE_OPENAI_KEY');
const String kAzureDeployment = String.fromEnvironment(
  'AZURE_OPENAI_DEPLOYMENT',
  defaultValue: 'gpt-4o-mini',
);

/// DEMO-ONLY (see demo_fallback.dart): --dart-define=DEMO_FALLBACK=true
const bool kDemoFallbackEnabled = bool.fromEnvironment('DEMO_FALLBACK');
const bool kMockDataEnabled = bool.fromEnvironment('MOCK_DATA');
const String kMockProjectPath = String.fromEnvironment(
  'MOCK_PROJECT_PATH',
  defaultValue: 'Extra AI Demo Project',
);

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
  if (kMockDataEnabled && !auth.isSignedIn) {
    final registered = await auth.register(
      fullName: 'Extra AI Demo',
      email: 'demo@extra.ai',
      password: 'password123',
      confirm: 'password123',
    );
    if (!registered.ok) {
      await auth.signIn(email: 'demo@extra.ai', password: 'password123');
    }
  }

  final services = await AppServices.create(
    userId: auth.activeUserId ?? '',
    geminiApiKey: kGeminiApiKey,
    geminiModelName: kGeminiModelName,
    azureEndpoint: kAzureEndpoint,
    azureKey: kAzureKey,
    azureDeployment: kAzureDeployment,
    demoFallbackEnabled: kDemoFallbackEnabled,
    mockDataEnabled: kMockDataEnabled,
    mockProjectPath: kMockProjectPath,
  );
  final appState = services.state;
  await appState.normalizeSelectedProject();
  unawaited(appState.runHealthCheck());
  unawaited(appState.refreshBackendSync());

  final flow = MainFlowController(
    auth: auth,
    appState: appState,
    settings: appState.settings!,
  );

  final overlay = _OverlayWindowManager(
    activeUserId: () => auth.activeUserId,
    currentState: () => WindowIpc.encodeState(
      projects: appState.linkedProjects,
      selectedHash: appState.selectedProjectHash,
    ),
  );

  // Main-window IPC handler: the overlay pulls state on startup and reports
  // back analyses/selections (each engine has its own Hive copy — IPC keeps
  // both windows' views consistent within a session).
  await WindowIpc.mainChannel.setMethodCallHandler((call) async {
    switch (call.method) {
      case 'getState':
        return WindowIpc.encodeState(
          projects: appState.linkedProjects,
          selectedHash: appState.selectedProjectHash,
        );
      case 'analysisSaved':
        final entry = PromptHistoryEntry.fromMap(
          Map<String, dynamic>.from(
            jsonDecode(call.arguments as String) as Map,
          ),
        );
        appState.noteExternalAnalysis(entry);
        return null;
      case 'projectSelected':
        await appState.selectProject(call.arguments as String);
        return null;
    }
    return null;
  });

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
      keyDownHandler: (_) {
        debugPrint('[hotkey] analysis hotkey fired → overlay.toggle()');
        overlay.toggle();
      },
    );

    // Quick-template bindings still open the overlay; the prefill is passed
    // through IPC when the overlay window is (re)created.
    for (final entry
        in appState.templateBindings?.all.entries ??
            const Iterable<MapEntry<String, String>>.empty()) {
      final hk = parseCombo(entry.value);
      if (hk == null) continue;
      final template = kQuickTemplates.firstWhere(
        (t) => t.id == entry.key,
        orElse: () => kQuickTemplates.first,
      );
      try {
        await hotKeyManager.register(
          hk,
          keyDownHandler: (_) => overlay.toggle(prefill: template.cannedPrompt),
        );
      } catch (_) {
        // Combo taken by the OS/another app — best-effort.
      }
    }
  }

  await registerHotkeys();

  // Dev aid (--dart-define=OVERLAY_ON_LAUNCH=true): invoke the same code path
  // as the hotkey a moment after startup, so window creation + IPC can be
  // verified end to end without Accessibility permission.
  const overlayOnLaunch = bool.fromEnvironment('OVERLAY_ON_LAUNCH');
  if (overlayOnLaunch) {
    Timer(const Duration(seconds: 3), () {
      debugPrint('[dev] OVERLAY_ON_LAUNCH → overlay.toggle()');
      overlay.toggle();
    });
  }

  runApp(
    MainWindowApp(
      flow: flow,
      auth: auth,
      state: appState,
      onNewAnalysis: () => overlay.toggle(),
      onBindingsChanged: () => unawaited(registerHotkeys()),
    ),
  );
}

/// Creates and toggles the overlay sub-window (Window 2) on demand. The first
/// hotkey press creates it; subsequent presses show/hide it (faster than
/// recreating). Visibility is tracked here since desktop_multi_window 0.3.0
/// has no isVisible(). The active user id is passed so the overlay scopes its
/// Hive data to the signed-in account. A quick-template prefill is handed off
/// via a shared Hive value (robust across engines — both open the same Hive).
class _OverlayWindowManager {
  _OverlayWindowManager({
    required this.activeUserId,
    required this.currentState,
  });

  static const _handoffBox = 'overlay_handoff';
  static const _prefillKey = 'prefill';

  final String? Function() activeUserId;

  /// Encoded project snapshot from the main window, pushed on every show so a
  /// hidden overlay never re-appears with stale projects/selection.
  final String Function() currentState;

  WindowController? _controller;
  bool _visible = false;

  Future<void> toggle({String? prefill}) async {
    await _writePrefill(prefill);
    if (_controller == null) {
      debugPrint('[overlay-manager] creating overlay window (Window 2)');
      _controller = await WindowController.create(
        WindowConfiguration(
          arguments: WindowArgs.encodeOverlay(activeUserId: activeUserId()),
        ),
      );
      await _controller!.show();
      _visible = true;
      unawaited(_pushState());
      return;
    }
    if (_visible) {
      await _controller!.hide();
      _visible = false;
    } else {
      await _controller!.show();
      _visible = true;
      unawaited(_pushState());
    }
  }

  Future<void> _pushState() async {
    final raw = currentState();
    for (var i = 0; i < 5; i++) {
      try {
        await WindowIpc.overlayChannel.invokeMethod('stateSync', raw);
        debugPrint('[overlay-manager] stateSync pushed to overlay');
        return;
      } catch (_) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
    }
    debugPrint('[overlay-manager] stateSync push failed (channel not ready)');
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
