/// Client-side rate limiter guarding against runaway API costs from bugs or
/// abuse (double-clicks, retry loops). Limits are generous for legit use and
/// only block genuine runaway behavior.
///
/// Server-side rate limiting is out of scope for the MVP — this is honest
/// client-side protection only.
class RateLimiter {
  RateLimiter({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  static const int maxRequestsPerMinute = 5;
  static const int maxRequestsPerDay = 100;

  final DateTime Function() _clock;
  final List<DateTime> _requestLog = [];

  bool canMakeRequest() {
    final now = _clock();
    _prune(now);

    final lastMinute = _requestLog
        .where((t) => now.difference(t) < const Duration(minutes: 1))
        .length;
    final lastDay = _requestLog.length;

    return lastMinute < maxRequestsPerMinute && lastDay < maxRequestsPerDay;
  }

  /// Record a request at the current clock time.
  void recordRequest() => recordRequestAt(_clock());

  /// Record a request at an explicit time — primarily for testing time windows.
  void recordRequestAt(DateTime time) {
    _requestLog.add(time);
  }

  /// Drop entries older than one day relative to [now].
  void _prune(DateTime now) {
    _requestLog.removeWhere((t) => now.difference(t) > const Duration(days: 1));
  }
}
