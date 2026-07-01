import 'package:flutter_test/flutter_test.dart';
import 'package:extra_ai/services/knowledge_base_service.dart';

void main() {
  group('KnowledgeBaseService', () {
    setUp(KnowledgeBaseService.reset);

    test('loadAll reads all four assets via the injected loader', () async {
      final loaded = <String>[];
      await KnowledgeBaseService.loadAll(loader: (path) async {
        loaded.add(path);
        return '{}';
      });
      expect(loaded, containsAll([
        'assets/knowledge/stack_patterns.json',
        'assets/knowledge/security_patterns.json',
        'assets/knowledge/design_heuristics.json',
        'assets/knowledge/tool_syntax.json',
      ]));
    });

    test('getStackPatterns returns the entry for a detected stack key', () async {
      await KnowledgeBaseService.loadAll(loader: (path) async {
        if (path.contains('stack_patterns')) {
          return '{"react": {"common_issues": [{"pattern": "x"}]}}';
        }
        return '{}';
      });
      final react = KnowledgeBaseService.getStackPatterns('react');
      expect(react, isNotNull);
      expect(react!['common_issues'], isA<List>());
    });

    test('getStackPatterns normalizes spaces to underscores', () async {
      await KnowledgeBaseService.loadAll(loader: (path) async {
        if (path.contains('stack_patterns')) {
          return '{"vanilla_js": {"common_issues": []}}';
        }
        return '{}';
      });
      // "Vanilla JS" -> "vanilla_js"
      expect(KnowledgeBaseService.getStackPatterns('Vanilla JS'), isNotNull);
    });

    test('getStackPatterns returns null for an unknown stack', () async {
      await KnowledgeBaseService.loadAll(loader: (_) async => '{}');
      expect(KnowledgeBaseService.getStackPatterns('cobol'), isNull);
    });

    test('getToolSyntax returns convention + format_hint for a tool', () async {
      await KnowledgeBaseService.loadAll(loader: (path) async {
        if (path.contains('tool_syntax')) {
          return '{"cursor": {"convention": "c", "format_hint": "f"}}';
        }
        return '{}';
      });
      final cursor = KnowledgeBaseService.getToolSyntax('Cursor');
      expect(cursor!['convention'], 'c');
      expect(cursor['format_hint'], 'f');
    });

    test('security patterns and design heuristics load as maps', () async {
      await KnowledgeBaseService.loadAll(loader: (path) async {
        if (path.contains('security_patterns')) {
          return '{"patterns": [{"id": "hardcoded_api_key"}]}';
        }
        if (path.contains('design_heuristics')) {
          return '{"spacing": {"rule": "r"}}';
        }
        return '{}';
      });
      expect(KnowledgeBaseService.getSecurityPatterns()['patterns'], isA<List>());
      expect(KnowledgeBaseService.getDesignHeuristics()['spacing'], isNotNull);
    });

    test('getters are safe before loadAll (return empty/null, no throw)', () {
      KnowledgeBaseService.reset();
      expect(KnowledgeBaseService.getStackPatterns('react'), isNull);
      expect(KnowledgeBaseService.getSecurityPatterns(), isEmpty);
      expect(KnowledgeBaseService.getDesignHeuristics(), isEmpty);
      expect(KnowledgeBaseService.getToolSyntax('cursor'), isNull);
    });
  });
}
