import 'package:flutter/foundation.dart';

import '../services/auth_service.dart';
import '../services/settings_service.dart';
import 'app_state.dart';

/// The main window's funnel: which gate a user is at on the way into the app.
enum MainStage { auth, linking, onboarding, app }

/// Routes the main app window through registration → project linking →
/// onboarding → the dashboard shell. Separate from [AppState] (which owns the
/// analysis/shell logic) so each concern stays focused and testable.
class MainFlowController extends ChangeNotifier {
  MainFlowController({
    required this.auth,
    required this.appState,
    required this.settings,
  }) {
    _stage = _computeStage();
  }

  final AuthService auth;
  final AppState appState;
  final SettingsService settings;

  late MainStage _stage;
  MainStage get stage => _stage;

  MainStage _computeStage() {
    if (!auth.isSignedIn) return MainStage.auth;
    if (!settings.linkingComplete) return MainStage.linking;
    if (!appState.profiles.hasProfile) return MainStage.onboarding;
    return MainStage.app;
  }

  void _advance() {
    _stage = _computeStage();
    notifyListeners();
  }

  /// Called when registration/sign-in succeeds.
  void onAuthenticated() {
    // A returning, fully-set-up user skips straight to the app.
    _advance();
  }

  /// Called when the linking step finishes (link or skip).
  Future<void> onLinkingComplete() async {
    await settings.setLinkingComplete(true);
    _advance();
  }

  /// Called when onboarding completes (profile saved via AppState).
  void onOnboardingComplete() => _advance();

  /// Sign out returns to the auth gate.
  Future<void> signOut() async {
    await auth.signOut();
    _advance();
  }
}
