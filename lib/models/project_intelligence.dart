/// A compact local "project brief" built from the selected folder before every
/// analysis. It gives Gemini stable product context without sending random or
/// stale file lists.
class ProjectIntelligence {
  const ProjectIntelligence({
    required this.summary,
    required this.packageManager,
    required this.toolchain,
    required this.sourceRoots,
    required this.entrypoints,
    required this.importantFiles,
    required this.recommendedChecks,
    required this.riskFlags,
  });

  final String summary;
  final String packageManager;
  final List<String> toolchain;
  final List<String> sourceRoots;
  final List<String> entrypoints;
  final List<String> importantFiles;
  final List<String> recommendedChecks;
  final List<String> riskFlags;

  bool get hasSignals =>
      toolchain.isNotEmpty ||
      entrypoints.isNotEmpty ||
      importantFiles.isNotEmpty;

  String toPromptBlock() {
    return '''
PROJECT INTELLIGENCE:
- Summary: $summary
- Package manager: $packageManager
- Toolchain: ${_joinOrNone(toolchain)}
- Source roots: ${_joinOrNone(sourceRoots)}
- Entrypoints: ${_joinOrNone(entrypoints)}
- Important files: ${_joinOrNone(importantFiles)}
- Recommended checks: ${_joinOrNone(recommendedChecks)}
- Risk flags: ${_joinOrNone(riskFlags)}
''';
  }

  static String _joinOrNone(List<String> values) =>
      values.isEmpty ? 'None detected' : values.join(', ');
}
