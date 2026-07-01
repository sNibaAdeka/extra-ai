import 'package:flutter_test/flutter_test.dart';
import 'package:extra_ai/models/project_context.dart';
import 'package:extra_ai/models/prompt_history_entry.dart';
import 'package:extra_ai/models/user_profile.dart';
import 'package:extra_ai/services/extra_ai_request_builder.dart';
import 'package:extra_ai/services/knowledge_base_service.dart';

UserProfile _profile() => UserProfile(
      experienceLevel: ExperienceLevel.vibeCoder,
      primaryTools: const ['Cursor', 'Claude Code'],
      projectFocus: ProjectFocus.clientSites,
      tonePreference: ToneLevel.explained,
      createdAt: DateTime(2026, 1, 1),
    );

ProjectContext _project({int analyses = 0}) => ProjectContext(
      projectPath: '/Users/me/site',
      detectedStack: 'React + Tailwind',
      fileNames: const ['App.jsx', 'style.css'],
      firstSeenAt: DateTime(2026, 1, 1),
      lastAnalyzedAt: DateTime(2026, 1, 1),
      totalAnalysesCount: analyses,
    );

void main() {
  setUp(() async {
    KnowledgeBaseService.reset();
    await KnowledgeBaseService.loadAll(loader: (path) async {
      if (path.contains('stack_patterns')) {
        return '{"react": {"common_issues": [{"pattern": "missing key prop"}]}}';
      }
      if (path.contains('tool_syntax')) {
        return '{"cursor": {"convention": "use @file refs", "format_hint": "scope it"}}';
      }
      if (path.contains('security_patterns')) {
        return '{"patterns": [{"id": "hardcoded_api_key"}]}';
      }
      if (path.contains('design_heuristics')) {
        return '{"contrast": {"rule": "4.5:1"}}';
      }
      return '{}';
    });
  });

  ExtraAIRequestBuilder builder({
    List<PromptHistoryEntry> history = const [],
    bool frustrated = false,
  }) =>
      ExtraAIRequestBuilder(
        userProfile: _profile(),
        projectContext: _project(),
        recentHistory: history,
        frustrationDetected: frustrated,
      );

  group('buildContextBlock', () {
    test('includes the user profile fields', () {
      final block = builder().buildContextBlock();
      expect(block, contains('USER PROFILE'));
      expect(block, contains('Cursor'));
      expect(block, contains('Claude Code'));
    });

    test('includes the project stack and file names', () {
      final block = builder().buildContextBlock();
      expect(block, contains('React + Tailwind'));
      expect(block, contains('App.jsx'));
    });

    test('shows the analysis number as count + 1', () {
      final b = ExtraAIRequestBuilder(
        userProfile: _profile(),
        projectContext: _project(analyses: 4),
        recentHistory: const [],
        frustrationDetected: false,
      );
      expect(b.buildContextBlock(), contains('analysis #5'));
    });

    test('injects knowledge-base stack patterns for the detected stack', () {
      final block = builder().buildContextBlock();
      expect(block, contains('KNOWLEDGE BASE'));
      expect(block, contains('missing key prop'));
    });

    test('injects the tool formatting convention for the primary tool', () {
      final block = builder().buildContextBlock();
      expect(block, contains('use @file refs'));
    });

    test('injects security patterns and design heuristics', () {
      final block = builder().buildContextBlock();
      expect(block, contains('hardcoded_api_key'));
      expect(block, contains('4.5:1'));
    });

    test('states no history when history is empty', () {
      final block = builder().buildContextBlock();
      expect(block.toLowerCase(), contains('no previous analyses'));
    });

    test('summarizes recent history entries when present', () {
      final block = builder(history: [
        PromptHistoryEntry(
          projectPathHash: 'h',
          roughPrompt: 'make the button blue',
          improvedPrompt:
              'Change the .cta button background to #2563EB in style.css, preserving hover state and all other styles.',
          issuesFound: const [],
          timestamp: DateTime(2026, 1, 2),
        ),
      ]).buildContextBlock();
      expect(block, contains('make the button blue'));
      expect(block, contains('RECENT HISTORY'));
    });

    test('adds a frustration calibration note only when flagged', () {
      expect(
        builder(frustrated: true).buildContextBlock().toLowerCase(),
        contains('frustration'),
      );
      expect(
        builder(frustrated: false).buildContextBlock().toLowerCase(),
        isNot(contains('frustration')),
      );
    });

    test('handles a very short improved prompt in history without crashing', () {
      final block = builder(history: [
        PromptHistoryEntry(
          projectPathHash: 'h',
          roughPrompt: 'x',
          improvedPrompt: 'short', // < 80 chars — substring must not throw
          issuesFound: const [],
          timestamp: DateTime(2026, 1, 2),
        ),
      ]).buildContextBlock();
      expect(block, contains('short'));
    });
  });

  group('buildFullPrompt', () {
    test('embeds the context block, files, and rough prompt in order', () {
      final full = builder().buildFullPrompt(
        fileContents: '--- App.jsx ---\nexport default App;',
        roughPrompt: 'make it nicer',
        issuesEnabled: true,
      );
      expect(full, contains('USER PROFILE'));
      expect(full, contains('PROJECT FILES'));
      expect(full, contains('export default App;'));
      expect(full, contains('make it nicer'));
      expect(full, contains('issues_enabled: true'));
    });
  });
}
