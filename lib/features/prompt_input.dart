import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../models/analysis_preferences.dart';
import '../theme/app_theme.dart';
import '../understanding/intent_pre_checker.dart';

/// Compact hotkey composer. It keeps the overlay visually quiet: a single
/// floating prompt box with file/project controls and a send affordance.
class PromptInput extends StatefulWidget {
  const PromptInput({
    super.key,
    required this.onAnalyze,
    required this.onPickFiles,
    this.fileCount = 0,
    this.initialText,
    this.projectBrief,
    this.projectControl,
    this.onDismiss,
    this.onInitialTextApplied,
  });

  /// Called with the current rough prompt when Analyze is pressed.
  final void Function(String prompt, AnalysisPreferences preferences) onAnalyze;
  final VoidCallback onPickFiles;
  final int fileCount;

  /// Pre-filled prompt (quick-template hotkeys).
  final String? initialText;

  /// Compact project intelligence line shown when a project folder is active.
  final String? projectBrief;

  /// Optional compact project picker/action supplied by the overlay shell.
  final Widget? projectControl;

  /// Optional close action for the floating overlay.
  final VoidCallback? onDismiss;

  /// Called once after a supplied initial text has been applied to the field.
  final VoidCallback? onInitialTextApplied;

  @override
  State<PromptInput> createState() => _PromptInputState();
}

class _PromptInputState extends State<PromptInput> {
  late final TextEditingController _controller;
  IntentClarity _clarity = IntentClarity.clear;
  String? _validationError;
  bool _deepThink = true;
  bool _visualContext = true;
  bool _autoFileSearch = true;
  bool _securityAudit = true;
  bool _bugAudit = true;
  bool _advancedOpen = false;
  ModelEffort _effort = ModelEffort.balanced;
  ActionMode _actionMode = ActionMode.promptOnly;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText ?? '');
    _controller.addListener(_onChanged);
    _consumeInitialTextIfNeeded(widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PromptInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.initialText;
    if (next != null && next != oldWidget.initialText) {
      _controller.text = next;
      _controller.selection = TextSelection.collapsed(offset: next.length);
      _consumeInitialTextIfNeeded(next);
    }
  }

  void _consumeInitialTextIfNeeded(String? text) {
    if (text == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onInitialTextApplied?.call();
    });
  }

  void _onChanged() {
    setState(() {
      _clarity = IntentPreChecker.check(_controller.text);
      if (_validationError != null && _controller.text.trim().isNotEmpty) {
        _validationError = null;
      }
    });
  }

  void _analyze() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() => _validationError = 'Write what you want to change first.');
      return;
    }
    widget.onAnalyze(text, _preferences);
  }

  AnalysisPreferences get _preferences => AnalysisPreferences(
    effort: _effort,
    actionMode: _actionMode,
    screenContext: _visualContext,
    autoFileSearch: _autoFileSearch,
    securityAudit: _securityAudit,
    bugAudit: _bugAudit,
  );

  @override
  Widget build(BuildContext context) {
    final hasText = _controller.text.trim().isNotEmpty;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, meta: true): _analyze,
        const SingleActivator(LogicalKeyboardKey.enter, control: true):
            _analyze,
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: AnimatedContainer(
              duration: AppTheme.transitionMs,
              curve: AppTheme.easeOut,
              padding: const EdgeInsets.fromLTRB(18, 12, 14, 13),
              foregroundDecoration: _validationError == null
                  ? null
                  : BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: AppTheme.signalRed.withValues(alpha: 0.62),
                      ),
                    ),
              decoration: AppTheme.islandPanel(),
              child: CustomPaint(
                painter: const _IslandGridPainter(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _IslandDragHeader(),
                    const SizedBox(height: 7),
                    TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 3,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _analyze(),
                      style: AppTheme.display(
                        size: 19,
                        weight: FontWeight.w500,
                        color: AppTheme.textPrimary,
                      ),
                      cursorColor: AppTheme.accent,
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: _deepThink
                            ? 'Think deeply...'
                            : 'Tell Extra AI what to fix...',
                        hintStyle: AppTheme.display(
                          size: 19,
                          weight: FontWeight.w500,
                          color: AppTheme.textDim.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                    if (_validationError != null ||
                        _clarity == IntentClarity.veryVague) ...[
                      const SizedBox(height: 6),
                      Text(
                        _validationError ??
                            'This is pretty broad. A bit more detail helps.',
                        style: AppTheme.ui(
                          size: 12,
                          color: _validationError == null
                              ? AppTheme.textSecondary
                              : AppTheme.signalRed,
                        ),
                      ),
                    ],
                    if (widget.projectBrief != null &&
                        widget.projectBrief!.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _ProjectBriefBar(text: widget.projectBrief!),
                    ],
                    const SizedBox(height: 14),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxWidth < 560;
                        return Row(
                          children: [
                            _ComposerIconButton(
                              icon: Icons.attach_file_rounded,
                              tooltip: widget.fileCount > 0
                                  ? '${widget.fileCount} files loaded from the selected project'
                                  : 'Attach files manually',
                              onTap: widget.onPickFiles,
                            ),
                            if (widget.fileCount > 0) ...[
                              const SizedBox(width: 6),
                              _FileCountChip(count: widget.fileCount),
                            ],
                            const SizedBox(width: 7),
                            _ComposerIconButton(
                              icon: Icons.center_focus_weak_rounded,
                              tooltip:
                                  'Screen context: include what is visible on your screen',
                              active: _visualContext,
                              onTap: () => setState(
                                () => _visualContext = !_visualContext,
                              ),
                            ),
                            const SizedBox(width: 7),
                            _ThinkButton(
                              active: _deepThink,
                              showLabel: !compact,
                              onTap: () =>
                                  setState(() => _deepThink = !_deepThink),
                            ),
                            const SizedBox(width: 7),
                            if (widget.projectControl != null)
                              widget.projectControl!
                            else
                              _ComposerIconButton(
                                icon: Icons.folder_open_outlined,
                                tooltip: 'Choose project folder',
                                onTap: widget.onPickFiles,
                              ),
                            const SizedBox(width: 7),
                            _AdvancedToggle(
                              open: _advancedOpen,
                              activeCount: _activeAdvancedCount,
                              onTap: () => setState(
                                () => _advancedOpen = !_advancedOpen,
                              ),
                            ),
                            const Spacer(),
                            if (widget.onDismiss != null) ...[
                              if (!compact)
                                _ComposerIconButton(
                                  icon: Icons.close_rounded,
                                  tooltip: 'Close overlay',
                                  onTap: widget.onDismiss,
                                ),
                              if (!compact) const SizedBox(width: 8),
                            ],
                            _SendButton(hasText: hasText, onTap: _analyze),
                          ],
                        );
                      },
                    ),
                    AnimatedSize(
                      duration: AppTheme.transitionMs,
                      curve: AppTheme.easeOut,
                      alignment: Alignment.topCenter,
                      child: _advancedOpen
                          ? Padding(
                              padding: const EdgeInsets.only(top: 13),
                              child: _AdvancedControls(
                                autoFileSearch: _autoFileSearch,
                                securityAudit: _securityAudit,
                                bugAudit: _bugAudit,
                                effort: _effort,
                                actionMode: _actionMode,
                                onAutoFileSearch: () => setState(
                                  () => _autoFileSearch = !_autoFileSearch,
                                ),
                                onSecurityAudit: () => setState(
                                  () => _securityAudit = !_securityAudit,
                                ),
                                onBugAudit: () =>
                                    setState(() => _bugAudit = !_bugAudit),
                                onEffortChanged: (value) =>
                                    setState(() => _effort = value),
                                onModeChanged: (value) =>
                                    setState(() => _actionMode = value),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  int get _activeAdvancedCount =>
      (_autoFileSearch ? 1 : 0) +
      (_securityAudit ? 1 : 0) +
      (_bugAudit ? 1 : 0) +
      (_effort == ModelEffort.deep ? 1 : 0) +
      (_actionMode != ActionMode.promptOnly ? 1 : 0);
}

class _ProjectBriefBar extends StatelessWidget {
  const _ProjectBriefBar({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message:
          'Project map is rebuilt locally from the selected folder before analysis',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: AppTheme.bgVoid.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.borderSubtle),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.account_tree_outlined,
              size: 15,
              color: AppTheme.signalOrange,
            ),
            const SizedBox(width: 7),
            Text(
              'Project map',
              style: AppTheme.ui(
                size: 11,
                weight: FontWeight.w800,
                color: AppTheme.signalOrange,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.ui(
                  size: 11.5,
                  weight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IslandDragHeader extends StatelessWidget {
  const _IslandDragHeader();

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.move,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanStart: (_) => windowManager.startDragging(),
        child: Tooltip(
          message: 'Drag the Extra AI island',
          child: SizedBox(
            height: 18,
            child: Row(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppTheme.accent.withValues(alpha: 0.24),
                    ),
                  ),
                  child: const Icon(
                    Icons.data_object_rounded,
                    size: 13,
                    color: AppTheme.accent,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'extra.',
                  style: AppTheme.ui(
                    size: 12,
                    weight: FontWeight.w700,
                    color: AppTheme.textSecondary,
                  ),
                ),
                // Empty flexible space keeps the header full-width and
                // draggable, without a visible line after the name.
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IslandGridPainter extends CustomPainter {
  const _IslandGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final paint = Paint()
      ..color = AppTheme.textPrimary.withValues(alpha: 0.035)
      ..strokeWidth = 1;
    const step = 48.0;
    for (var x = step; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = step; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    final glow = Paint()
      ..shader =
          RadialGradient(
            colors: [
              AppTheme.accent.withValues(alpha: 0.11),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(
              center: size.center(Offset.zero),
              radius: size.width * 0.7,
            ),
          );
    canvas.drawRect(Offset.zero & size, glow);
  }

  @override
  bool shouldRepaint(covariant _IslandGridPainter oldDelegate) => false;
}

class _ComposerIconButton extends StatelessWidget {
  const _ComposerIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppTheme.accent : AppTheme.textDim;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: InkResponse(
          onTap: onTap,
          radius: 20,
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
                    ? AppTheme.accent.withValues(alpha: 0.65)
                    : Colors.transparent,
              ),
            ),
            child: Icon(icon, size: 19, color: color),
          ),
        ),
      ),
    );
  }
}

class _AdvancedToggle extends StatelessWidget {
  const _AdvancedToggle({
    required this.open,
    required this.activeCount,
    required this.onTap,
  });

  final bool open;
  final int activeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: open
          ? 'Hide advanced controls'
          : 'Show effort, access, bug and security controls',
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        child: AnimatedContainer(
          duration: AppTheme.microMs,
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            color: open
                ? AppTheme.accent.withValues(alpha: 0.12)
                : AppTheme.surfaceHigh.withValues(alpha: 0.62),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: open
                  ? AppTheme.accent.withValues(alpha: 0.58)
                  : AppTheme.borderSubtle,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedRotation(
                turns: open ? 0.5 : 0,
                duration: AppTheme.microMs,
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: open ? AppTheme.accent : AppTheme.textSecondary,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.tune_rounded,
                size: 16,
                color: open ? AppTheme.accent : AppTheme.textSecondary,
              ),
              if (activeCount > 0) ...[
                const SizedBox(width: 6),
                Container(
                  height: 18,
                  constraints: const BoxConstraints(minWidth: 18),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '$activeCount',
                    style: AppTheme.ui(
                      size: 10,
                      weight: FontWeight.w800,
                      color: AppTheme.onAccent,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AdvancedControls extends StatelessWidget {
  const _AdvancedControls({
    required this.autoFileSearch,
    required this.securityAudit,
    required this.bugAudit,
    required this.effort,
    required this.actionMode,
    required this.onAutoFileSearch,
    required this.onSecurityAudit,
    required this.onBugAudit,
    required this.onEffortChanged,
    required this.onModeChanged,
  });

  final bool autoFileSearch;
  final bool securityAudit;
  final bool bugAudit;
  final ModelEffort effort;
  final ActionMode actionMode;
  final VoidCallback onAutoFileSearch;
  final VoidCallback onSecurityAudit;
  final VoidCallback onBugAudit;
  final ValueChanged<ModelEffort> onEffortChanged;
  final ValueChanged<ActionMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.bgVoid.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'Agent controls',
                  style: AppTheme.ui(
                    size: 11,
                    weight: FontWeight.w800,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 1,
                    color: AppTheme.borderSubtle.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _LabeledToggle(
                  icon: Icons.manage_search_rounded,
                  label: 'Files',
                  active: autoFileSearch,
                  tooltip:
                      'Auto file search: scan related files in the selected project folder',
                  onTap: onAutoFileSearch,
                ),
                _LabeledToggle(
                  icon: Icons.shield_outlined,
                  label: 'Security',
                  active: securityAudit,
                  tooltip:
                      'Security audit: check exposed secrets and unsafe patterns',
                  onTap: onSecurityAudit,
                ),
                _LabeledToggle(
                  icon: Icons.bug_report_outlined,
                  label: 'Bugs',
                  active: bugAudit,
                  tooltip:
                      'Bug audit: look for visual, responsive, and logic regressions',
                  onTap: onBugAudit,
                ),
                _EffortMenu(value: effort, onChanged: onEffortChanged),
                _ModeMenu(value: actionMode, onChanged: onModeChanged),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LabeledToggle extends StatelessWidget {
  const _LabeledToggle({
    required this.icon,
    required this.label,
    required this.active,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: AnimatedContainer(
          duration: AppTheme.microMs,
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: active
                ? AppTheme.accent.withValues(alpha: 0.12)
                : AppTheme.surfaceHigh.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: active
                  ? AppTheme.accent.withValues(alpha: 0.55)
                  : AppTheme.borderSubtle,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: active ? AppTheme.accent : AppTheme.textDim,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTheme.ui(
                  size: 12,
                  weight: FontWeight.w700,
                  color: active ? AppTheme.accent : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EffortMenu extends StatelessWidget {
  const _EffortMenu({required this.value, required this.onChanged});

  final ModelEffort value;
  final ValueChanged<ModelEffort> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ModelEffort>(
      tooltip: 'Model effort: choose speed vs deeper reasoning',
      color: AppTheme.surfaceHigh,
      position: PopupMenuPosition.under,
      onSelected: onChanged,
      itemBuilder: (context) => [
        _effortItem(
          ModelEffort.fast,
          'Fast',
          'Shortest wait, lighter analysis',
        ),
        _effortItem(
          ModelEffort.balanced,
          'Balanced',
          'Best default for most UI/code fixes',
        ),
        _effortItem(
          ModelEffort.deep,
          'Deep',
          'More context and stricter checks',
        ),
      ],
      child: _ControlPill(
        icon: Icons.speed_rounded,
        label: switch (value) {
          ModelEffort.fast => 'Fast',
          ModelEffort.balanced => 'Balanced',
          ModelEffort.deep => 'Deep',
        },
      ),
    );
  }

  PopupMenuItem<ModelEffort> _effortItem(
    ModelEffort value,
    String label,
    String description,
  ) {
    return PopupMenuItem(
      value: value,
      child: _MenuText(label: label, description: description),
    );
  }
}

class _ModeMenu extends StatelessWidget {
  const _ModeMenu({required this.value, required this.onChanged});

  final ActionMode value;
  final ValueChanged<ActionMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ActionMode>(
      tooltip: 'Agent mode: choose how the generated prompt should act',
      color: AppTheme.surfaceHigh,
      position: PopupMenuPosition.under,
      onSelected: onChanged,
      itemBuilder: (context) => [
        _modeItem(
          ActionMode.promptOnly,
          'Prompt',
          'Copy-ready instruction for any AI coding tool',
        ),
        _modeItem(
          ActionMode.fullAccess,
          'Full access',
          'Ask the coding agent to inspect related files first',
        ),
        _modeItem(
          ActionMode.autoEdit,
          'Auto edit',
          'Ask the coding agent to edit directly and run checks',
        ),
      ],
      child: _ControlPill(
        icon: Icons.tune_rounded,
        label: switch (value) {
          ActionMode.promptOnly => 'Prompt',
          ActionMode.fullAccess => 'Full',
          ActionMode.autoEdit => 'Auto',
        },
      ),
    );
  }

  PopupMenuItem<ActionMode> _modeItem(
    ActionMode value,
    String label,
    String description,
  ) {
    return PopupMenuItem(
      value: value,
      child: _MenuText(label: label, description: description),
    );
  }
}

class _ControlPill extends StatelessWidget {
  const _ControlPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTheme.ui(
              size: 12,
              weight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuText extends StatelessWidget {
  const _MenuText({required this.label, required this.description});

  final String label;
  final String description;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 230),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTheme.ui(size: 13, weight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(
            description,
            style: AppTheme.ui(size: 11, color: AppTheme.textDim),
          ),
        ],
      ),
    );
  }
}

class _ThinkButton extends StatelessWidget {
  const _ThinkButton({
    required this.active,
    required this.onTap,
    this.showLabel = true,
  });

  final bool active;
  final VoidCallback onTap;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Think mode',
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: AnimatedContainer(
          duration: AppTheme.microMs,
          height: 32,
          padding: EdgeInsets.symmetric(horizontal: active ? 12 : 7),
          decoration: BoxDecoration(
            color: active
                ? AppTheme.accent.withValues(alpha: 0.13)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: active
                  ? AppTheme.accent.withValues(alpha: 0.75)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.psychology_alt_outlined,
                size: 20,
                color: active ? AppTheme.accent : AppTheme.textDim,
              ),
              if (active && showLabel) ...[
                const SizedBox(width: 7),
                Text(
                  'Think',
                  style: AppTheme.ui(
                    size: 13,
                    weight: FontWeight.w600,
                    color: AppTheme.accent,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.hasText, required this.onTap});

  final bool hasText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Send prompt',
      child: Semantics(
        button: true,
        label: 'Send prompt',
        child: InkResponse(
          onTap: onTap,
          radius: 22,
          child: AnimatedContainer(
            duration: AppTheme.microMs,
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: hasText ? AppTheme.accent : AppTheme.textPrimary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (hasText ? AppTheme.accent : Colors.black).withValues(
                    alpha: hasText ? 0.28 : 0.18,
                  ),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(
              hasText ? Icons.arrow_upward_rounded : Icons.mic_none_rounded,
              size: hasText ? 19 : 21,
              color: AppTheme.onAccent,
            ),
          ),
        ),
      ),
    );
  }
}

class _FileCountChip extends StatelessWidget {
  const _FileCountChip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Text(
        '$count',
        style: AppTheme.ui(
          size: 12,
          weight: FontWeight.w700,
          color: AppTheme.accent,
        ),
      ),
    );
  }
}
