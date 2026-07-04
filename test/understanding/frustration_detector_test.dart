import 'package:flutter_test/flutter_test.dart';
import 'package:extra_ai/understanding/frustration_detector.dart';

void main() {
  group('FrustrationDetector', () {
    test('detects frustration from double exclamation + "still"', () {
      expect(FrustrationDetector.detect('this is STILL broken!!'), isTrue);
    });

    test('detects frustration from all-caps + "again"', () {
      expect(FrustrationDetector.detect('WHY IS THIS BROKEN AGAIN'), isTrue);
    });

    test('detects Russian frustration signals', () {
      expect(FrustrationDetector.detect('НЕ РАБОТАЕТ ОПЯТЬ!!'), isTrue);
    });

    test('a single signal alone is not enough', () {
      // Only "!!" present, calm otherwise, lowercase, no repeat words.
      expect(
        FrustrationDetector.detect('add a subtle shadow to the card!!'),
        isFalse,
      );
    });

    test('calm prompt is not flagged', () {
      expect(
        FrustrationDetector.detect('please make the button a bit larger'),
        isFalse,
      );
    });
  });
}
