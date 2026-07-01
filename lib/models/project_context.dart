/// Per-project context, auto-detected and persisted per unique project path.
/// Lets Extra AI recognize "I've seen this project before" across sessions.
class ProjectContext {
  const ProjectContext({
    required this.projectPath,
    required this.detectedStack,
    required this.fileNames,
    required this.firstSeenAt,
    required this.lastAnalyzedAt,
    required this.totalAnalysesCount,
  });

  final String projectPath;
  final String detectedStack;
  final List<String> fileNames;
  final DateTime firstSeenAt;
  final DateTime lastAnalyzedAt;
  final int totalAnalysesCount;

  /// Stable key for Hive storage — a hash of the project path.
  String get pathHash => projectPath.hashCode.toString();

  ProjectContext copyWith({
    String? projectPath,
    String? detectedStack,
    List<String>? fileNames,
    DateTime? firstSeenAt,
    DateTime? lastAnalyzedAt,
    int? totalAnalysesCount,
  }) {
    return ProjectContext(
      projectPath: projectPath ?? this.projectPath,
      detectedStack: detectedStack ?? this.detectedStack,
      fileNames: fileNames ?? this.fileNames,
      firstSeenAt: firstSeenAt ?? this.firstSeenAt,
      lastAnalyzedAt: lastAnalyzedAt ?? this.lastAnalyzedAt,
      totalAnalysesCount: totalAnalysesCount ?? this.totalAnalysesCount,
    );
  }

  Map<String, dynamic> toMap() => {
        'projectPath': projectPath,
        'detectedStack': detectedStack,
        'fileNames': fileNames,
        'firstSeenAt': firstSeenAt.toIso8601String(),
        'lastAnalyzedAt': lastAnalyzedAt.toIso8601String(),
        'totalAnalysesCount': totalAnalysesCount,
      };

  factory ProjectContext.fromMap(Map<String, dynamic> map) => ProjectContext(
        projectPath: map['projectPath'] as String? ?? '',
        detectedStack: map['detectedStack'] as String? ?? 'Unknown',
        fileNames: (map['fileNames'] as List?)?.cast<String>() ?? const [],
        firstSeenAt: DateTime.tryParse(map['firstSeenAt'] as String? ?? '') ??
            DateTime.now(),
        lastAnalyzedAt:
            DateTime.tryParse(map['lastAnalyzedAt'] as String? ?? '') ??
                DateTime.now(),
        totalAnalysesCount: map['totalAnalysesCount'] as int? ?? 0,
      );
}
