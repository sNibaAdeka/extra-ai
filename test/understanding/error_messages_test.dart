import 'package:flutter_test/flutter_test.dart';
import 'package:extra_ai/understanding/error_messages.dart';

void main() {
  group('ErrorMessages', () {
    test('maps every failure type to a non-empty human message', () {
      for (final type in FailureType.values) {
        final msg = ErrorMessages.forFailure(type);
        expect(msg.trim(), isNotEmpty);
        // No raw technical leakage: no stack-trace markers or HTTP codes.
        expect(msg, isNot(contains('Exception')));
        expect(msg, isNot(matches(RegExp(r'\b[45]\d\d\b'))));
      }
    });

    test('network timeout message mentions connection', () {
      expect(
        ErrorMessages.forFailure(FailureType.networkTimeout).toLowerCase(),
        contains('connection'),
      );
    });

    test('rate limited message mentions quota or credits', () {
      expect(
        ErrorMessages.forFailure(FailureType.rateLimited).toLowerCase(),
        anyOf(contains('quota'), contains('credits')),
      );
    });
  });
}
