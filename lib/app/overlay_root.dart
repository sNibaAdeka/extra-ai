import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../features/loading_view.dart';
import '../features/onboarding/onboarding_flow.dart';
import '../features/prompt_input.dart';
import '../features/results_view.dart';
import '../features/shell/app_shell.dart';
import '../overlay/overlay_window.dart';
import '../overlay/screen_border.dart';
import '../theme/app_theme.dart';
import '../widgets/pill_widget.dart';
import 'app_state.dart';

/// The full-screen transparent overlay: breathing border on the edges, the pill
/// top-center, and the floating window on the right whose body follows
/// [AppState.view]. Escape closes; the caller wires the hotkey + window hide.
class OverlayRoot extends StatelessWidget {
  const OverlayRoot({
    super.key,
    required this.state,
    required this.onDismiss,
    this.onBindingsChanged,
  });

  final AppState state;
  final VoidCallback onDismiss;

  /// Re-registers quick-template hotkeys after a binding change (main.dart).
  final VoidCallback? onBindingsChanged;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        return Stack(
          children: [
            // Edge-to-edge breathing border.
            const Positioned.fill(child: ScreenBorder()),

            // Pill, top-center.
            Positioned(
              top: 32,
              left: 0,
              right: 0,
              child: Center(child: PillWidget(onTap: onDismiss)),
            ),

            // Floating window, right side, vertically centered.
            Positioned(
              right: 40,
              top: 0,
              bottom: 0,
              child: Center(child: _window(context)),
            ),

            // Transient error banner.
            if (state.errorMessage != null)
              Positioned(
                bottom: 32,
                left: 0,
                right: 0,
                child: Center(child: _ErrorBanner(state: state)),
              ),

            // Redaction trust notice.
            if (state.redactedCount > 0 && state.view == OverlayView.input)
              Positioned(
                top: 88,
                left: 0,
                right: 0,
                child: Center(child: _RedactionNotice(count: state.redactedCount)),
              ),
          ],
        );
      },
    );
  }

  /// Calm health indicator: amber when a configured service failed its probe,
  /// lime when everything checked out, hidden before the first probe.
  Color? get _statusDotColor {
    final health = state.health;
    if (health.isDegraded) return AppTheme.signalOrange;
    if (health.isHealthy) return AppTheme.accent;
    return null;
  }

  String get _statusTooltip => state.health.isDegraded
      ? 'A service is degraded — results may be limited'
      : 'All services healthy';

  Widget _window(BuildContext context) {
    switch (state.view) {
      case OverlayView.onboarding:
        return OverlayWindow(
          width: 920,
          height: 620,
          child: OnboardingFlow(
            onComplete: state.completeOnboarding,
            onHotkeyChanged: (combo) => state.settings?.setHotkeyCombo(combo),
          ),
        );
      case OverlayView.home:
        return AppShell(
          state: state,
          onNewAnalysis: state.showInput,
          onBindingsChanged: onBindingsChanged,
        );
      case OverlayView.input:
        return OverlayWindow(
          onClose: onDismiss,
          onSettings: state.openSettings,
          onHome: state.showHome,
          statusDotColor: _statusDotColor,
          statusTooltip: _statusTooltip,
          child: PromptInput(
            fileCount: state.fileCount,
            initialText: state.takePrefillPrompt(),
            onPickFiles: () => _pickFiles(context),
            onAnalyze: state.analyze,
          ),
        );
      case OverlayView.loading:
        return OverlayWindow(
          onClose: onDismiss,
          child: LoadingView(
            title: 'Analyzing your code...',
            subtitle: state.loadingSubtitle,
          ),
        );
      case OverlayView.results:
        return OverlayWindow(
          onClose: onDismiss,
          onSettings: state.openSettings,
          onHome: state.showHome,
          statusDotColor: _statusDotColor,
          statusTooltip: _statusTooltip,
          child: ResultsView(
            response: state.response!,
            verificationStatus: state.verification,
            onCopyInsert: onDismiss,
            onEdit: state.showInput,
          ),
        );
    }
  }

  Future<void> _pickFiles(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
    );
    if (result == null) return;

    final raw = <String, String>{};
    for (final file in result.files) {
      final bytes = file.bytes;
      if (bytes == null) continue;
      try {
        // UTF-8 decode (not fromCharCodes) so non-ASCII source — Cyrillic
        // comments, emoji in strings — survives intact.
        raw[file.name] = utf8.decode(bytes, allowMalformed: true);
      } catch (_) {
        continue; // skip binary
      }
    }
    final projectPath =
        result.files.first.path ?? result.files.first.name;
    state.setFiles(raw, projectPath: projectPath);
  }
}

class _RedactionNotice extends StatelessWidget {
  const _RedactionNotice({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_outline, size: 14, color: AppTheme.accent),
          const SizedBox(width: 8),
          Text(
            'Redacted $count potential ${count == 1 ? 'secret' : 'secrets'} — your keys are safe.',
            style: AppTheme.ui(size: 12, color: AppTheme.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: state.dismissError,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.signalOrange.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 16, color: AppTheme.signalOrange),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                state.errorMessage!,
                style: AppTheme.ui(size: 13, color: AppTheme.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
