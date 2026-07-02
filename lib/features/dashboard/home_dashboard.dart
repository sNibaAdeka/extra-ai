import 'package:flutter/material.dart';

import '../../app/app_state.dart';
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
    final entries = state.history.allEntries();
    final counts =
        WeekActivity.counts(entries.map((e) => e.timestamp).toList());
    final today = DateTime.now();
    final todayCount = entries
        .where((e) =>
            e.timestamp.year == today.year &&
            e.timestamp.month == today.month &&
            e.timestamp.day == today.day)
        .length;
    final firstName = state.settings?.firstName ?? '';

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
            Text('Press ',
                style: AppTheme.ui(size: 12, color: AppTheme.textDim)),
            KeycapBadge.combo(
              state.settings?.hotkeyCombo ?? '⌘⇧E',
              size: KeycapSize.small,
            ),
            Text(' anywhere',
                style: AppTheme.ui(size: 12, color: AppTheme.textDim)),
          ],
        ),
        const SizedBox(height: 6),
        Row(children: [
          _stat('🔥', '${_streak(entries)} day streak'),
          _dot(),
          _stat('⚡', '$todayCount today'),
          _dot(),
          _stat('🕐', '${entries.length} total'),
        ]),
        const SizedBox(height: 20),

        // 60/40 grid.
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 6,
                child: _WeekCard(counts: counts),
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

  static Widget _stat(String icon, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(label, style: AppTheme.ui(size: 12, color: AppTheme.textDim)),
        ],
      );

  static Widget _dot() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child:
            Text('·', style: AppTheme.ui(size: 12, color: AppTheme.textDim)),
      );

  /// Consecutive days (ending today) with at least one analysis.
  static int _streak(List<PromptHistoryEntry> entries) {
    final days = entries
        .map((e) =>
            DateTime(e.timestamp.year, e.timestamp.month, e.timestamp.day))
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

// -----------------------------------------------------------------------------
// Left card: week chart + Spotlight carousel.
// -----------------------------------------------------------------------------

class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.counts});

  final List<int> counts;

  @override
  Widget build(BuildContext context) {
    final labels = WeekActivity.dayLabels();
    final maxCount =
        counts.fold<int>(0, (m, c) => c > m ? c : m).clamp(1, 1 << 30);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Analyses this week',
                  style: AppTheme.ui(size: 14, weight: FontWeight.w600)),
              const Spacer(),
              // Decorative period dropdown (Daily is the only MVP option).
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Row(children: [
                  Text('Daily',
                      style: AppTheme.ui(
                          size: 12, color: AppTheme.textSecondary)),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down,
                      size: 14, color: AppTheme.textDim),
                ]),
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
                        AnimatedContainer(
                          duration: AppTheme.transitionMs,
                          height: 6 + 80.0 * (counts[i] / maxCount),
                          decoration: BoxDecoration(
                            color: counts[i] > 0
                                ? AppTheme.accent
                                : AppTheme.textDim.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
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
          const SizedBox(height: 18),
          const _SpotlightCarousel(),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('✦ SPOTLIGHT',
                style: AppTheme.sectionLabel()
                    .copyWith(color: AppTheme.accent)),
            const Spacer(),
            Row(children: [
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
            ]),
            const SizedBox(width: 6),
            _arrow(Icons.chevron_left, () => _go(_tips.length - 1)),
            _arrow(Icons.chevron_right, () => _go(1)),
          ],
        ),
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: AppTheme.transitionMs,
          child: Column(
            key: ValueKey(_index),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tip.$1,
                  style: AppTheme.display(size: 17, weight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(tip.$2,
                  style: AppTheme.ui(
                      size: 13, color: AppTheme.textSecondary)),
              if (tip.$3 != null) ...[
                const SizedBox(height: 8),
                PressableScale(
                  onTap: () {}, // decorative for MVP — must render
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.borderSubtle),
                    ),
                    child: Text(tip.$3!,
                        style: AppTheme.ui(
                            size: 12, color: AppTheme.textSecondary)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
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
          Text('Recent analyses',
              style: AppTheme.ui(size: 14, weight: FontWeight.w600)),
          const SizedBox(height: 10),
          Expanded(
            child: entries.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('No analyses yet',
                            style: AppTheme.display(
                                size: 20, weight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Press ',
                                style: AppTheme.ui(
                                    size: 13, color: AppTheme.textDim)),
                            KeycapBadge.combo(hotkey,
                                size: KeycapSize.small),
                            Text(' to get started',
                                style: AppTheme.ui(
                                    size: 13, color: AppTheme.textDim)),
                          ],
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: entries.length,
                    separatorBuilder: (_, _) => const Divider(
                        height: 14, color: AppTheme.borderSubtle),
                    itemBuilder: (context, i) =>
                        _RecentRow(entry: entries[i], onTap: onOpenEntry),
                  ),
          ),
        ],
      ),
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
              Text(relativeTime(entry.timestamp),
                  style: AppTheme.ui(size: 11, color: AppTheme.textDim)),
            ],
          ),
          const SizedBox(height: 3),
          Text('project ${entry.projectPathHash.substring(0, entry.projectPathHash.length.clamp(0, 6))}',
              style: AppTheme.ui(size: 11, color: AppTheme.textDim)),
        ],
      ),
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
