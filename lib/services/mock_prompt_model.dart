import 'dart:convert';

import 'gemini_service.dart';

/// Local-only model used by MOCK_DATA=true. It lets the UI and analysis flow
/// work on this Mac even when Gemini billing/credits are unavailable.
class MockPromptModel implements PromptModel {
  const MockPromptModel();

  @override
  Future<String?> generate(String prompt, {List<int>? screenshotBytes}) async {
    final roughPrompt = _extractSection(prompt, 'USER PROMPT:').trim();
    final files = _extractFiles(prompt);
    final target = files.isEmpty
        ? 'the hero section file, likely @src/components/Hero.tsx or @app/page.tsx'
        : '@${files.first}';
    final userAsk = roughPrompt.isEmpty
        ? 'сделай экран визуально чище и понятнее'
        : roughPrompt;

    return jsonEncode({
      'improved_prompt':
          'In $target, implement this current request: "$userAsk". Inspect the '
          'nearby related files first, keep the change tightly scoped, preserve '
          'existing routing/state behavior, and match the Extra AI warm dark '
          'visual system from extrai.org: bg-void/bg-mid surfaces, cream text, '
          'ember accent only for active states and primary actions, subtle grid '
          'texture, and clipped-corner product surfaces. Verify desktop and '
          'mobile sizing so controls do not overlap or overflow.',
      'issues': [
        'Mock mode is active, so this response is generated locally and does not prove the Gemini API is reachable.',
        'If the output repeats, turn MOCK_DATA off and check Gemini quota/billing for the configured key.',
        'Make sure the selected project folder is correct so the generated prompt references the right files.',
      ],
      'clarifying_question': null,
    });
  }

  static String _extractSection(String prompt, String marker) {
    final start = prompt.indexOf(marker);
    if (start == -1) return '';
    final rest = prompt.substring(start + marker.length);
    final next = rest.indexOf('\n\n');
    return next == -1 ? rest : rest.substring(0, next);
  }

  static List<String> _extractFiles(String prompt) {
    final matches =
        RegExp(r'^(?:FILE:\s*|---\s*)(.+?)(?:\s*---)?$', multiLine: true)
            .allMatches(prompt)
            .map((m) => m.group(1)!.trim())
            .where((name) => name.isNotEmpty)
            .toList(growable: false);
    return matches;
  }
}
