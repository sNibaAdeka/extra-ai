/// Detects signals of user frustration in the rough prompt so the response can
/// be CALIBRATED (tighter, calmer, solution-first) — never surfaced to the user
/// as "we detected you're frustrated". This is calibration, not detection
/// theater. Requires at least two independent signals to avoid false positives.
class FrustrationDetector {
  FrustrationDetector._();

  static final RegExp _repeatWords = RegExp(
    r'\b(again|still|опять|снова)\b',
    caseSensitive: false,
  );

  static bool detect(String prompt) {
    final trimmed = prompt.trim();
    final signals = <bool>[
      trimmed.contains('!!'),
      trimmed.toUpperCase() == trimmed && trimmed.length > 5,
      _repeatWords.hasMatch(trimmed),
    ];
    return signals.where((s) => s).length >= 2;
  }
}
