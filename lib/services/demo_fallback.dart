// ============================================================================
// DEMO-ONLY SAFETY NET — NOT A PRODUCT FEATURE.
//
// Enabled exclusively via --dart-define=DEMO_FALLBACK=true for the live jury
// pitch: if BOTH live API attempts fail mid-demo, the app shows this known-good
// pre-recorded response instead of an error screen. It is never triggered in
// normal builds (the flag defaults to false) and must not ship enabled.
// Remove or keep disabled after the demo.
// ============================================================================

import '../models/extra_ai_response.dart';

/// A realistic, pre-recorded "known good" analysis for the demo project.
const ExtraAIResponse kDemoFallbackResponse = ExtraAIResponse(
  improvedPrompt:
      'In @style.css, update the .cta-button background to the brand accent '
      '(#B5E04A) and darken its text to #10120B for contrast. Preserve the '
      'existing hover transition and border-radius. Do not modify any styles '
      'outside the .cta-button rule, and keep all markup in index.html '
      'unchanged.',
  issues: [
    'The .hero <img> in index.html has no alt attribute — add descriptive alt text for accessibility.',
    'script.js attaches a click listener inside render() on every call without removing the previous one — this leaks listeners; register it once or use event delegation.',
    'The layout grid in style.css has no breakpoint below 768px — content overflows horizontally on mobile widths.',
  ],
);

ExtraAIResponse buildContextualFallbackResponse({
  required String roughPrompt,
  required List<String> fileNames,
}) {
  final target = fileNames.isEmpty
      ? 'the selected project'
      : '@${fileNames.first}';
  final trimmed = roughPrompt.trim().isEmpty
      ? 'improve the current UI'
      : roughPrompt.trim();
  return ExtraAIResponse(
    improvedPrompt:
        'In $target, implement this request: "$trimmed". First inspect adjacent related files in the selected project, then make the smallest safe change that matches the existing Extra AI visual system. Preserve current behavior, avoid unrelated refactors, and verify the result on the active screen size. If the change affects UI, check spacing, contrast, responsiveness, and hover states before reporting completion.',
    issues: const [
      'Live Gemini was unavailable, so this fallback prompt was generated locally from the current request instead of reusing an old canned result.',
      'Make sure the selected project folder is correct before applying this prompt in a coding tool.',
      'If the same API error repeats, check Gemini quota or billing for the configured API key.',
    ],
  );
}
