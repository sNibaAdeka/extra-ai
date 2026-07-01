import 'package:flutter_test/flutter_test.dart';
import 'package:extra_ai/security/response_validator.dart';

void main() {
  group('ResponseValidator', () {
    test('parses a well-formed response', () {
      const raw = '''
      {
        "improved_prompt": "Update the .hero button color in @style.css to #7C3AED.",
        "issues": ["Missing alt text", "No mobile breakpoint"],
        "clarifying_question": null
      }''';
      final result = ResponseValidator.validateAndParse(raw);
      expect(result, isNotNull);
      expect(result!.improvedPrompt, contains('.hero'));
      expect(result.issues.length, 2);
      expect(result.hasClarifyingQuestion, isFalse);
    });

    test('returns null for invalid JSON', () {
      final result = ResponseValidator.validateAndParse('not json at all');
      expect(result, isNull);
    });

    test('returns null when improved_prompt is missing', () {
      const raw = '{"issues": [], "clarifying_question": null}';
      final result = ResponseValidator.validateAndParse(raw);
      expect(result, isNull);
    });

    test('returns null when improved_prompt is absurdly long', () {
      final raw =
          '{"improved_prompt": "${'a' * 3001}", "issues": [], "clarifying_question": null}';
      final result = ResponseValidator.validateAndParse(raw);
      expect(result, isNull);
    });

    test('caps issues at 3 when more are returned', () {
      const raw = '''
      {
        "improved_prompt": "Do the thing.",
        "issues": ["a", "b", "c", "d", "e"],
        "clarifying_question": null
      }''';
      final result = ResponseValidator.validateAndParse(raw);
      expect(result, isNotNull);
      expect(result!.issues.length, 3);
    });

    test('handles issues being absent entirely', () {
      const raw =
          '{"improved_prompt": "Do the thing.", "clarifying_question": null}';
      final result = ResponseValidator.validateAndParse(raw);
      expect(result, isNotNull);
      expect(result!.issues, isEmpty);
    });

    test('extracts a clarifying question when present', () {
      const raw = '''
      {
        "improved_prompt": "Do the thing.",
        "issues": [],
        "clarifying_question": "Which button do you mean?"
      }''';
      final result = ResponseValidator.validateAndParse(raw);
      expect(result!.hasClarifyingQuestion, isTrue);
      expect(result.clarifyingQuestion, 'Which button do you mean?');
    });

    test('tolerates markdown code fences around the JSON', () {
      const raw = '''```json
      {"improved_prompt": "Do the thing.", "issues": [], "clarifying_question": null}
      ```''';
      final result = ResponseValidator.validateAndParse(raw);
      expect(result, isNotNull);
      expect(result!.improvedPrompt, 'Do the thing.');
    });
  });
}
