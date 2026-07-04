import 'package:flutter_test/flutter_test.dart';
import 'package:extra_ai/models/analysis_preferences.dart';
import 'package:extra_ai/models/extra_ai_response.dart';
import 'package:extra_ai/models/project_intelligence.dart';
import 'package:extra_ai/models/response_quality_report.dart';
import 'package:extra_ai/services/response_quality_service.dart';

void main() {
  group('ResponseQualityService', () {
    test('passes a concrete prompt that references a real project file', () {
      final report = ResponseQualityService.evaluate(
        response: const ExtraAIResponse(
          improvedPrompt:
              'In @lib/main.dart, update the hero layout and verify with flutter analyze and flutter test.',
          issues: ['Check responsive layout after the hero update.'],
        ),
        knownFiles: const ['lib/main.dart', 'lib/theme/app_theme.dart'],
        preferences: const AnalysisPreferences(
          securityAudit: false,
          bugAudit: false,
        ),
        intelligence: const ProjectIntelligence(
          summary: 'Extra AI uses Flutter.',
          packageManager: 'flutter pub',
          toolchain: ['Flutter'],
          sourceRoots: ['lib'],
          entrypoints: ['lib/main.dart'],
          importantFiles: ['lib/main.dart'],
          recommendedChecks: ['flutter analyze', 'flutter test'],
          riskFlags: [],
        ),
      );

      expect(report.status, ResponseQualityStatus.passed);
      expect(report.failedChecks, isEmpty);
    });

    test('fails when the prompt references an unknown @file', () {
      final report = ResponseQualityService.evaluate(
        response: const ExtraAIResponse(
          improvedPrompt: 'In @src/ghost.ts, fix the visual bug.',
          issues: [],
        ),
        knownFiles: const ['src/main.ts'],
        preferences: const AnalysisPreferences(
          securityAudit: false,
          bugAudit: false,
        ),
      );

      expect(report.status, ResponseQualityStatus.failed);
      expect(report.failedChecks.join(' '), contains('@src/ghost.ts'));
    });

    test(
      'warns when project files exist but the prompt has no file reference',
      () {
        final report = ResponseQualityService.evaluate(
          response: const ExtraAIResponse(
            improvedPrompt: 'Make the page cleaner and nicer.',
            issues: [],
          ),
          knownFiles: const ['src/main.ts'],
          preferences: const AnalysisPreferences(
            securityAudit: false,
            bugAudit: false,
          ),
        );

        expect(report.status, ResponseQualityStatus.warning);
        expect(report.warnings.join(' '), contains('concrete project file'));
      },
    );

    test('warns when security audit is enabled but absent from output', () {
      final report = ResponseQualityService.evaluate(
        response: const ExtraAIResponse(
          improvedPrompt: 'In @src/main.ts, update the layout.',
          issues: [],
        ),
        knownFiles: const ['src/main.ts'],
        preferences: const AnalysisPreferences(securityAudit: true),
      );

      expect(report.status, ResponseQualityStatus.warning);
      expect(report.warnings.join(' '), contains('Security audit'));
    });
  });
}
