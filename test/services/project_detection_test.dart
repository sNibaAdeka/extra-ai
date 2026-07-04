import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:extra_ai/services/project_detection_service.dart';

void main() {
  group('ProjectDetectionService', () {
    test('decodes a file:// workspace uri from Cursor/VSCode storage json', () {
      const json = '{"folder": "file:///Users/me/projects/my-app"}';
      final path = ProjectDetectionService.pathFromWorkspaceJson(json);
      expect(path, '/Users/me/projects/my-app');
    });

    test('handles url-encoded spaces in the workspace path', () {
      const json = '{"folder": "file:///Users/me/My%20App"}';
      expect(
        ProjectDetectionService.pathFromWorkspaceJson(json),
        '/Users/me/My App',
      );
    });

    test('returns null for storage json with no folder', () {
      expect(
        ProjectDetectionService.pathFromWorkspaceJson('{"other": 1}'),
        isNull,
      );
      expect(ProjectDetectionService.pathFromWorkspaceJson('not json'), isNull);
    });

    test('dedupes detected projects by path, keeping first source', () {
      final results = ProjectDetectionService.dedupe([
        const DetectedProject(path: '/a', source: 'Cursor'),
        const DetectedProject(path: '/a', source: 'VS Code'),
        const DetectedProject(path: '/b', source: 'Claude Code'),
      ]);
      expect(results.map((r) => r.path), ['/a', '/b']);
      expect(results.first.source, 'Cursor');
    });

    test(
      'scanForClaudeProjects finds dirs containing a .claude folder',
      () async {
        final tmp = await Directory.systemTemp.createTemp('extra_ai_detect');
        final proj = Directory('${tmp.path}/cool-project')..createSync();
        Directory('${proj.path}/.claude').createSync();
        Directory('${tmp.path}/not-a-project').createSync();

        final found = await ProjectDetectionService.scanForClaudeProjects(
          roots: [tmp.path],
          maxDepth: 3,
        );
        expect(found.map((p) => p.path), contains(proj.path));
        expect(found.every((p) => p.source == 'Claude Code'), isTrue);

        await tmp.delete(recursive: true);
      },
    );

    test(
      'scanForCodexProjects finds project folders under a Codex root',
      () async {
        final tmp = await Directory.systemTemp.createTemp('extra_ai_codex');
        final root = Directory('${tmp.path}/Codex')..createSync();
        final project = Directory('${root.path}/mini-app')..createSync();
        File(
          '${project.path}/package.json',
        ).writeAsStringSync('{"name":"mini"}');
        Directory('${root.path}/notes-only').createSync();

        final found = await ProjectDetectionService.scanForCodexProjects(
          roots: [root.path],
          maxDepth: 3,
        );
        expect(found.map((p) => p.path), contains(project.path));
        expect(found.every((p) => p.source == 'Codex'), isTrue);

        await tmp.delete(recursive: true);
      },
    );

    test(
      'scan respects the timeout and returns what it found so far',
      () async {
        // A missing root shouldn't throw; empty result is fine.
        final found = await ProjectDetectionService.scanForClaudeProjects(
          roots: ['/definitely/not/here'],
          maxDepth: 3,
          timeout: const Duration(milliseconds: 200),
        );
        expect(found, isEmpty);
      },
    );
  });
}
