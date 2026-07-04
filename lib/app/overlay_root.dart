import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../features/loading_view.dart';
import '../features/prompt_input.dart';
import '../features/results_view.dart';
import '../models/project_context.dart';
import '../overlay/overlay_window.dart';
import '../theme/app_theme.dart';
import 'app_state.dart';

/// Transparent hotkey overlay. The macOS window itself is clear; this root only
/// paints the compact floating surfaces that follow [AppState.view].
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
            Positioned.fill(
              child: Center(
                // Smooth cross-fade + slight rise/scale between input →
                // loading → results, so pressing Enter doesn't snap.
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 340),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.98, end: 1.0)
                          .animate(animation),
                      child: child,
                    ),
                  ),
                  layoutBuilder: (currentChild, previousChildren) => Stack(
                    alignment: Alignment.center,
                    children: [
                      ...previousChildren,
                      // ignore: use_null_aware_elements
                      if (currentChild != null) currentChild,
                    ],
                  ),
                  child: KeyedSubtree(
                    key: ValueKey(state.view),
                    child: _window(context),
                  ),
                ),
              ),
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
                child: Center(
                  child: _RedactionNotice(count: state.redactedCount),
                ),
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
      case OverlayView.input:
        return PromptInput(
          fileCount: state.fileCount,
          initialText: state.prefillPrompt,
          onInitialTextApplied: state.markPrefillPromptApplied,
          projectBrief: state.projectIntelligence?.summary,
          onPickFiles: () => _pickFiles(context),
          onAnalyze: (prompt, preferences) =>
              state.analyze(prompt, preferences: preferences),
          onDismiss: onDismiss,
          projectControl: _ProjectScopeButton(
            projects: state.linkedProjects,
            selected: state.selectedProject,
            statusDotColor: _statusDotColor,
            statusTooltip: _statusTooltip,
            onSelect: state.selectProject,
            onSyncProjects: state.syncDetectedProjects,
            onAddProject: () => _addProject(context),
          ),
        );
      case OverlayView.loading:
        return OverlayWindow(
          onClose: onDismiss,
          width: 600,
          height: 400,
          child: LoadingView(
            title: 'Reading screen context...',
            subtitle: state.loadingSubtitle,
            steps: state.loadingSteps,
            activeStep: state.loadingStepIndex,
          ),
        );
      case OverlayView.results:
        return OverlayWindow(
          onClose: onDismiss,
          statusDotColor: _statusDotColor,
          statusTooltip: _statusTooltip,
          width: 720,
          height: 660,
          child: ResultsView(
            response: state.response!,
            trace: state.analysisTrace,
            auditReport: state.auditReport,
            qualityReport: state.qualityReport,
            verificationStatus: state.verification,
            primaryActionLabel: 'Copy Prompt',
            primaryActionShortcut: '⌘C',
            onCopyInsert: _copyPrompt,
            onEdit: state.editLastPrompt,
          ),
        );
      // The overlay never hosts onboarding or the app shell — those live in
      // the main window (Window 1). Fall back to input defensively.
      case OverlayView.onboarding:
      case OverlayView.home:
        return PromptInput(
          fileCount: state.fileCount,
          initialText: state.prefillPrompt,
          onInitialTextApplied: state.markPrefillPromptApplied,
          projectBrief: state.projectIntelligence?.summary,
          projectControl: _ProjectScopeButton(
            projects: state.linkedProjects,
            selected: state.selectedProject,
            onSelect: state.selectProject,
            onSyncProjects: state.syncDetectedProjects,
            onAddProject: () => _addProject(context),
          ),
          onPickFiles: () => _pickFiles(context),
          onAnalyze: (prompt, preferences) =>
              state.analyze(prompt, preferences: preferences),
          onDismiss: onDismiss,
        );
    }
  }

  Future<void> _copyPrompt() async {
    final text = state.response?.improvedPrompt;
    if (text == null || text.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
  }

  /// "+ Add new project" from the overlay picker — pick a folder, link it,
  /// and select it as active.
  Future<void> _addProject(BuildContext context) async {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Pick a project folder',
    );
    if (path == null) return;
    await state.linkProject(path);
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
    final projectPath = result.files.first.path ?? result.files.first.name;
    state.setFiles(raw, projectPath: projectPath);
  }
}

class _ProjectScopeButton extends StatelessWidget {
  const _ProjectScopeButton({
    required this.projects,
    required this.selected,
    required this.onSelect,
    required this.onSyncProjects,
    required this.onAddProject,
    this.statusDotColor,
    this.statusTooltip,
  });

  final List<ProjectContext> projects;
  final ProjectContext? selected;
  final ValueChanged<String> onSelect;
  final Future<int> Function() onSyncProjects;
  final VoidCallback onAddProject;
  final Color? statusDotColor;
  final String? statusTooltip;

  @override
  Widget build(BuildContext context) {
    final current = selected ?? (projects.isEmpty ? null : projects.first);
    final tooltip = current == null
        ? 'Choose project folder'
        : 'Project folder: ${current.displayName}';

    return PopupMenuButton<String>(
      tooltip: tooltip,
      color: AppTheme.surfaceHigh,
      elevation: 18,
      constraints: const BoxConstraints(minWidth: 260, maxWidth: 320),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppTheme.borderSubtle),
      ),
      position: PopupMenuPosition.under,
      onSelected: (value) async {
        if (value == '__add__') {
          onAddProject();
        } else if (value == '__sync__') {
          await onSyncProjects();
        } else {
          onSelect(value);
        }
      },
      itemBuilder: (context) => [
        if (projects.isEmpty)
          PopupMenuItem(
            enabled: false,
            child: _ProjectMenuText(
              title: 'No projects linked',
              subtitle: 'Sync Codex / Claude or choose a folder',
            ),
          ),
        for (final p in projects)
          PopupMenuItem(
            value: p.pathHash,
            child: _ProjectMenuRow(
              project: p,
              selected: p.pathHash == current?.pathHash,
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: '__sync__',
          child: const _ProjectActionRow(
            icon: Icons.sync_rounded,
            title: 'Sync Codex / Claude',
            subtitle: 'Refresh projects from local tool history',
          ),
        ),
        PopupMenuItem(
          value: '__add__',
          child: const _ProjectActionRow(
            icon: Icons.create_new_folder_outlined,
            title: 'Choose folder...',
            subtitle: 'Link a project manually',
          ),
        ),
      ],
      child: _ProjectIcon(
        tooltip: tooltip,
        active: current != null,
        statusDotColor: statusDotColor,
        statusTooltip: statusTooltip,
      ),
    );
  }
}

class _ProjectIcon extends StatelessWidget {
  const _ProjectIcon({
    required this.tooltip,
    required this.active,
    this.statusDotColor,
    this.statusTooltip,
  });

  final String tooltip;
  final bool active;
  final Color? statusDotColor;
  final String? statusTooltip;

  @override
  Widget build(BuildContext context) {
    final button = Tooltip(
      message: tooltip,
      child: AnimatedContainer(
        duration: AppTheme.microMs,
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active
              ? AppTheme.accent.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active
                ? AppTheme.accent.withValues(alpha: 0.6)
                : Colors.transparent,
          ),
        ),
        child: Icon(
          Icons.folder_open_outlined,
          size: 19,
          color: active ? AppTheme.accent : AppTheme.textDim,
        ),
      ),
    );

    if (statusDotColor == null) return button;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        button,
        Positioned(
          right: 1,
          top: 2,
          child: Tooltip(
            message: statusTooltip ?? 'Service status',
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: statusDotColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: statusDotColor!.withValues(alpha: 0.55),
                    blurRadius: 7,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProjectMenuRow extends StatelessWidget {
  const _ProjectMenuRow({required this.project, required this.selected});

  final ProjectContext project;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          selected ? Icons.check_circle_rounded : Icons.folder_outlined,
          size: 18,
          color: selected ? AppTheme.accent : AppTheme.textDim,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ProjectMenuText(
            title: project.displayName,
            subtitle: project.detectedStack == 'Unknown'
                ? project.projectPath
                : '${project.detectedStack} · ${project.projectPath}',
          ),
        ),
      ],
    );
  }
}

class _ProjectActionRow extends StatelessWidget {
  const _ProjectActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.accent),
        const SizedBox(width: 10),
        Expanded(
          child: _ProjectMenuText(title: title, subtitle: subtitle),
        ),
      ],
    );
  }
}

class _ProjectMenuText extends StatelessWidget {
  const _ProjectMenuText({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTheme.ui(
            size: 13,
            weight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTheme.ui(size: 11, color: AppTheme.textDim),
        ),
      ],
    );
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
          border: Border.all(
            color: AppTheme.signalOrange.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 16,
              color: AppTheme.signalOrange,
            ),
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
