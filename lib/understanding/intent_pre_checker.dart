/// How clear the user's rough prompt is. Lets the UI set expectations before
/// sending (a very broad prompt gets an inline hint), and lets Gemini prefer
/// history-based disambiguation over asking a clarifying question.
enum IntentClarity { clear, vague, veryVague }

/// Lightweight, offline pre-check of the rough prompt. Never blocks sending —
/// only informs the UI hint and the context block.
class IntentPreChecker {
  IntentPreChecker._();

  static const List<String> _vagueWords = [
    'fix',
    'better',
    'nice',
    'good',
    'improve',
    // Russian
    'исправь',
    'лучше',
    'покрасивее',
    'сделай норм',
  ];

  static IntentClarity check(String roughPrompt) {
    final trimmed = roughPrompt.trim();
    if (trimmed.isEmpty) return IntentClarity.veryVague;

    final wordCount = trimmed.split(RegExp(r'\s+')).length;
    final lower = trimmed.toLowerCase();
    final hasVagueWord = _vagueWords.any(lower.contains);

    if (wordCount <= 2 && hasVagueWord) return IntentClarity.veryVague;
    if (wordCount <= 4) return IntentClarity.vague;
    return IntentClarity.clear;
  }
}
