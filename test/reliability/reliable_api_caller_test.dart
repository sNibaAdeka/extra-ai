import 'package:flutter_test/flutter_test.dart';
import 'package:extra_ai/reliability/reliable_api_caller.dart';

void main() {
  group('ReliableApiCaller', () {
    test('returns the result on first success', () async {
      var calls = 0;
      final result = await ReliableApiCaller.callWithRetry(() async {
        calls++;
        return 'ok';
      });
      expect(result, 'ok');
      expect(calls, 1);
    });

    test('retries once after a failure, then succeeds', () async {
      var calls = 0;
      final result = await ReliableApiCaller.callWithRetry(
        () async {
          calls++;
          if (calls == 1) throw Exception('transient');
          return 'recovered';
        },
        backoffBase: const Duration(milliseconds: 1),
      );
      expect(result, 'recovered');
      expect(calls, 2);
    });

    test('rethrows the last error after max attempts', () async {
      var calls = 0;
      await expectLater(
        ReliableApiCaller.callWithRetry<String>(
          () async {
            calls++;
            throw StateError('down');
          },
          backoffBase: const Duration(milliseconds: 1),
        ),
        throwsStateError,
      );
      expect(calls, 2); // default maxAttempts
    });

    test('a hung call times out and triggers the retry', () async {
      var calls = 0;
      final result = await ReliableApiCaller.callWithRetry(
        () async {
          calls++;
          if (calls == 1) {
            // Never completes within the timeout.
            await Future<void>.delayed(const Duration(seconds: 30));
          }
          return 'second-attempt';
        },
        timeout: const Duration(milliseconds: 50),
        backoffBase: const Duration(milliseconds: 1),
      );
      expect(result, 'second-attempt');
      expect(calls, 2);
    });

    test('honors a custom attempt count', () async {
      var calls = 0;
      await expectLater(
        ReliableApiCaller.callWithRetry<void>(
          () async {
            calls++;
            throw Exception('always');
          },
          maxAttempts: 3,
          backoffBase: const Duration(milliseconds: 1),
        ),
        throwsException,
      );
      expect(calls, 3);
    });
  });
}
