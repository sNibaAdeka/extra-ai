import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:extra_ai/security/request_validator.dart';

void main() {
  group('RequestValidator', () {
    test('rejects an empty rough prompt', () {
      final result = RequestValidator.validate(
        roughPrompt: '   ',
        fileContents: const [],
        screenshotBytes: null,
      );
      expect(result.isValid, isFalse);
      expect(result.message, isNotNull);
    });

    test('rejects a rough prompt over 2000 chars', () {
      final result = RequestValidator.validate(
        roughPrompt: 'a' * 2001,
        fileContents: const [],
        screenshotBytes: null,
      );
      expect(result.isValid, isFalse);
    });

    test('rejects total file size over 500KB', () {
      final big = 'x' * 300000;
      final result = RequestValidator.validate(
        roughPrompt: 'make the button prettier',
        fileContents: [big, big],
        screenshotBytes: null,
      );
      expect(result.isValid, isFalse);
    });

    test('rejects a screenshot over 5MB', () {
      final result = RequestValidator.validate(
        roughPrompt: 'fix the layout',
        fileContents: const [],
        screenshotBytes: Uint8List(5000001),
      );
      expect(result.isValid, isFalse);
    });

    test('accepts a valid request', () {
      final result = RequestValidator.validate(
        roughPrompt: 'make the hero section responsive on mobile',
        fileContents: const ['body { margin: 0; }'],
        screenshotBytes: Uint8List(1024),
      );
      expect(result.isValid, isTrue);
      expect(result.message, isNull);
    });

    test('accepts a prompt with no files (files optional)', () {
      final result = RequestValidator.validate(
        roughPrompt: 'improve this prompt',
        fileContents: const [],
        screenshotBytes: null,
      );
      expect(result.isValid, isTrue);
    });
  });
}
