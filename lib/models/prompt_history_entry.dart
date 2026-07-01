/// One past analysis for a project. Session memory (Layer 3) — the last 5 per
/// project are kept (FIFO), and the last 3 are fed back into each new request
/// so Gemini isn't amnesiac between iterations.
class PromptHistoryEntry {
  const PromptHistoryEntry({
    required this.projectPathHash,
    required this.roughPrompt,
    required this.improvedPrompt,
    required this.issuesFound,
    required this.timestamp,
  });

  final String projectPathHash;
  final String roughPrompt;
  final String improvedPrompt;
  final List<String> issuesFound;
  final DateTime timestamp;

  Map<String, dynamic> toMap() => {
        'projectPathHash': projectPathHash,
        'roughPrompt': roughPrompt,
        'improvedPrompt': improvedPrompt,
        'issuesFound': issuesFound,
        'timestamp': timestamp.toIso8601String(),
      };

  factory PromptHistoryEntry.fromMap(Map<String, dynamic> map) =>
      PromptHistoryEntry(
        projectPathHash: map['projectPathHash'] as String? ?? '',
        roughPrompt: map['roughPrompt'] as String? ?? '',
        improvedPrompt: map['improvedPrompt'] as String? ?? '',
        issuesFound: (map['issuesFound'] as List?)?.cast<String>() ?? const [],
        timestamp: DateTime.tryParse(map['timestamp'] as String? ?? '') ??
            DateTime.now(),
      );
}
