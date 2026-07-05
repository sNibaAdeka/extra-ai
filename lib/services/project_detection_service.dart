import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'stack_detector.dart';

/// A project surfaced by auto-detection (linking screen).
class DetectedProject {
  const DetectedProject({
    required this.path,
    required this.source,
    this.stack = 'Unknown',
  });

  final String path;

  /// Which tool it was detected from ("Cursor", "VS Code", "Claude Code").
  final String source;
  final String stack;

  String get name {
    final t = path.endsWith('/') ? path.substring(0, path.length - 1) : path;
    final i = t.lastIndexOf('/');
    return i == -1 ? t : t.substring(i + 1);
  }

  DetectedProject withStack(String s) =>
      DetectedProject(path: path, source: source, stack: s);
}

/// Detects projects the user is already working on, from the recent-workspace
/// storage of common Code AI tools and shallow scans for tool markers.
/// Every scan is bounded (depth + timeout) so it never hangs on large drives.
class ProjectDetectionService {
  ProjectDetectionService._();

  static String get _home =>
      Platform.environment['HOME'] ??
      Platform.environment['USERPROFILE'] ??
      '';

  /// Cursor/VS Code keep workspaceStorage under Application Support on
  /// macOS and under %APPDATA% (Roaming) on Windows.
  static String _workspaceStorage(String product) {
    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'] ?? '$_home\\AppData\\Roaming';
      return '$appData\\$product\\User\\workspaceStorage';
    }
    return '$_home/Library/Application Support/$product/User/workspaceStorage';
  }

  /// Full detection across all sources, deduped and stack-tagged.
  static Future<List<DetectedProject>> detectAll({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final deadline = DateTime.now().add(timeout);
    final results = <DetectedProject>[];

    results.addAll(
      await _fromWorkspaceStorage(_workspaceStorage('Cursor'), 'Cursor'),
    );
    results.addAll(
      await _fromWorkspaceStorage(_workspaceStorage('Code'), 'VS Code'),
    );
    results.addAll(await _fromCodexStorage());
    results.addAll(await _fromClaudeStorage());

    final remaining = deadline.difference(DateTime.now());
    if (remaining > Duration.zero) {
      results.addAll(
        await scanForClaudeProjects(
          roots: [
            '$_home/Documents',
            '$_home/Projects',
            '$_home/Developer',
            '$_home/Desktop',
          ],
          maxDepth: 3,
          timeout: remaining,
        ),
      );
    }
    final codexRemaining = deadline.difference(DateTime.now());
    if (codexRemaining > Duration.zero) {
      results.addAll(
        await scanForCodexProjects(
          roots: [
            '$_home/Documents/Codex',
            '$_home/Documents',
            '$_home/Projects',
            '$_home/Developer',
            '$_home/Desktop',
          ],
          maxDepth: 3,
          timeout: codexRemaining,
        ),
      );
    }

    final deduped = dedupe(results);
    // Tag each with a detected stack from a shallow listing (best effort).
    return [for (final p in deduped) p.withStack(await _detectStack(p.path))];
  }

  /// Reads a Cursor/VS Code `workspaceStorage` dir; each subfolder has a
  /// `workspace.json` pointing at the opened folder.
  static Future<List<DetectedProject>> _fromWorkspaceStorage(
    String storagePath,
    String source,
  ) async {
    final dir = Directory(storagePath);
    if (!await dir.exists()) return const [];
    final out = <DetectedProject>[];
    try {
      await for (final entry in dir.list(followLinks: false)) {
        if (entry is! Directory) continue;
        final wsFile = File('${entry.path}/workspace.json');
        if (!await wsFile.exists()) continue;
        final path = pathFromWorkspaceJson(await wsFile.readAsString());
        if (path != null && await Directory(path).exists()) {
          out.add(DetectedProject(path: path, source: source));
        }
      }
    } catch (_) {
      // Unreadable storage dir — skip rather than fail the whole detection.
    }
    return out;
  }

  /// Reads local Codex desktop/CLI metadata for recently used working folders.
  /// Only paths are imported; command contents and prompts are ignored.
  static Future<List<DetectedProject>> _fromCodexStorage() async {
    final out = <DetectedProject>[];
    await _addJsonPaths(
      out,
      File('$_home/.codex/process_manager/chat_processes.json'),
      const {'cwd'},
      'Codex',
    );

    final ambientDir = Directory('$_home/.codex/ambient-suggestions');
    if (await ambientDir.exists()) {
      var read = 0;
      try {
        await for (final entry in ambientDir.list(followLinks: false)) {
          if (read >= 60) break;
          if (entry is! Directory) continue;
          final file = File('${entry.path}/ambient-suggestions.json');
          if (await file.exists()) {
            await _addJsonPaths(out, file, const {'projectRoot'}, 'Codex');
            read++;
          }
        }
      } catch (_) {
        // Ignore unreadable Codex cache entries.
      }
    }
    return out;
  }

  /// Reads Claude Code session metadata for projects opened there.
  static Future<List<DetectedProject>> _fromClaudeStorage() async {
    final root = Directory('$_home/.claude/projects');
    if (!await root.exists()) return const [];

    final out = <DetectedProject>[];
    var filesRead = 0;
    try {
      await for (final projectDir in root.list(followLinks: false)) {
        if (filesRead >= 90) break;
        if (projectDir is! Directory) continue;
        await for (final entry in projectDir.list(followLinks: false)) {
          if (filesRead >= 90) break;
          if (entry is! File || !entry.path.endsWith('.jsonl')) continue;
          final paths = await _pathsFromJsonl(entry, const {
            'cwd',
          }, maxLines: 12);
          for (final path in paths) {
            await _addExistingProject(out, path, 'Claude Code');
          }
          filesRead++;
        }
      }
    } catch (_) {
      // Ignore unreadable Claude project caches.
    }
    return out;
  }

  static Future<void> _addJsonPaths(
    List<DetectedProject> out,
    File file,
    Set<String> keys,
    String source,
  ) async {
    if (!await file.exists()) return;
    try {
      final stat = await file.stat();
      if (stat.size > 1000000) return;
      final decoded = jsonDecode(await file.readAsString());
      for (final path in _pathsFromJson(decoded, keys)) {
        await _addExistingProject(out, path, source);
      }
    } catch (_) {
      // Corrupt or unexpected cache files are non-fatal.
    }
  }

  static Future<List<String>> _pathsFromJsonl(
    File file,
    Set<String> keys, {
    int maxLines = 10,
  }) async {
    final paths = <String>[];
    try {
      final lines = file
          .openRead()
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      var count = 0;
      await for (final line in lines) {
        if (count++ >= maxLines) break;
        try {
          paths.addAll(_pathsFromJson(jsonDecode(line), keys));
        } catch (_) {
          // Skip malformed jsonl entries.
        }
      }
    } catch (_) {
      // Ignore unreadable session files.
    }
    return paths;
  }

  static List<String> _pathsFromJson(Object? value, Set<String> keys) {
    final paths = <String>[];

    void walk(Object? node) {
      if (node is Map) {
        for (final entry in node.entries) {
          final key = entry.key;
          final value = entry.value;
          if (key is String && keys.contains(key) && value is String) {
            paths.add(value);
          } else {
            walk(value);
          }
        }
      } else if (node is List) {
        for (final item in node) {
          walk(item);
        }
      }
    }

    walk(value);
    return paths;
  }

  static Future<void> _addExistingProject(
    List<DetectedProject> out,
    String path,
    String source,
  ) async {
    final dir = Directory(path);
    if (await dir.exists() && await _looksLikeProject(path)) {
      out.add(DetectedProject(path: path, source: source));
    }
  }

  /// Extracts the local folder path from a workspace.json `folder` uri.
  static String? pathFromWorkspaceJson(String jsonStr) {
    try {
      final json = jsonDecode(jsonStr);
      if (json is! Map) return null;
      final folder = json['folder'];
      if (folder is! String) return null;
      final uri = Uri.tryParse(folder);
      if (uri == null || uri.scheme != 'file') return null;
      return Uri.decodeComponent(uri.path);
    } catch (_) {
      return null;
    }
  }

  /// Shallow scan (bounded depth + timeout) for directories that contain a
  /// `.claude` folder — a signal of a Claude Code project.
  static Future<List<DetectedProject>> scanForClaudeProjects({
    required List<String> roots,
    int maxDepth = 3,
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final deadline = DateTime.now().add(timeout);
    final found = <DetectedProject>[];

    Future<void> walk(Directory dir, int depth) async {
      if (depth > maxDepth || DateTime.now().isAfter(deadline)) return;
      List<FileSystemEntity> children;
      try {
        children = await dir.list(followLinks: false).toList();
      } catch (_) {
        return;
      }
      final hasClaude = children.any(
        (e) => e is Directory && e.path.endsWith('/.claude'),
      );
      if (hasClaude) {
        found.add(DetectedProject(path: dir.path, source: 'Claude Code'));
        return; // don't descend into a matched project
      }
      for (final child in children) {
        if (child is! Directory) continue;
        final base = child.path.split('/').last;
        if (base.startsWith('.') || base == 'node_modules') continue;
        if (DateTime.now().isAfter(deadline)) return;
        await walk(child, depth + 1);
      }
    }

    for (final root in roots) {
      final dir = Directory(root);
      if (await dir.exists()) {
        await walk(dir, 0);
      }
    }
    return found;
  }

  /// Bounded scan for folders that Codex can reasonably treat as projects:
  /// explicit `.codex` markers anywhere, or normal project markers under a
  /// `Documents/Codex`-style root.
  static Future<List<DetectedProject>> scanForCodexProjects({
    required List<String> roots,
    int maxDepth = 3,
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final deadline = DateTime.now().add(timeout);
    final found = <DetectedProject>[];

    Future<void> walk(Directory dir, int depth, bool underCodexRoot) async {
      if (depth > maxDepth || DateTime.now().isAfter(deadline)) return;
      List<FileSystemEntity> children;
      try {
        children = await dir.list(followLinks: false).toList();
      } catch (_) {
        return;
      }
      final names = children.map((e) => e.path.split('/').last).toSet();
      final hasCodexMarker = names.contains('.codex');
      final hasProjectMarker = _hasProjectMarker(names);
      if (hasCodexMarker || (underCodexRoot && hasProjectMarker)) {
        found.add(DetectedProject(path: dir.path, source: 'Codex'));
        return;
      }
      for (final child in children) {
        if (child is! Directory) continue;
        final base = child.path.split('/').last;
        if (_shouldSkipDirectory(base)) continue;
        if (DateTime.now().isAfter(deadline)) return;
        await walk(child, depth + 1, underCodexRoot);
      }
    }

    for (final root in roots) {
      final dir = Directory(root);
      if (await dir.exists()) {
        final rootName = root.split('/').last.toLowerCase();
        await walk(dir, 0, rootName == 'codex');
      }
    }
    return found;
  }

  /// Keep the first occurrence per path (source priority = scan order).
  static List<DetectedProject> dedupe(List<DetectedProject> input) {
    final seen = <String>{};
    final out = <DetectedProject>[];
    for (final p in input) {
      if (seen.add(p.path)) out.add(p);
    }
    return out;
  }

  static Future<bool> _looksLikeProject(String path) async {
    try {
      final names = <String>{};
      await for (final entry in Directory(path).list(followLinks: false)) {
        names.add(entry.path.split('/').last);
        if (names.length > 80) break;
      }
      return _hasProjectMarker(names);
    } catch (_) {
      return false;
    }
  }

  static bool _hasProjectMarker(Set<String> names) {
    const markers = {
      '.git',
      '.codex',
      '.claude',
      'pubspec.yaml',
      'package.json',
      'pnpm-lock.yaml',
      'yarn.lock',
      'package-lock.json',
      'pyproject.toml',
      'requirements.txt',
      'Cargo.toml',
      'go.mod',
      'Package.swift',
      'project.pbxproj',
      'README.md',
    };
    if (names.any(markers.contains)) return true;
    return names.contains('lib') ||
        names.contains('src') ||
        names.contains('app') ||
        names.contains('ios') ||
        names.contains('macos');
  }

  static bool _shouldSkipDirectory(String base) {
    return base.startsWith('.') ||
        base == 'node_modules' ||
        base == 'Pods' ||
        base == 'build' ||
        base == 'dist' ||
        base == '.dart_tool';
  }

  /// Detects the stack from a shallow listing of a project folder.
  static Future<String> _detectStack(String path) async {
    try {
      final dir = Directory(path);
      final files = <String, String>{};
      await for (final entry in dir.list(followLinks: false)) {
        if (entry is! File) continue;
        final name = entry.path.split('/').last;
        // Only read small signature files (package.json etc.).
        if (name == 'package.json' ||
            name.endsWith('.config.js') ||
            name.endsWith('.html')) {
          try {
            final stat = await entry.stat();
            if (stat.size < 200000) files[name] = await entry.readAsString();
          } catch (_) {
            files[name] = '';
          }
        } else {
          files[name] = '';
        }
      }
      return StackDetector.detect(files);
    } catch (_) {
      return 'Unknown';
    }
  }
}
