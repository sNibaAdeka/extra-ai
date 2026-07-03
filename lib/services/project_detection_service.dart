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
/// storage of common Code AI tools and a shallow scan for `.claude` folders.
/// Every scan is bounded (depth + timeout) so it never hangs on large drives.
class ProjectDetectionService {
  ProjectDetectionService._();

  static String get _home => Platform.environment['HOME'] ?? '';

  /// Full detection across all sources, deduped and stack-tagged.
  static Future<List<DetectedProject>> detectAll({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final deadline = DateTime.now().add(timeout);
    final results = <DetectedProject>[];

    results.addAll(await _fromWorkspaceStorage(
      '$_home/Library/Application Support/Cursor/User/workspaceStorage',
      'Cursor',
    ));
    results.addAll(await _fromWorkspaceStorage(
      '$_home/Library/Application Support/Code/User/workspaceStorage',
      'VS Code',
    ));

    final remaining = deadline.difference(DateTime.now());
    if (remaining > Duration.zero) {
      results.addAll(await scanForClaudeProjects(
        roots: [
          '$_home/Documents',
          '$_home/Projects',
          '$_home/Developer',
          '$_home/Desktop',
        ],
        maxDepth: 3,
        timeout: remaining,
      ));
    }

    final deduped = dedupe(results);
    // Tag each with a detected stack from a shallow listing (best effort).
    return [
      for (final p in deduped) p.withStack(await _detectStack(p.path)),
    ];
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
      final hasClaude =
          children.any((e) => e is Directory && e.path.endsWith('/.claude'));
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

  /// Keep the first occurrence per path (source priority = scan order).
  static List<DetectedProject> dedupe(List<DetectedProject> input) {
    final seen = <String>{};
    final out = <DetectedProject>[];
    for (final p in input) {
      if (seen.add(p.path)) out.add(p);
    }
    return out;
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
