import 'package:flutter_test/flutter_test.dart';
import 'package:extra_ai/models/prompt_history_entry.dart';
import 'package:extra_ai/services/history_service.dart';

PromptHistoryEntry _entry(String hash, String rough, DateTime ts) =>
    PromptHistoryEntry(
      projectPathHash: hash,
      roughPrompt: rough,
      improvedPrompt: 'improved: $rough',
      issuesFound: const [],
      timestamp: ts,
    );

void main() {
  late HistoryService history;

  setUp(() {
    history = HistoryService(store: InMemoryHistoryStore());
  });

  group('HistoryService', () {
    test('stores and retrieves entries for a project', () async {
      await history.add(_entry('p1', 'first', DateTime(2026, 1, 1)));
      final recent = history.recentFor('p1');
      expect(recent, hasLength(1));
      expect(recent.first.roughPrompt, 'first');
    });

    test('isolates entries by project hash', () async {
      await history.add(_entry('p1', 'a', DateTime(2026, 1, 1)));
      await history.add(_entry('p2', 'b', DateTime(2026, 1, 1)));
      expect(history.recentFor('p1'), hasLength(1));
      expect(history.recentFor('p2'), hasLength(1));
    });

    test('caps stored history at 5 per project (FIFO drops oldest)', () async {
      for (var i = 1; i <= 6; i++) {
        await history.add(_entry('p1', 'prompt$i', DateTime(2026, 1, i)));
      }
      final all = history.allFor('p1');
      expect(all, hasLength(5));
      // Oldest (prompt1) dropped; prompt2..prompt6 remain.
      expect(all.any((e) => e.roughPrompt == 'prompt1'), isFalse);
      expect(all.any((e) => e.roughPrompt == 'prompt6'), isTrue);
    });

    test('recentFor returns at most the last 3, most recent last', () async {
      for (var i = 1; i <= 5; i++) {
        await history.add(_entry('p1', 'prompt$i', DateTime(2026, 1, i)));
      }
      final recent = history.recentFor('p1');
      expect(recent, hasLength(3));
      expect(recent.first.roughPrompt, 'prompt3');
      expect(recent.last.roughPrompt, 'prompt5');
    });

    test('recentFor returns empty for an unknown project', () {
      expect(history.recentFor('nope'), isEmpty);
    });

    test('clear removes a single project history', () async {
      await history.add(_entry('p1', 'a', DateTime(2026, 1, 1)));
      await history.add(_entry('p2', 'b', DateTime(2026, 1, 1)));
      await history.clear('p1');
      expect(history.recentFor('p1'), isEmpty);
      expect(history.recentFor('p2'), hasLength(1));
    });
  });
}
