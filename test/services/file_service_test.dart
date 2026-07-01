import 'package:flutter_test/flutter_test.dart';
import 'package:extra_ai/services/file_service.dart';

void main() {
  group('FileService.buildFromRaw', () {
    test('redacts secrets in file content before assembly', () {
      final project = FileService.buildFromRaw({
        'config.js': 'const apiKey = "abcdefghijklmnop1234";',
      });
      expect(project.concatenatedContent, contains('[REDACTED_BY_EXTRA_AI]'));
      expect(project.concatenatedContent,
          isNot(contains('abcdefghijklmnop1234')));
      expect(project.redactedSecretCount, greaterThanOrEqualTo(1));
    });

    test('reports file names in order', () {
      final project = FileService.buildFromRaw({
        'index.html': '<html></html>',
        'style.css': 'body {}',
      });
      expect(project.fileNames, ['index.html', 'style.css']);
    });

    test('concatenated content labels each file by name', () {
      final project = FileService.buildFromRaw({
        'app.js': 'console.log(1);',
      });
      expect(project.concatenatedContent, contains('app.js'));
      expect(project.concatenatedContent, contains('console.log(1);'));
    });

    test('clean project reports zero redactions', () {
      final project = FileService.buildFromRaw({
        'math.js': 'export const add = (a, b) => a + b;',
      });
      expect(project.redactedSecretCount, 0);
    });

    test('empty project yields empty content and no files', () {
      final project = FileService.buildFromRaw(const {});
      expect(project.fileNames, isEmpty);
      expect(project.concatenatedContent.trim(), isEmpty);
      expect(project.redactedSecretCount, 0);
    });

    test('redaction count sums across multiple files', () {
      final project = FileService.buildFromRaw({
        'a.js': 'apiKey = "abcdefghijklmnop1234"',
        'b.env': 'password = "hunter2password"',
      });
      expect(project.redactedSecretCount, greaterThanOrEqualTo(2));
    });
  });
}
