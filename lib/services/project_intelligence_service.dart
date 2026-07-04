import '../models/project_intelligence.dart';
import 'file_service.dart';

/// Builds a local product/architecture brief from the selected project
/// snapshot. This is intentionally deterministic and cheap: it runs before
/// every analysis and makes the LLM prompt less stale and less guessy.
class ProjectIntelligenceService {
  ProjectIntelligenceService._();

  static ProjectIntelligence analyze({
    required String projectPath,
    required LoadedProject project,
  }) {
    final files = project.fileNames;
    final lowerFiles = files.map((f) => f.toLowerCase()).toList();
    final content = project.concatenatedContent.toLowerCase();

    final toolchain = <String>{
      if (_hasAny(lowerFiles, ['pubspec.yaml'])) 'Flutter',
      if (_hasAny(lowerFiles, ['package.json'])) 'Node',
      if (content.contains('"react"') || content.contains('from "react"'))
        'React',
      if (content.contains('"next"') || _hasAny(lowerFiles, ['next.config']))
        'Next.js',
      if (content.contains('tailwind') ||
          _hasAny(lowerFiles, ['tailwind.config']))
        'Tailwind',
      if (content.contains('vite') || _hasAny(lowerFiles, ['vite.config']))
        'Vite',
      if (content.contains('hive') || content.contains('hive_flutter'))
        'Hive local storage',
      if (content.contains('gemini') ||
          content.contains('google_generative_ai'))
        'Gemini',
    }.toList();

    final sourceRoots = <String>{
      for (final name in files)
        if (name.contains('/')) name.split('/').first,
    }.where(_isSourceRoot).toList()..sort();

    final entrypoints = files.where(_isEntrypoint).take(8).toList();
    final importantFiles = files.where(_isImportantFile).take(16).toList();
    final packageManager = _packageManager(lowerFiles);
    final checks = _recommendedChecks(toolchain, lowerFiles);
    final risks = _riskFlags(project, toolchain, lowerFiles);
    final displayName = _displayName(projectPath);

    return ProjectIntelligence(
      summary: _summary(displayName, toolchain, sourceRoots),
      packageManager: packageManager,
      toolchain: toolchain,
      sourceRoots: sourceRoots,
      entrypoints: entrypoints,
      importantFiles: importantFiles,
      recommendedChecks: checks,
      riskFlags: risks,
    );
  }

  static bool _hasAny(List<String> files, List<String> needles) {
    return files.any((file) => needles.any(file.contains));
  }

  static bool _isSourceRoot(String root) {
    const roots = {
      'app',
      'assets',
      'components',
      'docs',
      'lib',
      'macos',
      'pages',
      'src',
      'test',
      'tests',
      'tool',
    };
    return roots.contains(root);
  }

  static bool _isEntrypoint(String file) {
    final lower = file.toLowerCase();
    return lower == 'main.dart' ||
        lower.endsWith('/main.dart') ||
        lower == 'lib/main.dart' ||
        lower.endsWith('/app.dart') ||
        lower.endsWith('/app.tsx') ||
        lower.endsWith('/app.jsx') ||
        lower.endsWith('/page.tsx') ||
        lower.endsWith('/index.tsx') ||
        lower.endsWith('/index.jsx') ||
        lower.endsWith('/main.ts') ||
        lower.endsWith('/main.tsx');
  }

  static bool _isImportantFile(String file) {
    final lower = file.toLowerCase();
    return _isEntrypoint(file) ||
        lower.endsWith('pubspec.yaml') ||
        lower.endsWith('package.json') ||
        lower.contains('prompt') ||
        lower.contains('overlay') ||
        lower.contains('gemini') ||
        lower.contains('project') ||
        lower.contains('theme') ||
        lower.contains('auth') ||
        lower.contains('security');
  }

  static String _packageManager(List<String> files) {
    if (_hasAny(files, ['pnpm-lock.yaml'])) return 'pnpm';
    if (_hasAny(files, ['yarn.lock'])) return 'yarn';
    if (_hasAny(files, ['package-lock.json'])) return 'npm';
    if (_hasAny(files, ['pubspec.yaml'])) return 'flutter pub';
    return 'Unknown';
  }

  static List<String> _recommendedChecks(
    List<String> toolchain,
    List<String> files,
  ) {
    final checks = <String>{
      if (toolchain.contains('Flutter')) 'flutter analyze',
      if (toolchain.contains('Flutter')) 'flutter test',
      if (toolchain.any((t) => t == 'React' || t == 'Next.js' || t == 'Vite'))
        'npm run lint',
      if (toolchain.any((t) => t == 'React' || t == 'Next.js' || t == 'Vite'))
        'npm run build',
      if (_hasAny(files, ['test/', 'tests/'])) 'run focused tests',
    }.toList();
    return checks.isEmpty ? const ['run the smallest relevant check'] : checks;
  }

  static List<String> _riskFlags(
    LoadedProject project,
    List<String> toolchain,
    List<String> files,
  ) {
    final risks = <String>{
      if (project.redactedSecretCount > 0)
        '${project.redactedSecretCount} secret-like value(s) were redacted',
      if (project.fileNames.length >= 28)
        'context snapshot is near the file limit; ask the agent to inspect related files',
      if (toolchain.contains('Gemini'))
        'LLM/API behavior should expose clear error states',
      if (toolchain.contains('Hive local storage'))
        'local persistence needs migration-safe data shapes',
      if (!_hasAny(files, ['test/']) && !_hasAny(files, ['tests/']))
        'no tests detected in the selected snapshot',
    }.toList();
    return risks;
  }

  static String _summary(
    String displayName,
    List<String> toolchain,
    List<String> sourceRoots,
  ) {
    final stack = toolchain.isEmpty ? 'unknown stack' : toolchain.join(' + ');
    final roots = sourceRoots.isEmpty
        ? 'no source roots detected'
        : sourceRoots.join(', ');
    return '$displayName uses $stack; key roots: $roots.';
  }

  static String _displayName(String projectPath) {
    final normalized = projectPath.replaceAll('\\', '/');
    final trimmed = normalized.endsWith('/')
        ? normalized.substring(0, normalized.length - 1)
        : normalized;
    final idx = trimmed.lastIndexOf('/');
    return idx == -1 ? trimmed : trimmed.substring(idx + 1);
  }
}
