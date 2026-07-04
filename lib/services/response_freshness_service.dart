import '../models/extra_ai_response.dart';
import '../models/prompt_history_entry.dart';

/// Detects a common LLM failure mode: the response validates structurally but
/// is essentially a replay of a previous prompt for a different user request.
class ResponseFreshnessService {
  const ResponseFreshnessService._();

  static bool looksStale({
    required ExtraAIResponse response,
    required String roughPrompt,
    required List<PromptHistoryEntry> recentHistory,
  }) {
    final draft = _normalize(response.improvedPrompt);
    final currentAsk = _normalize(roughPrompt);
    if (draft.length < 24 || currentAsk.isEmpty) return false;

    for (final entry in recentHistory) {
      final previousDraft = _normalize(entry.improvedPrompt);
      final previousAsk = _normalize(entry.roughPrompt);
      final draftSimilarity = _similarity(draft, previousDraft);
      final askSimilarity = _similarity(currentAsk, previousAsk);
      if (draftSimilarity >= 0.92 && askSimilarity < 0.82) {
        return true;
      }
    }
    return false;
  }

  static String _normalize(String input) => input
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'[^\p{L}\p{N}@/._ -]+', unicode: true), '')
      .trim();

  static double _similarity(String a, String b) {
    if (a == b) return 1;
    if (a.isEmpty || b.isEmpty) return 0;
    final aTokens = _tokens(a);
    final bTokens = _tokens(b);
    if (aTokens.isEmpty || bTokens.isEmpty) return 0;
    final intersection = aTokens.intersection(bTokens).length;
    final union = aTokens.union(bTokens).length;
    return union == 0 ? 0 : intersection / union;
  }

  static Set<String> _tokens(String value) => value
      .split(RegExp(r'[^a-zа-я0-9@/._-]+', caseSensitive: false))
      .where((token) => token.length >= 3)
      .toSet();
}
