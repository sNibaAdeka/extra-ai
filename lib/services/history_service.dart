// PRIVACY NOTE: All data in this file is stored locally via Hive.
// Nothing here is transmitted anywhere except as part of the context
// block included in individual Gemini API requests. There is no backend
// server collecting this data. If this changes in a future version,
// this comment must be updated and the user must be notified.

import 'package:hive/hive.dart';

import '../models/prompt_history_entry.dart';

/// Storage backend for prompt history. Abstracted so the FIFO logic in
/// [HistoryService] is testable with an in-memory store (no Hive init needed).
abstract class HistoryStore {
  List<PromptHistoryEntry> all();
  Future<void> put(List<PromptHistoryEntry> entries);
}

/// In-memory store for tests.
class InMemoryHistoryStore implements HistoryStore {
  final List<PromptHistoryEntry> _entries = [];

  @override
  List<PromptHistoryEntry> all() => List.unmodifiable(_entries);

  @override
  Future<void> put(List<PromptHistoryEntry> entries) async {
    _entries
      ..clear()
      ..addAll(entries);
  }
}

/// Hive-backed store. Persists entries as plain maps (no generated adapters).
class HiveHistoryStore implements HistoryStore {
  HiveHistoryStore(this._box);

  static const String boxName = 'prompt_history';
  final Box _box;

  @override
  List<PromptHistoryEntry> all() {
    return _box.values
        .whereType<Map>()
        .map((m) => PromptHistoryEntry.fromMap(Map<String, dynamic>.from(m)))
        .toList();
  }

  @override
  Future<void> put(List<PromptHistoryEntry> entries) async {
    await _box.clear();
    for (final e in entries) {
      await _box.add(e.toMap());
    }
  }
}

/// Session memory (Layer 3). Keeps the last [maxPerProject] entries per project
/// (FIFO), and exposes the last [recentWindow] for the request context block.
class HistoryService {
  HistoryService({required HistoryStore store}) : _store = store; // ignore: prefer_initializing_formals

  static const int maxPerProject = 5;
  static const int recentWindow = 3;

  final HistoryStore _store;

  /// Add an entry, enforcing the per-project FIFO cap. Entries for other
  /// projects are preserved untouched.
  Future<void> add(PromptHistoryEntry entry) async {
    final all = _store.all().toList();

    final sameProject = all
        .where((e) => e.projectPathHash == entry.projectPathHash)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final others =
        all.where((e) => e.projectPathHash != entry.projectPathHash).toList();

    sameProject.add(entry);
    // Drop oldest until within cap.
    while (sameProject.length > maxPerProject) {
      sameProject.removeAt(0);
    }

    await _store.put([...others, ...sameProject]);
  }

  /// All stored entries for a project, oldest first.
  List<PromptHistoryEntry> allFor(String projectPathHash) {
    return _store
        .all()
        .where((e) => e.projectPathHash == projectPathHash)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  /// The last [recentWindow] entries for a project, oldest first (most recent
  /// last) — the slice fed into the Gemini context block.
  List<PromptHistoryEntry> recentFor(String projectPathHash) {
    final all = allFor(projectPathHash);
    if (all.length <= recentWindow) return all;
    return all.sublist(all.length - recentWindow);
  }

  /// Clear a single project's history (settings action).
  Future<void> clear(String projectPathHash) async {
    final remaining = _store
        .all()
        .where((e) => e.projectPathHash != projectPathHash)
        .toList();
    await _store.put(remaining);
  }
}
