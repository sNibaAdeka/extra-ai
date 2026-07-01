/// The structured response Gemini returns (raw JSON only). Parsing/validation
/// is enforced by ResponseValidator — this model assumes already-clean input.
class ExtraAIResponse {
  const ExtraAIResponse({
    required this.improvedPrompt,
    required this.issues,
    this.clarifyingQuestion,
  });

  final String improvedPrompt;
  final List<String> issues;

  /// One specific question if intent was ambiguous; otherwise null.
  final String? clarifyingQuestion;

  bool get hasClarifyingQuestion =>
      clarifyingQuestion != null && clarifyingQuestion!.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
        'improved_prompt': improvedPrompt,
        'issues': issues,
        'clarifying_question': clarifyingQuestion,
      };

  /// Lenient parse — assumes structural validation already happened upstream in
  /// ResponseValidator. Caps issues at 3 defensively.
  factory ExtraAIResponse.fromJson(Map<String, dynamic> json) {
    final rawIssues = (json['issues'] as List?) ?? const [];
    final issues =
        rawIssues.map((e) => e.toString()).take(3).toList(growable: false);

    final rawQuestion = json['clarifying_question'];
    final question = (rawQuestion == null || rawQuestion == 'null')
        ? null
        : rawQuestion.toString();

    return ExtraAIResponse(
      improvedPrompt: json['improved_prompt']?.toString() ?? '',
      issues: issues,
      clarifyingQuestion:
          (question != null && question.trim().isEmpty) ? null : question,
    );
  }
}
