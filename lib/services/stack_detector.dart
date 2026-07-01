/// Auto-detects a project's tech stack from its file names and contents so
/// Extra AI can pull the right knowledge-base patterns and write
/// framework-appropriate suggestions — instead of the user typing it manually.
///
/// Input: a map of fileName -> fileContent (content may be truncated/redacted).
class StackDetector {
  StackDetector._();

  static const String unknown = 'Unknown';

  /// Returns a human-readable stack label, e.g. "React + Tailwind",
  /// "Next.js + Tailwind", "Vue", "Vanilla HTML/CSS/JS", or "Unknown".
  static String detect(Map<String, String> files) {
    if (files.isEmpty) return unknown;

    final names = files.keys.map((k) => k.toLowerCase()).toSet();
    final packageJson = _findPackageJson(files);
    final hasPackageJson = packageJson != null;

    final parts = <String>[];

    if (hasPackageJson) {
      final pkg = packageJson.toLowerCase();
      final hasNext = names.contains('next.config.js') ||
          names.contains('next.config.mjs') ||
          names.contains('next.config.ts') ||
          _dependsOn(pkg, 'next');

      if (hasNext) {
        parts.add('Next.js');
      } else if (_dependsOn(pkg, 'react')) {
        parts.add('React');
      } else if (_dependsOn(pkg, 'vue')) {
        parts.add('Vue');
      } else if (_dependsOn(pkg, 'svelte')) {
        parts.add('Svelte');
      }

      if (_hasTailwind(names) || _dependsOn(pkg, 'tailwindcss')) {
        parts.add('Tailwind');
      }
      if (_dependsOn(pkg, 'bootstrap')) {
        parts.add('Bootstrap');
      }
    } else {
      // No package.json — likely a static/vanilla site.
      final hasHtml = names.any((n) => n.endsWith('.html'));
      final hasJs = names.any((n) => n.endsWith('.js'));
      if (hasHtml || hasJs) {
        parts.add('Vanilla HTML/CSS/JS');
      }
      if (_hasTailwind(names) ||
          files.values.any((c) => c.contains('tailwind'))) {
        parts.add('Tailwind');
      }
      if (files.values.any((c) => c.toLowerCase().contains('bootstrap'))) {
        parts.add('Bootstrap');
      }
    }

    if (parts.isEmpty) return unknown;
    return parts.join(' + ');
  }

  /// Maps the detected stack to the primary knowledge-base key used to look up
  /// stack_patterns.json (e.g. "react", "nextjs", "vue", "vanilla_js").
  static String primaryKnowledgeKey(Map<String, String> files) {
    final stack = detect(files).toLowerCase();
    if (stack.contains('next')) return 'nextjs';
    if (stack.contains('react')) return 'react';
    if (stack.contains('vue')) return 'vue';
    if (stack.contains('vanilla')) return 'vanilla_js';
    if (stack.contains('bootstrap')) return 'bootstrap';
    if (stack.contains('tailwind')) return 'tailwind';
    return 'vanilla_js';
  }

  static String? _findPackageJson(Map<String, String> files) {
    for (final entry in files.entries) {
      if (entry.key.toLowerCase().endsWith('package.json')) return entry.value;
    }
    return null;
  }

  static bool _dependsOn(String lowerPackageJson, String dep) {
    // Match "dep" as a JSON key: `"dep":`
    return RegExp('"${RegExp.escape(dep)}"\\s*:').hasMatch(lowerPackageJson);
  }

  static bool _hasTailwind(Set<String> lowerNames) {
    return lowerNames.any((n) => n.startsWith('tailwind.config.'));
  }
}
