import 'package:flutter_test/flutter_test.dart';
import 'package:extra_ai/security/rate_limiter.dart';

void main() {
  group('RateLimiter', () {
    test('allows the first request', () {
      final limiter = RateLimiter();
      expect(limiter.canMakeRequest(), isTrue);
    });

    test('blocks after 5 requests within a minute', () {
      final limiter = RateLimiter();
      for (var i = 0; i < 5; i++) {
        expect(limiter.canMakeRequest(), isTrue);
        limiter.recordRequest();
      }
      expect(limiter.canMakeRequest(), isFalse);
    });

    test('allows requests again after the minute window passes', () {
      final now = DateTime(2026, 1, 1, 12, 0, 0);
      final limiter = RateLimiter(clock: () => now);
      for (var i = 0; i < 5; i++) {
        limiter.recordRequest();
      }
      expect(limiter.canMakeRequest(), isFalse);

      // Advance the clock past the minute window.
      final later = now.add(const Duration(minutes: 1, seconds: 1));
      final limiter2 = RateLimiter(clock: () => later);
      // Re-record within the old window are stale relative to `later`.
      for (var i = 0; i < 5; i++) {
        limiter2.recordRequestAt(now);
      }
      expect(limiter2.canMakeRequest(), isTrue);
    });

    test('blocks after 100 requests within a day', () {
      final base = DateTime(2026, 1, 1, 8, 0, 0);
      var tick = base;
      // Spread requests ~1 min apart so the per-minute cap never trips.
      final limiter = RateLimiter(clock: () => tick);
      for (var i = 0; i < 100; i++) {
        tick = base.add(Duration(minutes: i * 2));
        limiter.recordRequestAt(tick);
      }
      tick = base.add(const Duration(minutes: 201));
      expect(limiter.canMakeRequest(), isFalse);
    });
  });
}
