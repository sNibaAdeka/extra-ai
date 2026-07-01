import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:extra_ai/services/knowledge_base_service.dart';

/// Loads the REAL bundled JSON assets (not mocked) to catch pubspec asset
/// registration mistakes and malformed JSON before runtime.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('real knowledge-base assets load and expose expected keys', () async {
    KnowledgeBaseService.reset();
    await KnowledgeBaseService.loadAll(loader: rootBundle.loadString);

    // stack_patterns.json has the six documented stacks.
    expect(KnowledgeBaseService.getStackPatterns('react'), isNotNull);
    expect(KnowledgeBaseService.getStackPatterns('nextjs'), isNotNull);
    expect(KnowledgeBaseService.getStackPatterns('vue'), isNotNull);
    expect(KnowledgeBaseService.getStackPatterns('tailwind'), isNotNull);
    expect(KnowledgeBaseService.getStackPatterns('bootstrap'), isNotNull);
    expect(KnowledgeBaseService.getStackPatterns('vanilla_js'), isNotNull);

    // security_patterns.json exposes a patterns array.
    expect(KnowledgeBaseService.getSecurityPatterns()['patterns'], isA<List>());

    // design_heuristics.json exposes named rules.
    expect(KnowledgeBaseService.getDesignHeuristics()['contrast'], isNotNull);

    // tool_syntax.json exposes per-tool conventions.
    expect(KnowledgeBaseService.getToolSyntax('cursor'), isNotNull);
    expect(KnowledgeBaseService.getToolSyntax('claude_code'), isNotNull);
  });
}
