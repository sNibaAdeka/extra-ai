import 'package:flutter_test/flutter_test.dart';

import 'package:extra_ai/models/analysis_preferences.dart';
import 'package:extra_ai/models/analysis_trace.dart';

void main() {
  test('AnalysisTrace round-trips through map storage', () {
    final trace = AnalysisTrace(
      projectName: 'Extra AI',
      projectPathHash: 'abc123',
      modelLabel: 'gemini-2.5-flash',
      filesRead: 4,
      filesSample: const ['lib/main.dart', 'lib/app/app_state.dart'],
      redactedSecrets: 1,
      historyEntriesUsed: 2,
      preferences: const AnalysisPreferences(
        effort: ModelEffort.deep,
        actionMode: ActionMode.fullAccess,
      ),
      recommendedChecks: const ['flutter analyze', 'flutter test'],
      freshnessRegenerated: true,
      qualityStatus: 'passed',
      verificationStatus: 'verified',
      generatedAt: DateTime(2026, 7, 4, 12),
    );

    final restored = AnalysisTrace.fromMap(trace.toMap());

    expect(restored.projectName, 'Extra AI');
    expect(restored.preferences.effort, ModelEffort.deep);
    expect(restored.preferences.actionMode, ActionMode.fullAccess);
    expect(restored.filesSample, contains('lib/main.dart'));
    expect(restored.freshnessRegenerated, isTrue);
    expect(restored.compactSummary, contains('regenerated'));
  });
}
