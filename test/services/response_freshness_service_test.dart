import 'package:flutter_test/flutter_test.dart';

import 'package:extra_ai/models/extra_ai_response.dart';
import 'package:extra_ai/models/prompt_history_entry.dart';
import 'package:extra_ai/services/response_freshness_service.dart';

PromptHistoryEntry _history({required String rough, required String improved}) {
  return PromptHistoryEntry(
    projectPathHash: 'project',
    roughPrompt: rough,
    improvedPrompt: improved,
    issuesFound: const [],
    timestamp: DateTime(2026, 1, 1),
  );
}

void main() {
  test('flags a replayed improved prompt for a different request', () {
    const previousImproved =
        'In @src/main.ts, replace the heavy 3D hero with a cleaner layout.';

    final stale = ResponseFreshnessService.looksStale(
      response: const ExtraAIResponse(
        improvedPrompt: previousImproved,
        issues: [],
      ),
      roughPrompt: 'сделай кнопку логина меньше',
      recentHistory: [
        _history(rough: 'убери большую 3д модель', improved: previousImproved),
      ],
    );

    expect(stale, isTrue);
  });

  test('does not flag similar output when the user request is the same', () {
    const improved =
        'In @src/main.ts, replace the heavy 3D hero with a cleaner layout.';

    final stale = ResponseFreshnessService.looksStale(
      response: const ExtraAIResponse(improvedPrompt: improved, issues: []),
      roughPrompt: 'убери большую 3д модель',
      recentHistory: [
        _history(rough: 'убери большую 3д модель', improved: improved),
      ],
    );

    expect(stale, isFalse);
  });
}
