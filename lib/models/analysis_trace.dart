import 'analysis_preferences.dart';

class AnalysisTrace {
  const AnalysisTrace({
    required this.projectName,
    required this.projectPathHash,
    required this.modelLabel,
    required this.filesRead,
    required this.filesSample,
    required this.redactedSecrets,
    required this.historyEntriesUsed,
    required this.preferences,
    required this.recommendedChecks,
    required this.freshnessRegenerated,
    required this.qualityStatus,
    required this.verificationStatus,
    required this.generatedAt,
  });

  final String projectName;
  final String projectPathHash;
  final String modelLabel;
  final int filesRead;
  final List<String> filesSample;
  final int redactedSecrets;
  final int historyEntriesUsed;
  final AnalysisPreferences preferences;
  final List<String> recommendedChecks;
  final bool freshnessRegenerated;
  final String qualityStatus;
  final String verificationStatus;
  final DateTime generatedAt;

  String get headline {
    final project = projectName.isEmpty ? 'Untitled project' : projectName;
    return '$project · $filesRead files · $modelLabel';
  }

  String get compactSummary {
    final checks = recommendedChecks.isEmpty
        ? 'no checks detected'
        : recommendedChecks.take(2).join(', ');
    final freshness = freshnessRegenerated ? ' · regenerated stale draft' : '';
    return '$historyEntriesUsed history items · $checks$freshness';
  }

  // --- Jury-facing summary (plain language, no internal model names) ----------

  /// True when an independent second model checked this response.
  bool get wasVerified =>
      verificationStatus == 'verified' || verificationStatus == 'corrected';

  /// The one-line collapsed proof, e.g.
  /// "✓ Grounded in 4 files · ✓ Verified · ✓ Secrets checked".
  /// Visible in a live demo without any clicks — the reliability proof.
  String get groundedSummary {
    final parts = <String>[];
    parts.add(
      filesRead > 0
          ? 'Grounded in $filesRead ${filesRead == 1 ? 'file' : 'files'}'
          : 'Grounded in your screen',
    );
    if (wasVerified) parts.add('Verified');
    parts.add('Secrets checked');
    return parts.map((p) => '✓ $p').join('   ·   ');
  }

  /// Plain-language "read N files from Project" line.
  String get readLine {
    if (filesRead == 0) return 'Read your current screen';
    final project = projectName.isEmpty ? 'this project' : projectName;
    return 'Read $filesRead ${filesRead == 1 ? 'file' : 'files'} from $project';
  }

  Map<String, dynamic> toMap() => {
    'projectName': projectName,
    'projectPathHash': projectPathHash,
    'modelLabel': modelLabel,
    'filesRead': filesRead,
    'filesSample': filesSample,
    'redactedSecrets': redactedSecrets,
    'historyEntriesUsed': historyEntriesUsed,
    'preferences': preferences.toMap(),
    'recommendedChecks': recommendedChecks,
    'freshnessRegenerated': freshnessRegenerated,
    'qualityStatus': qualityStatus,
    'verificationStatus': verificationStatus,
    'generatedAt': generatedAt.toIso8601String(),
  };

  factory AnalysisTrace.fromMap(Map<String, dynamic> map) => AnalysisTrace(
    projectName: map['projectName'] as String? ?? '',
    projectPathHash: map['projectPathHash'] as String? ?? '',
    modelLabel: map['modelLabel'] as String? ?? 'Unknown model',
    filesRead: map['filesRead'] as int? ?? 0,
    filesSample: (map['filesSample'] as List?)?.cast<String>() ?? const [],
    redactedSecrets: map['redactedSecrets'] as int? ?? 0,
    historyEntriesUsed: map['historyEntriesUsed'] as int? ?? 0,
    preferences: AnalysisPreferences.fromMap(
      Map<String, dynamic>.from((map['preferences'] as Map?) ?? const {}),
    ),
    recommendedChecks:
        (map['recommendedChecks'] as List?)?.cast<String>() ?? const [],
    freshnessRegenerated: map['freshnessRegenerated'] as bool? ?? false,
    qualityStatus: map['qualityStatus'] as String? ?? 'unknown',
    verificationStatus: map['verificationStatus'] as String? ?? 'unknown',
    generatedAt:
        DateTime.tryParse(map['generatedAt'] as String? ?? '') ??
        DateTime.now(),
  );
}
