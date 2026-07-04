import 'dart:convert';

import 'package:crypto/crypto.dart';

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
    this.linkedAtOnboarding = false,
  });

  final String projectPath;
  final String detectedStack;
  final List<String> fileNames;
  final DateTime firstSeenAt;
  final DateTime lastAnalyzedAt;
  final int totalAnalysesCount;

  /// True when the user linked this project during the onboarding step.
  final bool linkedAtOnboarding;

  /// Stable key for Hive storage — a hash of the project path.
  String get pathHash => stablePathHash(projectPath);

  /// Legacy key used before v0.1.0. Kept only for local migration/lookups.
  String get legacyPathHash => projectPath.hashCode.toString();

  /// Deterministic across app launches. Dart's String.hashCode is not suitable
  /// for persisted project identity.
  static String stablePathHash(String path) {
    final normalized = path.trim().replaceAll('\\', '/');
    return sha1.convert(utf8.encode(normalized)).toString();
  }

  /// Folder name (last path segment) for display.
  String get displayName {
    final normalized = projectPath.replaceAll('\\', '/');
    final trimmed = normalized.endsWith('/')
        ? normalized.substring(0, normalized.length - 1)
        : normalized;
    final idx = trimmed.lastIndexOf('/');
    return idx == -1 ? trimmed : trimmed.substring(idx + 1);
  }

  ProjectContext copyWith({
    String? projectPath,
    String? detectedStack,
    List<String>? fileNames,
    DateTime? firstSeenAt,
    DateTime? lastAnalyzedAt,
    int? totalAnalysesCount,
    bool? linkedAtOnboarding,
  }) {
    return ProjectContext(
      projectPath: projectPath ?? this.projectPath,
      detectedStack: detectedStack ?? this.detectedStack,
      fileNames: fileNames ?? this.fileNames,
      firstSeenAt: firstSeenAt ?? this.firstSeenAt,
      lastAnalyzedAt: lastAnalyzedAt ?? this.lastAnalyzedAt,
      totalAnalysesCount: totalAnalysesCount ?? this.totalAnalysesCount,
      linkedAtOnboarding: linkedAtOnboarding ?? this.linkedAtOnboarding,
    );
  }

  Map<String, dynamic> toMap() => {
    'projectPath': projectPath,
    'detectedStack': detectedStack,
    'fileNames': fileNames,
    'firstSeenAt': firstSeenAt.toIso8601String(),
    'lastAnalyzedAt': lastAnalyzedAt.toIso8601String(),
    'totalAnalysesCount': totalAnalysesCount,
    'linkedAtOnboarding': linkedAtOnboarding,
  };

  factory ProjectContext.fromMap(Map<String, dynamic> map) => ProjectContext(
    projectPath: map['projectPath'] as String? ?? '',
    detectedStack: map['detectedStack'] as String? ?? 'Unknown',
    fileNames: (map['fileNames'] as List?)?.cast<String>() ?? const [],
    firstSeenAt:
        DateTime.tryParse(map['firstSeenAt'] as String? ?? '') ??
        DateTime.now(),
    lastAnalyzedAt:
        DateTime.tryParse(map['lastAnalyzedAt'] as String? ?? '') ??
        DateTime.now(),
    totalAnalysesCount: map['totalAnalysesCount'] as int? ?? 0,
    linkedAtOnboarding: map['linkedAtOnboarding'] as bool? ?? false,
  );
}
