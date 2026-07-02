/// Pure logic for the "Analyses this week" chart: buckets analysis timestamps
/// into the REAL last 7 calendar days ending today (never a hardcoded
/// Mon–Sun week).
class WeekActivity {
  WeekActivity._();

  /// The last slot is always today.
  static const int todayIndex = 6;

  static const List<String> _weekdayNames = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun', //
  ];

  /// Seven counts, oldest day first, today last.
  static List<int> counts(List<DateTime> timestamps, {DateTime? today}) {
    final end = _dateOnly(today ?? DateTime.now());
    final start = end.subtract(const Duration(days: 6));
    final buckets = List<int>.filled(7, 0);
    for (final t in timestamps) {
      final day = _dateOnly(t);
      final offset = day.difference(start).inDays;
      if (offset >= 0 && offset <= 6) buckets[offset]++;
    }
    return buckets;
  }

  /// Seven weekday labels matching [counts] order (today last).
  static List<String> dayLabels({DateTime? today}) {
    final end = _dateOnly(today ?? DateTime.now());
    return List.generate(7, (i) {
      final day = end.subtract(Duration(days: 6 - i));
      return _weekdayNames[day.weekday - 1];
    });
  }

  static DateTime _dateOnly(DateTime t) => DateTime(t.year, t.month, t.day);
}
