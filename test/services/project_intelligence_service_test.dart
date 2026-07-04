import 'package:flutter_test/flutter_test.dart';
import 'package:extra_ai/services/file_service.dart';
import 'package:extra_ai/services/project_intelligence_service.dart';

void main() {
  group('ProjectIntelligenceService', () {
    test('detects Flutter/Gemini project signals and recommended checks', () {
      final project = FileService.buildFromRaw({
        'pubspec.yaml': '''
dependencies:
  flutter:
  google_generative_ai: any
  hive_flutter: any
''',
        'lib/main.dart': 'void main() {}',
        'lib/features/prompt_input.dart': 'class PromptInput {}',
        'test/widget_test.dart': 'void main() {}',
      });

      final intelligence = ProjectIntelligenceService.analyze(
        projectPath: '/Users/me/Extra AI',
        project: project,
      );

      expect(intelligence.summary, contains('Extra AI'));
      expect(intelligence.packageManager, 'flutter pub');
      expect(intelligence.toolchain, contains('Flutter'));
      expect(intelligence.toolchain, contains('Gemini'));
      expect(intelligence.toolchain, contains('Hive local storage'));
      expect(intelligence.sourceRoots, contains('lib'));
      expect(intelligence.entrypoints, contains('lib/main.dart'));
      expect(
        intelligence.importantFiles,
        contains('lib/features/prompt_input.dart'),
      );
      expect(intelligence.recommendedChecks, contains('flutter analyze'));
      expect(intelligence.recommendedChecks, contains('flutter test'));
      expect(intelligence.riskFlags.join(' '), contains('LLM/API'));
    });

    test('reports redacted secret risk without exposing the value', () {
      final project = FileService.buildFromRaw({
        'src/config.ts': 'export const apiKey = "abcdefghijklmnop1234";',
      });

      final intelligence = ProjectIntelligenceService.analyze(
        projectPath: '/tmp/site',
        project: project,
      );

      expect(intelligence.riskFlags.join(' '), contains('redacted'));
      expect(
        intelligence.toPromptBlock(),
        isNot(contains('abcdefghijklmnop1234')),
      );
    });
  });
}
