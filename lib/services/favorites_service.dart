// PRIVACY NOTE: favorites are stored locally via Hive only.

import 'package:hive/hive.dart';

import '../models/prompt_history_entry.dart';

/// Starred analyses (History screen). Keys are stable per entry
/// (projectPathHash + timestamp) so PromptHistoryEntry itself stays untouched.
class FavoritesService {
  FavoritesService(this._box);

  static const String boxName = 'favorites';
  final Box _box;

  static String keyFor(PromptHistoryEntry e) =>
      '${e.projectPathHash}:${e.timestamp.toIso8601String()}';

  bool isFavorite(PromptHistoryEntry e) =>
      _box.get(keyFor(e), defaultValue: false) as bool;

  Future<bool> toggle(PromptHistoryEntry e) async {
    final next = !isFavorite(e);
    if (next) {
      await _box.put(keyFor(e), true);
    } else {
      await _box.delete(keyFor(e));
    }
    return next;
  }

  int get count => _box.length;
}
