import 'package:flutter/material.dart';

import '../../models/prompt_history_entry.dart';
import '../../services/favorites_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/controls.dart';
import '../dashboard/home_dashboard.dart' show relativeTime;

/// Which slice of history a filter tab shows.
enum HistoryFilter { all, today, week, favorites }

/// Pure filtering logic (search + tabs) so it's unit-testable.
List<PromptHistoryEntry> filterHistory(
  List<PromptHistoryEntry> entries, {
  required String query,
  required HistoryFilter filter,
  required bool Function(PromptHistoryEntry) isFavorite,
  DateTime? now,
}) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final weekAgo = today.subtract(const Duration(days: 6));
  final q = query.trim().toLowerCase();

  return entries.where((e) {
    if (q.isNotEmpty &&
        !e.roughPrompt.toLowerCase().contains(q) &&
        !e.projectPathHash.toLowerCase().contains(q)) {
      return false;
    }
    final day = DateTime(e.timestamp.year, e.timestamp.month, e.timestamp.day);
    switch (filter) {
      case HistoryFilter.all:
        return true;
      case HistoryFilter.today:
        return day == today;
      case HistoryFilter.week:
        return !day.isBefore(weekAgo) && !day.isAfter(today);
      case HistoryFilter.favorites:
        return isFavorite(e);
    }
  }).toList();
}

/// Screen 7 — History: search, filter tabs, favorites, expandable entries.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    super.key,
    required this.entries,
    required this.favorites,
    required this.onOpenEntry,
  });

  final List<PromptHistoryEntry> entries;
  final FavoritesService favorites;
  final ValueChanged<PromptHistoryEntry> onOpenEntry;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _search = TextEditingController();
  HistoryFilter _filter = HistoryFilter.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  int _countFor(HistoryFilter f) => filterHistory(
    widget.entries,
    query: '',
    filter: f,
    isFavorite: widget.favorites.isFavorite,
  ).length;

  @override
  Widget build(BuildContext context) {
    final visible = filterHistory(
      widget.entries,
      query: _search.text,
      filter: _filter,
      isFavorite: widget.favorites.isFavorite,
    );
    final todayCount = _countFor(HistoryFilter.today);
    final favCount = _countFor(HistoryFilter.favorites);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.history, size: 20, color: AppTheme.textSecondary),
            const SizedBox(width: 8),
            Text(
              'History',
              style: AppTheme.display(size: 24, weight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              '💬 ${widget.entries.length} total',
              style: AppTheme.ui(size: 12, color: AppTheme.textDim),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '·',
                style: AppTheme.ui(size: 12, color: AppTheme.textDim),
              ),
            ),
            Text(
              '📅 $todayCount today',
              style: AppTheme.ui(size: 12, color: AppTheme.textDim),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '·',
                style: AppTheme.ui(size: 12, color: AppTheme.textDim),
              ),
            ),
            Text(
              '⭐ $favCount favorites',
              style: AppTheme.ui(size: 12, color: AppTheme.textDim),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Live search.
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          style: AppTheme.ui(size: 13),
          cursorColor: AppTheme.accent,
          decoration: InputDecoration(
            hintText: 'Search analyses...',
            hintStyle: AppTheme.ui(size: 13, color: AppTheme.textDim),
            prefixIcon: const Icon(
              Icons.search,
              size: 18,
              color: AppTheme.textDim,
            ),
            filled: true,
            fillColor: AppTheme.surface,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.borderSubtle),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.borderFocus),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Filter tabs.
        Wrap(
          spacing: 8,
          children: [
            _tab('All', _countFor(HistoryFilter.all), HistoryFilter.all),
            _tab('Today', todayCount, HistoryFilter.today),
            _tab(
              'This week',
              _countFor(HistoryFilter.week),
              HistoryFilter.week,
            ),
            _tab('Favorites', favCount, HistoryFilter.favorites),
            Tooltip(
              message: 'Coming soon',
              child: SelectChip(
                label: '+ custom',
                selected: false,
                onTap: () {}, // placeholder — renders + clickable per spec
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        Expanded(
          child: visible.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'No history yet',
                        style: AppTheme.display(
                          size: 20,
                          weight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Your analyses will appear here once you start.',
                        style: AppTheme.ui(size: 13, color: AppTheme.textDim),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: visible.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _HistoryCard(
                    entry: visible[i],
                    favorite: widget.favorites.isFavorite(visible[i]),
                    onToggleFavorite: () async {
                      await widget.favorites.toggle(visible[i]);
                      setState(() {});
                    },
                    onOpen: () => widget.onOpenEntry(visible[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _tab(String label, int count, HistoryFilter f) => SelectChip(
    label: '$label $count',
    selected: _filter == f,
    onTap: () => setState(() => _filter = f),
  );
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.entry,
    required this.favorite,
    required this.onToggleFavorite,
    required this.onOpen,
  });

  final PromptHistoryEntry entry;
  final bool favorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: AppTheme.card(radius: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    entry.roughPrompt,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.ui(size: 14, weight: FontWeight.w500),
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: favorite
                      ? 'Remove from favorites'
                      : 'Add to favorites',
                  child: PressableScale(
                    onTap: onToggleFavorite,
                    child: Icon(
                      favorite ? Icons.star : Icons.star_border,
                      size: 18,
                      color: favorite ? AppTheme.accent : AppTheme.textDim,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              entry.improvedPrompt,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.mono(size: 11.5, color: AppTheme.textDim),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: AppTheme.borderSubtle),
                  ),
                  child: Text(
                    'project ${entry.projectPathHash.substring(0, entry.projectPathHash.length.clamp(0, 6))}',
                    style: AppTheme.ui(size: 10.5, color: AppTheme.textDim),
                  ),
                ),
                Text(
                  relativeTime(entry.timestamp),
                  style: AppTheme.ui(size: 11, color: AppTheme.textDim),
                ),
              ],
            ),
            if (entry.qualityStatus != null) ...[
              const SizedBox(height: 7),
              _HistoryQualityLine(entry: entry),
            ],
            if (entry.auditStatus != null) ...[
              const SizedBox(height: 7),
              _HistoryAuditLine(entry: entry),
            ],
            if (entry.trace != null) ...[
              const SizedBox(height: 7),
              _HistoryTraceLine(entry: entry),
            ],
          ],
        ),
      ),
    );
  }
}

class _HistoryAuditLine extends StatelessWidget {
  const _HistoryAuditLine({required this.entry});

  final PromptHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final status = entry.auditStatus ?? 'clean';
    final color = switch (status) {
      'risk' => AppTheme.signalRed,
      'warning' => AppTheme.signalOrange,
      _ => AppTheme.accent,
    };
    final icon = switch (status) {
      'risk' => Icons.security_outlined,
      'warning' => Icons.manage_search_outlined,
      _ => Icons.verified_outlined,
    };
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            entry.auditSummary ?? 'Local audit complete',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.ui(size: 11, color: AppTheme.textDim),
          ),
        ),
      ],
    );
  }
}

class _HistoryTraceLine extends StatelessWidget {
  const _HistoryTraceLine({required this.entry});

  final PromptHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final trace = entry.trace!;
    return Row(
      children: [
        const Icon(Icons.radar_outlined, size: 14, color: AppTheme.textDim),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            trace.groundedSummary,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.ui(size: 11, color: AppTheme.textDim),
          ),
        ),
      ],
    );
  }
}

class _HistoryQualityLine extends StatelessWidget {
  const _HistoryQualityLine({required this.entry});

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
    final label = switch (status) {
      'passed' => 'Local check passed',
      'warning' => 'Needs review',
      'failed' => 'Context mismatch',
      _ => 'Quality unknown',
    };
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTheme.ui(size: 11, weight: FontWeight.w700, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            entry.qualitySummary ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.ui(size: 11, color: AppTheme.textDim),
          ),
        ),
      ],
    );
  }
}
