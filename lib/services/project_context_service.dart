// PRIVACY NOTE: ProjectContext is stored locally via Hive only. See
// history_service.dart for the full privacy statement.

import 'package:hive/hive.dart';

import '../models/project_context.dart';
import 'stack_detector.dart';

/// Persists one ProjectContext per unique project path (keyed by path hash) so
/// Extra AI recognizes "I've seen this project before" across sessions, and
/// tracks how many analyses have run against it.
class ProjectContextService {
  ProjectContextService(this._box);

  static const String boxName = 'project_contexts';
  final Box _box;

  ProjectContext? get(String projectPath) {
    final raw = _box.get(projectPath.hashCode.toString());
    if (raw is Map) {
      return ProjectContext.fromMap(Map<String, dynamic>.from(raw));
    }
    return null;
  }

  /// Detects (or refreshes) the context for a set of dropped files under a
  /// project path, incrementing the analysis count and persisting it.
  Future<ProjectContext> observe({
    required String projectPath,
    required Map<String, String> files,
  }) async {
    final now = DateTime.now();
    final existing = get(projectPath);
    final stack = StackDetector.detect(files);

    final context = existing == null
        ? ProjectContext(
            projectPath: projectPath,
            detectedStack: stack,
            fileNames: files.keys.toList(),
            firstSeenAt: now,
            lastAnalyzedAt: now,
            totalAnalysesCount: 0,
          )
        : existing.copyWith(
            detectedStack: stack,
            fileNames: files.keys.toList(),
            lastAnalyzedAt: now,
          );

    await _box.put(context.pathHash, context.toMap());
    return context;
  }

  /// Records that an analysis completed for this project (bumps the counter).
  Future<void> recordAnalysis(ProjectContext context) async {
    final updated = context.copyWith(
      totalAnalysesCount: context.totalAnalysesCount + 1,
      lastAnalyzedAt: DateTime.now(),
    );
    await _box.put(updated.pathHash, updated.toMap());
  }
}
