import 'package:flutter_test/flutter_test.dart';
import 'package:extra_ai/models/analysis_preferences.dart';
import 'package:extra_ai/models/analysis_trace.dart';
import 'package:extra_ai/models/project_audit_report.dart';
import 'package:extra_ai/models/prompt_history_entry.dart';
import 'package:extra_ai/services/history_service.dart';

PromptHistoryEntry _entry(String hash, String rough, DateTime ts) =>
    PromptHistoryEntry(
      projectPathHash: hash,
      roughPrompt: rough,
      improvedPrompt: 'improved: $rough',
      issuesFound: const [],
      timestamp: ts,
    );

void main() {
  late HistoryService history;

  setUp(() {
    history = HistoryService(store: InMemoryHistoryStore());
  });

  group('HistoryService', () {
    test('PromptHistoryEntry preserves optional quality fields', () {
      final trace = AnalysisTrace(
        projectName: 'Extra AI',
        projectPathHash: 'p1',
        modelLabel: 'gemini-2.5-flash',
        filesRead: 1,
        filesSample: const ['app.js'],
        redactedSecrets: 0,
        historyEntriesUsed: 0,
        preferences: const AnalysisPreferences(),
        recommendedChecks: const ['npm test'],
        freshnessRegenerated: false,
        qualityStatus: 'warning',
        verificationStatus: 'skipped',
        generatedAt: DateTime(2026, 1, 1),
      );
      final entry = PromptHistoryEntry(
        projectPathHash: 'p1',
        roughPrompt: 'fix hero',
        improvedPrompt: 'In @app.js, update hero.',
        issuesFound: const [],
        timestamp: DateTime(2026, 1, 1),
        qualityStatus: 'warning',
        qualitySummary: 'Prompt does not reference recommended checks.',
        auditStatus: 'warning',
        auditSummary: '1 local signal.',
        auditReport: const ProjectAuditReport(
          issues: [
            ProjectAuditIssue(
              category: ProjectAuditCategory.responsive,
              severity: ProjectAuditSeverity.warning,
              title: 'Large fixed width',
              detail: 'Large fixed widths often break mobile layouts.',
              file: 'style.css',
            ),
          ],
        ),
        trace: trace,
      );

      final restored = PromptHistoryEntry.fromMap(entry.toMap());
      expect(restored.qualityStatus, 'warning');
      expect(
        restored.qualitySummary,
        'Prompt does not reference recommended checks.',
      );
      expect(restored.trace?.modelLabel, 'gemini-2.5-flash');
      expect(restored.trace?.filesSample, ['app.js']);
      expect(restored.auditStatus, 'warning');
      expect(restored.auditReport?.issues.single.file, 'style.css');
    });

    test('PromptHistoryEntry keeps old records compatible', () {
      final restored = PromptHistoryEntry.fromMap({
        'projectPathHash': 'p1',
        'roughPrompt': 'old',
        'improvedPrompt': 'old improved',
        'issuesFound': const [],
        'timestamp': DateTime(2026, 1, 1).toIso8601String(),
      });

      expect(restored.qualityStatus, isNull);
      expect(restored.qualitySummary, isNull);
    });

    test('stores and retrieves entries for a project', () async {
      await history.add(_entry('p1', 'first', DateTime(2026, 1, 1)));
      final recent = history.recentFor('p1');
      expect(recent, hasLength(1));
      expect(recent.first.roughPrompt, 'first');
    });

    test('isolates entries by project hash', () async {
      await history.add(_entry('p1', 'a', DateTime(2026, 1, 1)));
      await history.add(_entry('p2', 'b', DateTime(2026, 1, 1)));
      expect(history.recentFor('p1'), hasLength(1));
      expect(history.recentFor('p2'), hasLength(1));
    });

    test('caps stored history at 5 per project (FIFO drops oldest)', () async {
      for (var i = 1; i <= 6; i++) {
        await history.add(_entry('p1', 'prompt$i', DateTime(2026, 1, i)));
      }
      final all = history.allFor('p1');
      expect(all, hasLength(5));
      // Oldest (prompt1) dropped; prompt2..prompt6 remain.
      expect(all.any((e) => e.roughPrompt == 'prompt1'), isFalse);
      expect(all.any((e) => e.roughPrompt == 'prompt6'), isTrue);
    });

    test('recentFor returns at most the last 3, most recent last', () async {
      for (var i = 1; i <= 5; i++) {
        await history.add(_entry('p1', 'prompt$i', DateTime(2026, 1, i)));
      }
      final recent = history.recentFor('p1');
      expect(recent, hasLength(3));
      expect(recent.first.roughPrompt, 'prompt3');
      expect(recent.last.roughPrompt, 'prompt5');
    });

    test('recentFor returns empty for an unknown project', () {
      expect(history.recentFor('nope'), isEmpty);
    });

    test('clear removes a single project history', () async {
      await history.add(_entry('p1', 'a', DateTime(2026, 1, 1)));
      await history.add(_entry('p2', 'b', DateTime(2026, 1, 1)));
      await history.clear('p1');
      expect(history.recentFor('p1'), isEmpty);
      expect(history.recentFor('p2'), hasLength(1));
    });

    test('rekeyProject migrates old project hashes to stable hashes', () async {
      await history.add(_entry('legacy', 'a', DateTime(2026, 1, 1)));

      await history.rekeyProject(from: 'legacy', to: 'stable');

      expect(history.recentFor('legacy'), isEmpty);
      final migrated = history.recentFor('stable');
      expect(migrated, hasLength(1));
      expect(migrated.first.roughPrompt, 'a');
    });
  });
}
