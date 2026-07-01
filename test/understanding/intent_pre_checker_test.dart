import 'package:flutter_test/flutter_test.dart';
import 'package:extra_ai/understanding/intent_pre_checker.dart';

void main() {
  group('IntentPreChecker', () {
    test('flags a 2-word vague prompt as veryVague', () {
      expect(IntentPreChecker.check('make better'), IntentClarity.veryVague);
    });

    test('flags a single vague word as veryVague', () {
      expect(IntentPreChecker.check('fix'), IntentClarity.veryVague);
    });

    test('flags a short 3-4 word prompt as vague', () {
      expect(IntentPreChecker.check('change the header size'), IntentClarity.vague);
    });

    test('treats a detailed prompt as clear', () {
      expect(
        IntentPreChecker.check(
          'make the hero section responsive on mobile and fix the button color',
        ),
        IntentClarity.clear,
      );
    });

    test('recognizes Russian vague words', () {
      expect(IntentPreChecker.check('исправь'), IntentClarity.veryVague);
    });

    test('empty prompt is veryVague', () {
      expect(IntentPreChecker.check('   '), IntentClarity.veryVague);
    });
  });
}
