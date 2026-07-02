import 'package:flutter_test/flutter_test.dart';
import 'package:extra_ai/features/dashboard/week_activity.dart';

void main() {
  group('WeekActivity', () {
    final today = DateTime(2026, 7, 3, 15, 30); // a Friday afternoon

    test('buckets timestamps into the last 7 days ending today', () {
      final counts = WeekActivity.counts([
        DateTime(2026, 7, 3, 9), // today → bucket 6
        DateTime(2026, 7, 3, 22), // today → bucket 6
        DateTime(2026, 7, 1, 12), // 2 days ago → bucket 4
        DateTime(2026, 6, 27, 8), // 6 days ago → bucket 0
      ], today: today);
      expect(counts, [1, 0, 0, 0, 1, 0, 2]);
    });

    test('ignores timestamps outside the window', () {
      final counts = WeekActivity.counts([
        DateTime(2026, 6, 26, 23, 59), // 7 days ago — outside
        DateTime(2026, 7, 4), // tomorrow — outside
      ], today: today);
      expect(counts.every((c) => c == 0), isTrue);
    });

    test('day labels are the real last 7 days ending today, not Mon-Sun', () {
      final labels = WeekActivity.dayLabels(today: today);
      expect(labels.length, 7);
      expect(labels.last, 'Fri'); // today
      expect(labels.first, 'Sat'); // 6 days back
    });

    test('todayIndex is always the last slot', () {
      expect(WeekActivity.todayIndex, 6);
    });
  });
}
