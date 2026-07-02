import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'dart:async';

import 'app/app_state.dart';
import 'app/overlay_root.dart';
import 'services/azure_openai_client.dart';
import 'services/gemini_service.dart';
import 'services/health_check_service.dart';
import 'services/history_service.dart';
import 'services/knowledge_base_service.dart';
import 'services/profile_service.dart';
import 'services/project_context_service.dart';
import 'services/verification_service.dart';
import 'theme/app_theme.dart';

/// All credentials are injected at build/run time and never committed:
///   flutter run -d macos \
///     --dart-define=GEMINI_API_KEY=your_key \
///     --dart-define=AZURE_OPENAI_ENDPOINT=https://res.openai.azure.com \
///     --dart-define=AZURE_OPENAI_KEY=your_azure_key
const String _geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');
const String _azureEndpoint = String.fromEnvironment('AZURE_OPENAI_ENDPOINT');
const String _azureKey = String.fromEnvironment('AZURE_OPENAI_KEY');
const String _azureDeployment = String.fromEnvironment(
  'AZURE_OPENAI_DEPLOYMENT',
  defaultValue: 'gpt-4o-mini',
);

/// DEMO-ONLY (see demo_fallback.dart): --dart-define=DEMO_FALLBACK=true
const bool _demoFallbackEnabled = bool.fromEnvironment('DEMO_FALLBACK');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- Window: full-screen, transparent, always-on-top overlay -------------
  await windowManager.ensureInitialized();
  const windowOptions = WindowOptions(
    backgroundColor: Colors.transparent,
    skipTaskbar: true,
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: false,
    alwaysOnTop: true,
    fullScreen: true,
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setAsFrameless();
    await windowManager.setBackgroundColor(Colors.transparent);
    await windowManager.setAlwaysOnTop(true);
    await windowManager.setSkipTaskbar(true);
  });

  // --- Local storage --------------------------------------------------------
  await Hive.initFlutter();
  final profileBox = await Hive.openBox(ProfileService.boxName);
  final projectBox = await Hive.openBox(ProjectContextService.boxName);
  final historyBox = await Hive.openBox(HiveHistoryStore.boxName);

  // --- Knowledge base (bundled, loaded once) --------------------------------
  await KnowledgeBaseService.loadAll();

  // --- Services + app state -------------------------------------------------
  final geminiModel = GeminiPromptModel(apiKey: _geminiApiKey);
  final critic = AzureOpenAIClient(
    endpoint: _azureEndpoint,
    apiKey: _azureKey,
    deployment: _azureDeployment,
  );
  final appState = AppState(
    profileService: ProfileService(profileBox),
    projectService: ProjectContextService(projectBox),
    historyService: HistoryService(store: HiveHistoryStore(historyBox)),
    geminiService: GeminiService(model: geminiModel),
    verificationService: VerificationService(critic: critic),
    healthCheckService: HealthCheckService(
      generatorProbe: _geminiApiKey.isEmpty ? null : geminiModel.healthCheck,
      criticProbe: critic.isConfigured ? critic.healthCheck : null,
    ),
    demoFallbackEnabled: _demoFallbackEnabled,
  );

  // Silent background health probe — a broken key surfaces as a calm amber
  // dot in the window header, never as a mid-demo surprise.
  unawaited(appState.runHealthCheck());

  // --- Global hotkey ⌘⇧E -----------------------------------------------------
  final overlayController = OverlayController(appState);
  await hotKeyManager.unregisterAll();
  final hotKey = HotKey(
    key: PhysicalKeyboardKey.keyE,
    modifiers: [HotKeyModifier.meta, HotKeyModifier.shift],
    scope: HotKeyScope.system,
  );
  await hotKeyManager.register(
    hotKey,
    keyDownHandler: (_) => overlayController.toggle(),
  );

  // Dev aid: show the overlay immediately on launch (for screenshots / manual
  // review) without needing the global hotkey + accessibility permission.
  const showOnLaunch = bool.fromEnvironment('SHOW_ON_LAUNCH');
  if (showOnLaunch) {
    await overlayController.show();
  }

  runApp(ExtraAIApp(state: appState, controller: overlayController));
}

/// Owns the show/hide state of the overlay window and syncs it to
/// window_manager. Kept separate from AppState so AppState stays testable
/// without a real window.
class OverlayController extends ChangeNotifier {
  OverlayController(
    this._state, {
    Future<void> Function()? showWindow,
    Future<void> Function()? hideWindow,
  })  : _showWindow = showWindow ?? _defaultShow,
        _hideWindow = hideWindow ?? _defaultHide;

  final AppState _state;
  final Future<void> Function() _showWindow;
  final Future<void> Function() _hideWindow;

  bool _visible = false;
  bool get visible => _visible;

  static Future<void> _defaultShow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  static Future<void> _defaultHide() => windowManager.hide();

  Future<void> toggle() => _visible ? hide() : show();

  Future<void> show() async {
    _visible = true;
    notifyListeners();
    await _showWindow();
  }

  Future<void> hide() async {
    _visible = false;
    // Return to the input view for next time (unless onboarding is pending).
    if (_state.view != OverlayView.onboarding) _state.showInput();
    notifyListeners();
    await _hideWindow();
  }
}

class ExtraAIApp extends StatelessWidget {
  const ExtraAIApp({super.key, required this.state, required this.controller});

  final AppState state;
  final OverlayController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Extra AI',
      theme: AppTheme.dark,
      home: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          // The window itself is hidden when not visible; render nothing.
          if (!controller.visible) {
            return const ColoredBox(color: Colors.transparent);
          }
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: _EscapeToClose(
              onEscape: controller.hide,
              child: OverlayRoot(
                state: state,
                onDismiss: controller.hide,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Wraps the overlay so pressing Escape dismisses it.
class _EscapeToClose extends StatelessWidget {
  const _EscapeToClose({required this.child, required this.onEscape});

  final Widget child;
  final VoidCallback onEscape;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          onEscape();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: child,
    );
  }
}
