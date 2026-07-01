import 'dart:convert';

import '../models/project_context.dart';
import '../models/prompt_history_entry.dart';
import '../models/user_profile.dart';
import 'knowledge_base_service.dart';

/// Assembles ALL context layers — user profile, project context, session
/// history, and curated knowledge-base fragments — into the block that precedes
/// the project files and rough prompt in a Gemini request. This is what turns
/// Extra AI from a stateless wrapper into a grounded, context-aware product.
class ExtraAIRequestBuilder {
  ExtraAIRequestBuilder({
    required this.userProfile,
    required this.projectContext,
    required this.recentHistory,
    this.frustrationDetected = false,
  });

  final UserProfile userProfile;
  final ProjectContext projectContext;

  /// Oldest-first slice (most recent last), already capped upstream.
  final List<PromptHistoryEntry> recentHistory;
  final bool frustrationDetected;

  /// The context block prepended to the request.
  String buildContextBlock() {
    final stackKnowledge = KnowledgeBaseService.getStackPatterns(
        _knowledgeKeyFor(projectContext.detectedStack));
    final primaryTool =
        userProfile.primaryTools.isNotEmpty ? userProfile.primaryTools.first : 'cursor';
    final toolSyntax = KnowledgeBaseService.getToolSyntax(primaryTool);
    final securityPatterns = KnowledgeBaseService.getSecurityPatterns();
    final designHeuristics = KnowledgeBaseService.getDesignHeuristics();

    final historyText = recentHistory.isEmpty
        ? 'No previous analyses for this project.'
        : recentHistory
            .map((e) =>
                '- User asked: "${e.roughPrompt}" → Improved to: "${_preview(e.improvedPrompt)}"')
            .join('\n');

    final frustrationNote = frustrationDetected
        ? '''

NOTE: The user's tone suggests frustration (repeated issue or urgency). Keep the
improved_prompt focused and the issues[] descriptions calm and solution-first —
do not add extra commentary, get straight to the fix.'''
        : '';

    return '''
USER PROFILE:
- Experience: ${userProfile.experienceLevel.description}
- Primary tools: ${userProfile.primaryTools.join(', ')}
- Building: ${userProfile.projectFocus.description}
- Preferred tone: ${userProfile.tonePreference.description}

PROJECT CONTEXT:
- Stack: ${projectContext.detectedStack}
- Files in project: ${projectContext.fileNames.join(', ')}
- This is analysis #${projectContext.totalAnalysesCount + 1} for this project

KNOWLEDGE BASE — known patterns for this stack:
${stackKnowledge != null ? jsonEncode(stackKnowledge) : 'No specific patterns for this stack — use general best practices.'}

TARGET TOOL FORMATTING CONVENTION:
${toolSyntax != null ? '${toolSyntax['convention']} ${toolSyntax['format_hint']}' : 'Use general clear technical instructions.'}

SECURITY PATTERNS TO CHECK (only apply if issues_enabled=true):
${jsonEncode(securityPatterns)}

DESIGN HEURISTICS FOR VISUAL ANALYSIS:
${jsonEncode(designHeuristics)}

RECENT HISTORY (most recent last):
$historyText$frustrationNote''';
  }

  /// The complete prompt: context block + project files + rough prompt + flag.
  String buildFullPrompt({
    required String fileContents,
    required String roughPrompt,
    required bool issuesEnabled,
  }) {
    return '''
${buildContextBlock()}

CURRENT REQUEST:
PROJECT FILES:
$fileContents

USER PROMPT:
$roughPrompt

issues_enabled: $issuesEnabled
''';
  }

  /// Resolves a display stack label ("React + Tailwind", "Vanilla HTML/CSS/JS")
  /// to the primary knowledge-base key ("react", "vanilla_js"). Mirrors the
  /// precedence in StackDetector.primaryKnowledgeKey.
  static String _knowledgeKeyFor(String detectedStack) {
    final s = detectedStack.toLowerCase();
    if (s.contains('next')) return 'nextjs';
    if (s.contains('react')) return 'react';
    if (s.contains('vue')) return 'vue';
    if (s.contains('vanilla')) return 'vanilla_js';
    if (s.contains('bootstrap')) return 'bootstrap';
    if (s.contains('tailwind')) return 'tailwind';
    return detectedStack; // fall through — lets an exact key still match
  }

  /// Safe truncation for the history summary — the spec's naive substring(0,80)
  /// throws on prompts shorter than 80 chars, so guard the length.
  static String _preview(String improved, [int max = 80]) {
    if (improved.length <= max) return improved;
    return '${improved.substring(0, max)}...';
  }
}
