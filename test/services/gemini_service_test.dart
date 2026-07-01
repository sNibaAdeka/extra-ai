import 'package:flutter_test/flutter_test.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:extra_ai/services/gemini_service.dart';
import 'package:extra_ai/understanding/error_messages.dart';

/// Fake model that returns a canned string or throws a canned error, so the
/// GeminiService flow (parse + validate + error-map) is testable without a key.
class _FakeModel implements PromptModel {
  _FakeModel({this.response, this.error});
  final String? response;
  final Object? error;

  @override
  Future<String?> generate(String prompt, {List<int>? screenshotBytes}) async {
    if (error != null) throw error!;
    return response;
  }
}

void main() {
  group('GeminiService', () {
    test('returns a parsed response on well-formed JSON', () async {
      final service = GeminiService(
        model: _FakeModel(
          response:
              '{"improved_prompt": "Do X in @file.js.", "issues": ["a"], "clarifying_question": null}',
        ),
      );
      final result = await service.analyze(fullPrompt: 'anything');
      expect(result.isSuccess, isTrue);
      expect(result.response!.improvedPrompt, contains('@file.js'));
    });

    test('maps invalid JSON to an invalidResponse failure', () async {
      final service = GeminiService(model: _FakeModel(response: 'garbage'));
      final result = await service.analyze(fullPrompt: 'x');
      expect(result.isSuccess, isFalse);
      expect(result.failure, FailureType.invalidResponse);
    });

    test('maps a null model reply to invalidResponse', () async {
      final service = GeminiService(model: _FakeModel(response: null));
      final result = await service.analyze(fullPrompt: 'x');
      expect(result.failure, FailureType.invalidResponse);
    });

    test('maps an InvalidApiKey error to noApiKey', () async {
      final service = GeminiService(
        model: _FakeModel(error: InvalidApiKey('bad key')),
      );
      final result = await service.analyze(fullPrompt: 'x');
      expect(result.failure, FailureType.noApiKey);
    });

    test('maps a timeout error to networkTimeout', () async {
      final service = GeminiService(
        model: _FakeModel(error: GeminiTimeout()),
      );
      final result = await service.analyze(fullPrompt: 'x');
      expect(result.failure, FailureType.networkTimeout);
    });

    test('maps an unexpected error to unknown', () async {
      final service = GeminiService(
        model: _FakeModel(error: StateError('boom')),
      );
      final result = await service.analyze(fullPrompt: 'x');
      expect(result.failure, FailureType.unknown);
    });

    test('retries once on invalid JSON before giving up', () async {
      var calls = 0;
      final flaky = _CountingModel(() {
        calls++;
        return calls == 1
            ? 'not json'
            : '{"improved_prompt": "ok", "issues": [], "clarifying_question": null}';
      });
      final service = GeminiService(model: flaky);
      final result = await service.analyze(fullPrompt: 'x');
      expect(calls, 2);
      expect(result.isSuccess, isTrue);
    });
  });
}

class _CountingModel implements PromptModel {
  _CountingModel(this.next);
  final String Function() next;

  @override
  Future<String?> generate(String prompt, {List<int>? screenshotBytes}) async {
    return next();
  }
}
