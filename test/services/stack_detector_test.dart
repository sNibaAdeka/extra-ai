import 'package:flutter_test/flutter_test.dart';
import 'package:extra_ai/services/stack_detector.dart';

void main() {
  group('StackDetector', () {
    test('detects React from package.json with react dependency', () {
      final files = {
        'package.json': '{"dependencies": {"react": "^18.0.0"}}',
        'App.jsx': 'export default function App() {}',
      };
      expect(StackDetector.detect(files), contains('React'));
    });

    test('appends Tailwind when tailwind.config.js is present', () {
      final files = {
        'package.json': '{"dependencies": {"react": "^18.0.0"}}',
        'tailwind.config.js': 'module.exports = {}',
      };
      final result = StackDetector.detect(files);
      expect(result, contains('React'));
      expect(result, contains('Tailwind'));
    });

    test('detects Next.js from next.config.js', () {
      final files = {
        'package.json': '{"dependencies": {"next": "14.0.0", "react": "18"}}',
        'next.config.js': 'module.exports = {}',
      };
      expect(StackDetector.detect(files), contains('Next.js'));
    });

    test('detects Vanilla HTML/CSS/JS when no package.json', () {
      final files = {
        'index.html': '<!DOCTYPE html>',
        'style.css': 'body {}',
        'script.js': 'console.log(1)',
      };
      expect(StackDetector.detect(files), contains('Vanilla'));
    });

    test('detects Vue from package.json vue dependency', () {
      final files = {
        'package.json': '{"dependencies": {"vue": "^3.0.0"}}',
      };
      expect(StackDetector.detect(files), contains('Vue'));
    });

    test('detects Bootstrap when referenced', () {
      final files = {
        'index.html': '<link href="bootstrap.min.css">',
        'package.json': '{"dependencies": {"bootstrap": "^5.3.0"}}',
      };
      expect(StackDetector.detect(files), contains('Bootstrap'));
    });

    test('returns Unknown for an empty file set', () {
      expect(StackDetector.detect(const {}), 'Unknown');
    });

    test('produces a knowledge-base key from the detected stack', () {
      final files = {
        'package.json': '{"dependencies": {"react": "^18"}}',
        'tailwind.config.js': '',
      };
      // "React + Tailwind" -> primary KB key should resolve to "react".
      expect(StackDetector.primaryKnowledgeKey(files), 'react');
    });

    test('vanilla stack maps to vanilla_js knowledge key', () {
      final files = {'index.html': '<html>', 'app.js': ''};
      expect(StackDetector.primaryKnowledgeKey(files), 'vanilla_js');
    });
  });
}
