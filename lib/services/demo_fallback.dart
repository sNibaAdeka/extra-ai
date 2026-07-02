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
