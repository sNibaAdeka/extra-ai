import 'dart:io';

import '../security/secret_redactor.dart';

/// A project's files after reading + secret redaction, ready to embed in a
/// Gemini request. The original unredacted content is never retained here.
class LoadedProject {
  const LoadedProject({
    required this.fileNames,
    required this.redactedContentByName,
    required this.concatenatedContent,
    required this.redactedSecretCount,
  });

  final List<String> fileNames;
  final Map<String, String> redactedContentByName;

  /// All files concatenated, each labeled by name — the block sent to Gemini.
  final String concatenatedContent;

  /// How many secrets were redacted across all files (for the trust notice).
  final int redactedSecretCount;

  bool get isEmpty => fileNames.isEmpty;
}

/// Reads project files and — critically — redacts secrets BEFORE the content is
/// ever used, concatenated, stored, or transmitted. Disk/picker reading is a
/// thin wrapper over the pure [buildFromRaw] assembly so the security-critical
/// logic is fully testable.
class FileService {
  FileService._();

  /// Pure assembly from an in-memory map of fileName -> raw content. Runs
  /// redaction on each file, then concatenates with per-file labels.
  static LoadedProject buildFromRaw(Map<String, String> rawByName) {
    final redactedByName = <String, String>{};
    final buffer = StringBuffer();
    var totalRedactions = 0;

    for (final entry in rawByName.entries) {
      final result = SecretRedactor.redactWithCount(entry.value);
      redactedByName[entry.key] = result.redacted;
      totalRedactions += result.count;

      buffer.writeln('--- ${entry.key} ---');
      buffer.writeln(result.redacted);
      buffer.writeln();
    }

    return LoadedProject(
      fileNames: rawByName.keys.toList(growable: false),
      redactedContentByName: redactedByName,
      concatenatedContent: buffer.toString(),
      redactedSecretCount: totalRedactions,
    );
  }

  /// Reads the given file paths from disk (best-effort, skipping unreadable or
  /// binary-looking files) and returns a redacted [LoadedProject].
  static Future<LoadedProject> loadFromPaths(List<String> paths) async {
    final raw = <String, String>{};
    for (final path in paths) {
      final file = File(path);
      try {
        if (!await file.exists()) continue;
        final content = await file.readAsString();
        raw[_baseName(path)] = content;
      } catch (_) {
        // Unreadable / binary file — skip it rather than fail the whole load.
        continue;
      }
    }
    return buildFromRaw(raw);
  }

  /// Reads a compact, relevant snapshot of a whole project folder. This is the
  /// default context path for Extra AI: the user picks a project, then every
  /// analysis gets fresh local code instead of stale manually attached files.
  static Future<LoadedProject> loadProjectSnapshot(
    String projectPath, {
    String query = '',
    int maxFiles = 32,
    int maxTotalChars = 430000,
  }) async {
    final root = Directory(projectPath);
    if (!await root.exists()) return buildFromRaw(const {});

    final files = <_CandidateFile>[];
    try {
      await _walkProject(root, root.path, files, query: query);
    } catch (_) {
      return buildFromRaw(const {});
    }

    files.sort((a, b) => b.score.compareTo(a.score));
    final raw = <String, String>{};
    var total = 0;
    for (final candidate in files.take(maxFiles * 2)) {
      if (raw.length >= maxFiles || total >= maxTotalChars) break;
      try {
        final stat = await candidate.file.stat();
        if (stat.size > 120000) continue;
        final content = await candidate.file.readAsString();
        if (_looksBinary(content)) continue;
        final remaining = maxTotalChars - total;
        if (remaining <= 0) break;
        raw[candidate.relativePath] = content.length > remaining
            ? content.substring(0, remaining)
            : content;
        total += raw[candidate.relativePath]!.length;
      } catch (_) {
        continue;
      }
    }

    return buildFromRaw(raw);
  }

  static Future<void> _walkProject(
    Directory dir,
    String rootPath,
    List<_CandidateFile> out, {
    required String query,
    int depth = 0,
  }) async {
    if (depth > 5 || out.length > 220) return;
    final children = await dir.list(followLinks: false).toList();
    for (final child in children) {
      final name = _baseName(child.path);
      if (child is Directory) {
        if (_skipDir(name)) continue;
        await _walkProject(
          child,
          rootPath,
          out,
          query: query,
          depth: depth + 1,
        );
      } else if (child is File) {
        if (!_isUsefulSourceFile(name)) continue;
        final relative = _relativePath(rootPath, child.path);
        out.add(_CandidateFile(child, relative, _score(relative, query)));
      }
    }
  }

  static bool _skipDir(String name) {
    return name.startsWith('.') ||
        name == 'node_modules' ||
        name == 'build' ||
        name == 'dist' ||
        name == '.dart_tool' ||
        name == 'Pods' ||
        name == 'DerivedData' ||
        name == 'coverage';
  }

  static bool _isUsefulSourceFile(String name) {
    const exact = {
      'pubspec.yaml',
      'package.json',
      'tailwind.config.js',
      'tailwind.config.ts',
      'next.config.js',
      'next.config.ts',
      'vite.config.js',
      'vite.config.ts',
      'README.md',
    };
    if (exact.contains(name)) return true;
    const extensions = [
      '.dart',
      '.swift',
      '.kt',
      '.js',
      '.jsx',
      '.ts',
      '.tsx',
      '.vue',
      '.svelte',
      '.css',
      '.scss',
      '.html',
      '.json',
      '.md',
      '.yaml',
      '.yml',
    ];
    return extensions.any(name.endsWith);
  }

  static int _score(String relativePath, String query) {
    final lower = relativePath.toLowerCase();
    var score = 0;
    if (lower.startsWith('lib/') ||
        lower.startsWith('src/') ||
        lower.startsWith('app/') ||
        lower.startsWith('components/')) {
      score += 24;
    }
    if (lower.contains('main') ||
        lower.contains('app') ||
        lower.contains('index') ||
        lower.contains('page') ||
        lower.contains('layout') ||
        lower.contains('component')) {
      score += 12;
    }
    if (lower.endsWith('.tsx') ||
        lower.endsWith('.dart') ||
        lower.endsWith('.swift') ||
        lower.endsWith('.css')) {
      score += 8;
    }
    for (final token in query.toLowerCase().split(RegExp(r'[^a-zа-я0-9]+'))) {
      if (token.length < 3) continue;
      if (lower.contains(token)) score += 20;
    }
    return score;
  }

  static String _relativePath(String rootPath, String path) {
    final normalizedRoot = rootPath.endsWith('/') ? rootPath : '$rootPath/';
    if (path.startsWith(normalizedRoot)) {
      return path.substring(normalizedRoot.length);
    }
    return _baseName(path);
  }

  static bool _looksBinary(String content) {
    if (content.isEmpty) return false;
    final sample = content.length > 4000 ? content.substring(0, 4000) : content;
    return sample.codeUnits.where((c) => c == 0).isNotEmpty;
  }

  static String _baseName(String path) {
    final normalized = path.replaceAll('\\', '/');
    final idx = normalized.lastIndexOf('/');
    return idx == -1 ? normalized : normalized.substring(idx + 1);
  }
}

class _CandidateFile {
  const _CandidateFile(this.file, this.relativePath, this.score);

  final File file;
  final String relativePath;
  final int score;
}
