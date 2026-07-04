import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../models/backend_sync_state.dart';
import '../../models/product_health_report.dart';
import '../../models/project_context.dart';
import '../../models/prompt_history_entry.dart';
import '../../theme/app_theme.dart';
import '../../widgets/controls.dart';
import 'week_activity.dart';

/// Screen 4 — Home Dashboard: greeting + stats, weekly activity chart with
/// the Spotlight carousel, and the Recent analyses list (designed empty
/// states everywhere).
class HomeDashboard extends StatelessWidget {
  const HomeDashboard({
    super.key,
    required this.state,
    required this.onOpenEntry,
  });

  final AppState state;
  final ValueChanged<PromptHistoryEntry> onOpenEntry;

  @override
  Widget build(BuildContext context) {
    final entries = state.allHistory();
    final counts = WeekActivity.counts(
      entries.map((e) => e.timestamp).toList(),
    );
    final today = DateTime.now();
    final todayCount = entries
        .where(
          (e) =>
              e.timestamp.year == today.year &&
              e.timestamp.month == today.month &&
              e.timestamp.day == today.day,
        )
        .length;
    final firstName = state.settings?.firstName ?? '';
    final subscription = state.subscriptionState;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Greeting row + persistent hotkey reminder.
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              firstName.isEmpty ? 'Hi there' : 'Hi, $firstName',
              style: AppTheme.display(size: 28, weight: FontWeight.w600),
            ),
            const Spacer(),
            Text(
              'Press ',
              style: AppTheme.ui(size: 12, color: AppTheme.textDim),
            ),
            KeycapBadge.combo(
              state.settings?.hotkeyCombo ?? '⌘⇧E',
              size: KeycapSize.small,
            ),
            Text(
              ' anywhere',
              style: AppTheme.ui(size: 12, color: AppTheme.textDim),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _stat(
              Icons.local_fire_department_outlined,
              '${_streak(entries)} day streak',
            ),
            _dot(),
            _stat(Icons.bolt_outlined, '$todayCount today'),
            _dot(),
            _stat(Icons.history_rounded, '${entries.length} total'),
            _dot(),
            _stat(
              Icons.workspace_premium_outlined,
              '${subscription.tier.label} plan',
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (subscription.remainingAnalyses == 0) ...[
          _UsageLimitBanner(
            planLabel: subscription.tier.label,
            onUpgrade: () => state.openSettings(SettingsTab.plans),
          ),
          const SizedBox(height: 12),
        ],
        _ProductHealthStrip(report: state.productHealthReport),
        const SizedBox(height: 12),
        _ProjectCommandCenter(state: state, onOpenEntry: onOpenEntry),
        const SizedBox(height: 16),

        // 60/40 grid.
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _WeekCard(counts: counts)),
                    const SizedBox(height: 12),
                    const SizedBox(height: 88, child: _SpotlightCarousel()),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 4,
                child: _RecentCard(
                  entries: entries,
                  hotkey: state.settings?.hotkeyCombo ?? '⌘⇧E',
                  onOpenEntry: onOpenEntry,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static Widget _stat(IconData icon, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: AppTheme.textSecondary),
      const SizedBox(width: 4),
      Text(label, style: AppTheme.ui(size: 12, color: AppTheme.textDim)),
    ],
  );

  static Widget _dot() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Text('·', style: AppTheme.ui(size: 12, color: AppTheme.textDim)),
  );

  /// Consecutive days (ending today) with at least one analysis.
  static int _streak(List<PromptHistoryEntry> entries) {
    final days = entries
        .map(
          (e) => DateTime(e.timestamp.year, e.timestamp.month, e.timestamp.day),
        )
        .toSet();
    var streak = 0;
    var cursor = DateTime.now();
    cursor = DateTime(cursor.year, cursor.month, cursor.day);
    while (days.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }
}

class _UsageLimitBanner extends StatelessWidget {
  const _UsageLimitBanner({required this.planLabel, required this.onUpgrade});

  final String planLabel;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.accentSoft.withValues(alpha: 0.18),
            AppTheme.surfaceHigh.withValues(alpha: 0.72),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.accentSoft.withValues(alpha: 0.32)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.accentSoft.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppTheme.accentSoft.withValues(alpha: 0.34),
              ),
            ),
            child: const Icon(
              Icons.workspace_premium_outlined,
              size: 18,
              color: AppTheme.accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "You've used this month's $planLabel analyses",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.ui(size: 13.5, weight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  'Upgrade to keep generating prompts without waiting for the next reset.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.ui(size: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          PressableScale(
            onTap: onUpgrade,
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: AppTheme.brandGradient,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                'Upgrade',
                style: AppTheme.ui(
                  size: 12.5,
                  weight: FontWeight.w800,
                  color: AppTheme.onAccent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductHealthStrip extends StatelessWidget {
  const _ProductHealthStrip({required this.report});

  final ProductHealthReport report;

  @override
  Widget build(BuildContext context) {
    // Understated by design: a small dot + one calm line. When everything is
    // fine it reassures without shouting; when something is degraded it says so
    // in plain language — never raw error codes or internal service names.
    final ok = report.allClear;
    final color = ok ? AppTheme.success : AppTheme.signalOrange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              report.dashboardLine,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.ui(
                size: 12.5,
                weight: FontWeight.w600,
                color: ok ? AppTheme.textSecondary : AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Project command center: linked projects + local quality state.
// -----------------------------------------------------------------------------

class _ProjectCommandCenter extends StatelessWidget {
  const _ProjectCommandCenter({required this.state, required this.onOpenEntry});

  final AppState state;
  final ValueChanged<PromptHistoryEntry> onOpenEntry;

  @override
  Widget build(BuildContext context) {
    final projects = state.linkedProjects;
    final selectedHash = state.selectedProjectHash;
    final entries = state.allHistory();
    final selected = state.selectedProject;
    final selectedProject =
        selected ?? (projects.isEmpty ? null : projects.first);
    final latestSelected = selectedProject == null
        ? null
        : _latestFor(entries, selectedProject.pathHash);
    final sync = state.backendSyncState;
    final otherProjects = selectedProject == null
        ? projects
        : projects
              .where((project) => project.pathHash != selectedProject.pathHash)
              .toList();

    return AnimatedContainer(
      duration: AppTheme.transitionMs,
      curve: AppTheme.easeOut,
      height: 218,
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: AppTheme.card(radius: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.account_tree_outlined,
                size: 17,
                color: AppTheme.signalOrange,
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  'Project command center',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.ui(size: 14, weight: FontWeight.w700),
                ),
              ),
              const Spacer(),
              Text(
                '${projects.length} linked',
                style: AppTheme.ui(size: 11, color: AppTheme.textDim),
              ),
              const SizedBox(width: 8),
              _BackendSyncChip(sync: sync),
              const SizedBox(width: 10),
              Tooltip(
                message: 'Sync Codex and Claude projects',
                child: PressableScale(
                  onTap: () => unawaited(state.syncDetectedProjects()),
                  child: Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: AppTheme.accent.withValues(alpha: 0.28),
                      ),
                    ),
                    child: const Icon(
                      Icons.sync_rounded,
                      size: 16,
                      color: AppTheme.accent,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: projects.isEmpty
                ? const _EmptyProjectCommand()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: AppTheme.transitionMs,
                          switchInCurve: AppTheme.easeOut,
                          switchOutCurve: AppTheme.easeOut,
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0.02, 0),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              ),
                            );
                          },
                          child: _SelectedProjectMap(
                            key: ValueKey(selectedProject!.pathHash),
                            project: selectedProject,
                            summary: state.projectIntelligence?.summary,
                            latest: latestSelected,
                            onOpenLatest: latestSelected == null
                                ? null
                                : () => onOpenEntry(latestSelected),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 42,
                        child: otherProjects.isEmpty
                            ? _SingleProjectStrip(project: selectedProject)
                            : ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: otherProjects.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (context, index) {
                                  final project = otherProjects[index];
                                  final latest = _latestFor(
                                    entries,
                                    project.pathHash,
                                  );
                                  return _ProjectCard(
                                    project: project,
                                    latest: latest,
                                    selected: project.pathHash == selectedHash,
                                    onTap: () => unawaited(
                                      state.selectProject(project.pathHash),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  static PromptHistoryEntry? _latestFor(
    List<PromptHistoryEntry> entries,
    String projectHash,
  ) {
    final filtered =
        entries.where((e) => e.projectPathHash == projectHash).toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return filtered.isEmpty ? null : filtered.first;
  }
}

class _SingleProjectStrip extends StatelessWidget {
  const _SingleProjectStrip({required this.project});

  final ProjectContext project;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        'Only linked project · ${project.projectPath}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTheme.ui(size: 11, color: AppTheme.textDim),
      ),
    );
  }
}

class _BackendSyncChip extends StatelessWidget {
  const _BackendSyncChip({required this.sync});

  final BackendSyncState sync;

  @override
  Widget build(BuildContext context) {
    final color = switch (sync.mode) {
      BackendSyncMode.localOnly => AppTheme.textDim,
      BackendSyncMode.cloudReady => AppTheme.signalOrange,
      BackendSyncMode.cloudConnected => AppTheme.accent,
    };
    final icon = switch (sync.mode) {
      BackendSyncMode.localOnly => Icons.storage_rounded,
      BackendSyncMode.cloudReady => Icons.cloud_sync_outlined,
      BackendSyncMode.cloudConnected => Icons.cloud_done_outlined,
    };
    return Tooltip(
      message:
          '${sync.summary}\nReady adapters: ${sync.adaptersReady.isEmpty ? 'none yet' : sync.adaptersReady.join(', ')}',
      child: Container(
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.24)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(sync.label, style: AppTheme.ui(size: 10.5, color: color)),
          ],
        ),
      ),
    );
  }
}

class _EmptyProjectCommand extends StatelessWidget {
  const _EmptyProjectCommand();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.accent.withValues(alpha: 0.24)),
          ),
          child: const Icon(
            Icons.folder_copy_outlined,
            color: AppTheme.accent,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Sync Codex / Claude or choose a folder to start project memory.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.ui(size: 12, color: AppTheme.textDim),
          ),
        ),
      ],
    );
  }
}

class _SelectedProjectMap extends StatelessWidget {
  const _SelectedProjectMap({
    super.key,
    required this.project,
    required this.summary,
    required this.latest,
    required this.onOpenLatest,
  });

  final ProjectContext project;
  final String? summary;
  final PromptHistoryEntry? latest;
  final VoidCallback? onOpenLatest;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.accentSoft.withValues(alpha: 0.13),
            AppTheme.bgVoid.withValues(alpha: 0.32),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: AppTheme.accent.withValues(alpha: 0.25),
                  ),
                ),
                child: const Icon(
                  Icons.folder_open_rounded,
                  size: 17,
                  color: AppTheme.accent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  project.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.display(size: 19, weight: FontWeight.w700),
                ),
              ),
              if (latest != null) _QualityMiniChip(entry: latest!),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            summary ??
                '${project.detectedStack} · ${project.fileNames.length} files remembered',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.ui(
              size: 12,
              height: 1.25,
              color: AppTheme.textSecondary,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              _ActiveProjectMetric(
                icon: Icons.code_rounded,
                label: project.detectedStack,
              ),
              const SizedBox(width: 8),
              _ActiveProjectMetric(
                icon: Icons.description_outlined,
                label: '${project.fileNames.length} files',
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActiveProjectMetric(
                  icon: Icons.history_rounded,
                  label: latest == null
                      ? 'No analyses yet'
                      : 'Last ${relativeTime(latest!.timestamp)}',
                ),
              ),
              if (onOpenLatest != null)
                Tooltip(
                  message: 'Open latest analysis',
                  child: PressableScale(
                    onTap: onOpenLatest!,
                    child: const Icon(
                      Icons.open_in_new_rounded,
                      size: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActiveProjectMetric extends StatelessWidget {
  const _ActiveProjectMetric({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppTheme.textDim),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.ui(size: 10.5, color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.project,
    required this.latest,
    required this.selected,
    required this.onTap,
  });

  final ProjectContext project;
  final PromptHistoryEntry? latest;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: project.projectPath,
      child: PressableScale(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppTheme.microMs,
          width: 150,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.accent.withValues(alpha: 0.11)
                : AppTheme.surfaceHigh.withValues(alpha: 0.64),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? AppTheme.accent.withValues(alpha: 0.46)
                  : AppTheme.borderSubtle,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.folder_outlined, size: 15, color: AppTheme.textDim),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.ui(
                        size: 11.5,
                        weight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      latest == null
                          ? project.detectedStack
                          : relativeTime(latest!.timestamp),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.ui(size: 10.5, color: AppTheme.textDim),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QualityMiniChip extends StatelessWidget {
  const _QualityMiniChip({required this.entry});

  final PromptHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final status = entry.qualityStatus ?? 'unknown';
    final color = switch (status) {
      'passed' => AppTheme.accent,
      'warning' => AppTheme.signalOrange,
      'failed' => AppTheme.signalRed,
      _ => AppTheme.textDim,
    };
    final icon = switch (status) {
      'passed' => Icons.verified_outlined,
      'warning' => Icons.manage_search_outlined,
      'failed' => Icons.error_outline_rounded,
      _ => Icons.help_outline_rounded,
    };
    return Tooltip(
      message: entry.qualitySummary ?? 'Quality status unavailable',
      child: Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.11),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.32)),
        ),
        child: Icon(icon, size: 13, color: color),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Left card: week chart + Spotlight carousel.
// -----------------------------------------------------------------------------

class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.counts});

  final List<int> counts;

  @override
  Widget build(BuildContext context) {
    final labels = WeekActivity.dayLabels();
    final maxCount = counts
        .fold<int>(0, (m, c) => c > m ? c : m)
        .clamp(1, 1 << 30);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Analyses this week',
                style: AppTheme.ui(size: 14, weight: FontWeight.w600),
              ),
              const Spacer(),
              // Decorative period dropdown (Daily is the only MVP option).
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Row(
                  children: [
                    Text(
                      'Daily',
                      style: AppTheme.ui(
                        size: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.keyboard_arrow_down,
                      size: 14,
                      color: AppTheme.textDim,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < 7; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Bar flexes to the available height (fraction of the
                        // column) so it never overflows a short card.
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(
                                begin: 0,
                                end: (0.08 + 0.92 * (counts[i] / maxCount))
                                    .clamp(0.06, 1.0),
                              ),
                              duration: Duration(milliseconds: 190 + i * 30),
                              curve: AppTheme.easeOut,
                              builder: (context, value, child) {
                                return FractionallySizedBox(
                                  heightFactor: value,
                                  child: child,
                                );
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: counts[i] > 0
                                      ? AppTheme.accentSoft
                                      : AppTheme.textDim.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          labels[i],
                          style: AppTheme.ui(
                            size: 11,
                            weight: i == WeekActivity.todayIndex
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: i == WeekActivity.todayIndex
                                ? AppTheme.accent
                                : AppTheme.textDim,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SpotlightCarousel extends StatefulWidget {
  const _SpotlightCarousel();

  @override
  State<_SpotlightCarousel> createState() => _SpotlightCarouselState();
}

class _SpotlightCarouselState extends State<_SpotlightCarousel> {
  static const _tips = [
    (
      'It remembers your project',
      'Switch from Cursor to Windsurf mid-project — Extra AI still knows '
          'what you already tried.',
      'See how',
    ),
    (
      'Grounded in what you see',
      'Not just your code — Extra AI looks at the actual screenshot too.',
      null,
    ),
    (
      'Security hygiene included',
      'Catches hardcoded keys and common vulnerabilities automatically.',
      null,
    ),
  ];

  int _index = 0;

  void _go(int delta) =>
      setState(() => _index = (_index + delta) % _tips.length);

  @override
  Widget build(BuildContext context) {
    final tip = _tips[_index % _tips.length];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: AppTheme.card(radius: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
            ),
            child: const Icon(
              Icons.tips_and_updates_outlined,
              size: 18,
              color: AppTheme.accent,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: AnimatedSwitcher(
              duration: AppTheme.transitionMs,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.08),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: Column(
                key: ValueKey(_index),
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tip.$1,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.ui(size: 13, weight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tip.$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.ui(
                      size: 11.5,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Row(
            children: [
              for (var i = 0; i < _tips.length; i++)
                Container(
                  width: i == _index ? 14 : 5,
                  height: 5,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: i == _index
                        ? AppTheme.accent
                        : AppTheme.textDim.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 4),
          _arrow(Icons.chevron_left, () => _go(_tips.length - 1)),
          _arrow(Icons.chevron_right, () => _go(1)),
        ],
      ),
    );
  }

  Widget _arrow(IconData icon, VoidCallback onTap) => PressableScale(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.all(2),
      child: Icon(icon, size: 18, color: AppTheme.textDim),
    ),
  );
}

// -----------------------------------------------------------------------------
// Right card: recent analyses.
// -----------------------------------------------------------------------------

class _RecentCard extends StatelessWidget {
  const _RecentCard({
    required this.entries,
    required this.hotkey,
    required this.onOpenEntry,
  });

  final List<PromptHistoryEntry> entries;
  final String hotkey;
  final ValueChanged<PromptHistoryEntry> onOpenEntry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent analyses',
            style: AppTheme.ui(size: 14, weight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: entries.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'No analyses yet',
                          style: AppTheme.display(
                            size: 20,
                            weight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Press ',
                              style: AppTheme.ui(
                                size: 13,
                                color: AppTheme.textDim,
                              ),
                            ),
                            KeycapBadge.combo(hotkey, size: KeycapSize.small),
                            Text(
                              ' to get started',
                              style: AppTheme.ui(
                                size: 13,
                                color: AppTheme.textDim,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: entries.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 14, color: AppTheme.borderSubtle),
                    itemBuilder: (context, i) => _StaggeredListItem(
                      index: i,
                      child: _RecentRow(entry: entries[i], onTap: onOpenEntry),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _StaggeredListItem extends StatelessWidget {
  const _StaggeredListItem({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 170 + index * 40),
      curve: AppTheme.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 4 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.entry, required this.onTap});

  final PromptHistoryEntry entry;
  final ValueChanged<PromptHistoryEntry> onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: () => onTap(entry),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.roughPrompt,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.ui(size: 13),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                relativeTime(entry.timestamp),
                style: AppTheme.ui(size: 11, color: AppTheme.textDim),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            'project ${entry.projectPathHash.substring(0, entry.projectPathHash.length.clamp(0, 6))}',
            style: AppTheme.ui(size: 11, color: AppTheme.textDim),
          ),
          if (entry.qualityStatus != null) ...[
            const SizedBox(height: 4),
            _QualityInline(entry: entry),
          ],
        ],
      ),
    );
  }
}

class _QualityInline extends StatelessWidget {
  const _QualityInline({required this.entry});

  final PromptHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final status = entry.qualityStatus ?? 'unknown';
    final color = switch (status) {
      'passed' => AppTheme.accent,
      'warning' => AppTheme.signalOrange,
      'failed' => AppTheme.signalRed,
      _ => AppTheme.textDim,
    };
    final label = switch (status) {
      'passed' => 'quality passed',
      'warning' => 'needs review',
      'failed' => 'context mismatch',
      _ => 'quality unknown',
    };
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            entry.qualitySummary ?? label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.ui(size: 10.5, color: color),
          ),
        ),
      ],
    );
  }
}

/// "2h ago"-style relative timestamps shared by dashboard + history rows.
String relativeTime(DateTime t, {DateTime? now}) {
  final d = (now ?? DateTime.now()).difference(t);
  if (d.inMinutes < 1) return 'now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  return '${d.inDays}d ago';
}
