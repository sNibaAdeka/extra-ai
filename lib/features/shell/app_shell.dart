import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../models/extra_ai_response.dart';
import '../../models/prompt_history_entry.dart';
import '../../theme/app_theme.dart';
import '../../widgets/controls.dart';
import '../../widgets/logo_mark.dart';
import '../dashboard/home_dashboard.dart';
import '../history/history_screen.dart';
import '../results_view.dart';
import '../settings/settings_modal.dart';
import '../templates/quick_templates_screen.dart';
import 'notifications_panel.dart';

/// The large app surface (Screens 4–13): icon sidebar, top bar with the
/// analyses pill / bell / avatar, section content, the notifications
/// dropdown, the settings modal, and the read-only history detail view.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.state,
    required this.onNewAnalysis,
    this.onBindingsChanged,
  });

  final AppState state;
  final VoidCallback onNewAnalysis;
  final VoidCallback? onBindingsChanged;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _notificationsOpen = false;
  PromptHistoryEntry? _detailEntry;
  int _lastSectionIndex = 0;

  AppState get state => widget.state;

  @override
  Widget build(BuildContext context) {
    final sectionIndex = _sectionIndex(state.shellSection);
    final sectionDirection = sectionIndex >= _lastSectionIndex ? 1.0 : -1.0;
    _lastSectionIndex = sectionIndex;

    // Fills its parent — the shell now lives in the normal main window
    // (Window 1), so it expands to the window size rather than a fixed panel.
    return Container(
      clipBehavior: Clip.antiAlias,
      // Quiet violet field warming toward one corner — the landing hero
      // backdrop, not a flat fill.
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.bgVoid, AppTheme.bgViolet, AppTheme.bgMid],
          stops: [0.0, 0.62, 1.0],
        ),
      ),
      child: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Sidebar(state: state, onNewAnalysis: widget.onNewAnalysis),
              Expanded(
                child: Column(
                  children: [
                    _topBar(),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 240),
                          switchInCurve: AppTheme.easeOut,
                          switchOutCurve: AppTheme.easeOut,
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: Offset(0.012 * sectionDirection, 0),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              ),
                            );
                          },
                          child: KeyedSubtree(
                            key: ValueKey(state.shellSection),
                            child: _sectionBody(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Click-outside barrier + notifications dropdown.
          if (_notificationsOpen) ...[
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _notificationsOpen = false),
              ),
            ),
            Positioned(
              top: 54,
              right: 56,
              child: NotificationsPanel(
                notifications: state.notifications?.all ?? const [],
                onDismiss: (id) async {
                  await state.notifications?.dismiss(id);
                  setState(() {});
                },
                onClearAll: () async {
                  await state.notifications?.clearAll();
                  setState(() {});
                },
              ),
            ),
          ],

          // Read-only history detail (reuses ResultsView, no actions).
          if (_detailEntry != null)
            _modalBarrier(
              onClose: () => setState(() => _detailEntry = null),
              child: Container(
                width: 460,
                height: 520,
                padding: const EdgeInsets.all(18),
                decoration: AppTheme.glassPanel(radius: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _detailEntry!.roughPrompt,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.ui(
                              size: 13,
                              color: AppTheme.textDim,
                            ),
                          ),
                        ),
                        PressableScale(
                          onTap: () => setState(() => _detailEntry = null),
                          child: const Icon(
                            Icons.close,
                            size: 16,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ResultsView(
                        response: ExtraAIResponse(
                          improvedPrompt: _detailEntry!.improvedPrompt,
                          issues: _detailEntry!.issuesFound,
                        ),
                        trace: _detailEntry!.trace,
                        auditReport: _detailEntry!.auditReport,
                        readOnly: true,
                        onCopyInsert: () {},
                        onEdit: () {},
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Settings modal (Escape handled by the overlay root).
          if (state.settingsOpen)
            _modalBarrier(
              onClose: state.closeSettings,
              child: SettingsModal(state: state),
            ),
        ],
      ),
    );
  }

  int _sectionIndex(ShellSection section) => switch (section) {
    ShellSection.home => 0,
    ShellSection.history => 1,
    ShellSection.templates => 2,
  };

  Widget _modalBarrier({required VoidCallback onClose, required Widget child}) {
    return Positioned.fill(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 200),
        curve: AppTheme.easeOut,
        builder: (context, value, _) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onClose,
            child: Container(
              color: Colors.black.withValues(alpha: 0.45 * value),
              alignment: Alignment.center,
              child: GestureDetector(
                onTap: () {},
                child: Opacity(
                  opacity: value,
                  child: Transform.scale(
                    scale: 0.96 + 0.04 * value,
                    child: child,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _topBar() {
    final s = state.settings;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      child: Row(
        children: [
          const Spacer(),
          Tooltip(
            message: 'Notifications',
            child: PressableScale(
              onTap: () =>
                  setState(() => _notificationsOpen = !_notificationsOpen),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.surface,
                      border: Border.all(color: AppTheme.borderSubtle),
                    ),
                    child: const Icon(
                      Icons.notifications_none,
                      size: 17,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  if ((state.notifications?.all ?? const []).isNotEmpty)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: TweenAnimationBuilder<double>(
                        key: ValueKey(state.notifications!.all.length),
                        tween: Tween(begin: 1.15, end: 1),
                        duration: const Duration(milliseconds: 300),
                        curve: AppTheme.easeOut,
                        builder: (context, scale, child) =>
                            Transform.scale(scale: scale, child: child),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppTheme.accent,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${state.notifications!.all.length}',
                            style: AppTheme.ui(
                              size: 8,
                              weight: FontWeight.w700,
                              color: AppTheme.onAccent,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Tooltip(
            message: 'Profile',
            child: PressableScale(
              onTap: () => state.openSettings(SettingsTab.profile),
              child: CircleAvatar(
                radius: 17,
                backgroundColor: Color(s?.avatarColor ?? 0xFFFF6B35),
                child: Text(
                  s?.initials ?? 'EA',
                  style: AppTheme.ui(
                    size: 12,
                    weight: FontWeight.w700,
                    color: AppTheme.onAccent,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionBody() {
    switch (state.shellSection) {
      case ShellSection.home:
        return HomeDashboard(
          state: state,
          onOpenEntry: (e) => setState(() => _detailEntry = e),
        );
      case ShellSection.history:
        return HistoryScreen(
          entries: state.allHistory(),
          favorites: state.favorites!,
          onOpenEntry: (e) => setState(() => _detailEntry = e),
        );
      case ShellSection.templates:
        return QuickTemplatesScreen(
          bindings: state.templateBindings!,
          onBindingsChanged: widget.onBindingsChanged ?? () {},
        );
    }
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.state, required this.onNewAnalysis});

  final AppState state;
  final VoidCallback onNewAnalysis;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: AppTheme.borderSubtle)),
      ),
      child: Column(
        children: [
          const LogoMark(size: 26),
          const SizedBox(height: 22),
          _item(Icons.home_outlined, 'Home', ShellSection.home),
          _item(Icons.history, 'History', ShellSection.history),
          _item(Icons.bolt_outlined, 'Quick Templates', ShellSection.templates),
          const Spacer(),
          Tooltip(
            message: 'New analysis',
            child: PressableScale(
              onTap: onNewAnalysis,
              child: Container(
                width: 38,
                height: 52,
                decoration: BoxDecoration(
                  gradient: AppTheme.brandGradient,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: const Icon(
                  Icons.add,
                  size: 18,
                  color: AppTheme.onAccent,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Tooltip(
            message: 'Settings',
            child: PressableScale(
              onTap: () => state.openSettings(),
              child: const Icon(
                Icons.settings_outlined,
                size: 19,
                color: AppTheme.textDim,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _item(IconData icon, String tooltip, ShellSection section) {
    final active = state.shellSection == section;
    return Tooltip(
      message: tooltip,
      child: PressableScale(
        onTap: () => state.setShellSection(section),
        child: Container(
          width: 40,
          height: 40,
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: active
                ? AppTheme.accent.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: active
                ? Border.all(color: AppTheme.accent.withValues(alpha: 0.4))
                : null,
          ),
          child: Icon(
            icon,
            size: 19,
            color: active ? AppTheme.accent : AppTheme.textDim,
          ),
        ),
      ),
    );
  }
}
