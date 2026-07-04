import 'package:flutter_test/flutter_test.dart';
import 'package:extra_ai/models/extra_ai_response.dart';
import 'package:extra_ai/services/gemini_service.dart';

class _RecordingModel implements PromptModel {
  _RecordingModel(this.reply);
  final String reply;
  final List<String> prompts = [];

  @override
  Future<String?> generate(String prompt, {List<int>? screenshotBytes}) async {
    prompts.add(prompt);
    return reply;
  }
}

void main() {
  const draft = ExtraAIResponse(
    improvedPrompt: 'Change .fake-class in ghost.css to blue.',
    issues: ['issue A'],
  );

  test(
    'correctDraft sends the draft + correction instruction and parses the fix',
    () async {
      final model = _RecordingModel(
        '{"improved_prompt": "Change .cta in style.css to blue.", "issues": ["issue A"], "clarifying_question": null}',
      );
      final service = GeminiService(model: model);

      final result = await service.correctDraft(
        fullPrompt: 'ORIGINAL_REQUEST_MARKER',
        draft: draft,
        correctionInstruction:
            'Reference only class names present in style.css.',
      );

      expect(result.isSuccess, isTrue);
      expect(result.response!.improvedPrompt, contains('.cta'));
      final sent = model.prompts.single;
      expect(sent, contains('ORIGINAL_REQUEST_MARKER'));
      expect(sent, contains('.fake-class')); // the previous draft is included
      expect(
        sent,
        contains('Reference only class names present in style.css.'),
      );
    },
  );

  test('correctDraft maps a bad corrective reply to a failure', () async {
    final service = GeminiService(model: _RecordingModel('garbage'));
    final result = await service.correctDraft(
      fullPrompt: 'x',
      draft: draft,
      correctionInstruction: 'fix it',
    );
    expect(result.isSuccess, isFalse);
  });
}
