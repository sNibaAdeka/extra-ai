enum ResponseQualityStatus { passed, warning, failed }

/// Local, deterministic quality gate for a generated prompt. It complements
/// the optional second-model critic and works even when no critic API is
/// configured.
class ResponseQualityReport {
  const ResponseQualityReport({
    required this.status,
    required this.passedChecks,
    required this.warnings,
    required this.failedChecks,
  });

  final ResponseQualityStatus status;
  final List<String> passedChecks;
  final List<String> warnings;
  final List<String> failedChecks;

  bool get passed => status == ResponseQualityStatus.passed;
  bool get hasProblems => warnings.isNotEmpty || failedChecks.isNotEmpty;

  String get label => switch (status) {
    ResponseQualityStatus.passed => 'Local check passed',
    ResponseQualityStatus.warning => 'Needs review',
    ResponseQualityStatus.failed => 'Context mismatch',
  };

  String get summary {
    if (failedChecks.isNotEmpty) return failedChecks.first;
    if (warnings.isNotEmpty) return warnings.first;
    return passedChecks.isEmpty
        ? 'Prompt shape looks usable.'
        : passedChecks.first;
  }
}
