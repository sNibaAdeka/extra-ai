import 'package:flutter/material.dart';

import '../features/auth/project_linking_screen.dart';
import '../features/auth/registration_screen.dart';
import '../features/onboarding/onboarding_flow.dart';
import '../features/shell/app_shell.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'app_state.dart';
import 'main_flow.dart';

/// Window 1 — the real, normal app window. Routes the user through
/// registration → project linking → onboarding → the dashboard shell, then
/// hosts everything (dashboard, history, templates, settings).
class MainWindowApp extends StatelessWidget {
  const MainWindowApp({
    super.key,
    required this.flow,
    required this.auth,
    required this.state,
    required this.onNewAnalysis,
    this.onBindingsChanged,
  });

  final MainFlowController flow;
  final AuthService auth;
  final AppState state;

  /// Opens the hotkey overlay window (so the user can trigger an analysis
  /// from the "New analysis" affordance without waiting for the hotkey).
  final VoidCallback onNewAnalysis;
  final VoidCallback? onBindingsChanged;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Extra AI',
      theme: AppTheme.dark,
      home: Scaffold(
        backgroundColor: AppTheme.bgVoid,
        body: AnimatedBuilder(
          animation: flow,
          builder: (context, _) {
            switch (flow.stage) {
              case MainStage.auth:
                return RegistrationScreen(
                  auth: auth,
                  onAuthenticated: flow.onAuthenticated,
                );
              case MainStage.linking:
                return ProjectLinkingScreen(
                  projects: state.projectService,
                  onContinue: flow.onLinkingComplete,
                );
              case MainStage.onboarding:
                return Padding(
                  padding: const EdgeInsets.all(40),
                  child: OnboardingFlow(
                    onComplete: (profile) async {
                      await state.completeOnboarding(profile);
                      flow.onOnboardingComplete();
                    },
                    onHotkeyChanged: (combo) =>
                        state.settings?.setHotkeyCombo(combo),
                  ),
                );
              case MainStage.app:
                return AnimatedBuilder(
                  animation: state,
                  builder: (context, _) => AppShell(
                    state: state,
                    onNewAnalysis: onNewAnalysis,
                    onBindingsChanged: onBindingsChanged,
                  ),
                );
            }
          },
        ),
      ),
    );
  }
}
