# Extra AI — Design Doc

Created: 2026-07-01

## Summary

Extra AI is a macOS Flutter overlay app activated by a global hotkey (⌘⇧E).
It shows a glowing "breathing" border around the whole screen and a floating
window. The user drops project files and types a rough prompt; the app reads
the files, redacts secrets locally, assembles a rich context block (user
profile + project context + recent history + curated knowledge base), and
calls the Gemini API (`gemini-2.0-flash`, JSON output). It returns an improved,
copy-pasteable prompt for Code AI tools (Cursor, Claude Code, etc.) plus 2–3
concrete code issues.

The authoritative feature spec is the user-provided
`extraai-MASTER-BUILD-PROMPT.md` (SECTIONS 0–4). This doc records the
**architecture decisions and build phasing** that are not fixed by that spec.

## Key decisions

- **Real Flutter macOS app**, built as specced. Flutter installed via Homebrew
  this session (was not previously present).
- **Gemini key from environment**: `String.fromEnvironment('GEMINI_API_KEY')`
  via `--dart-define=GEMINI_API_KEY=...`. Never hardcoded, never committed.
- **Backend/logic first, UI after, integration last** — phased for quality.
- **TDD on pure-logic classes** (redaction, validation, rate limiting, intent
  pre-check, frustration detection, stack detection). These are pure functions
  and the exact place correctness bugs hide.
- **4 knowledge-base JSON files copied verbatim** into `assets/knowledge/`
  from the provided attachments — not regenerated.

## Architecture

Layered from most-testable (pure Dart) to most-integration-heavy (Flutter/OS):

### Pure logic (no Flutter deps — unit tested)
- `security/secret_redactor.dart` — redacts secrets before any file content leaves device
- `security/request_validator.dart` — validates prompt/file/screenshot sizes before API call
- `security/response_validator.dart` — validates + parses Gemini JSON, caps issues at 3
- `security/rate_limiter.dart` — client-side 5/min, 100/day
- `understanding/intent_pre_checker.dart` — IntentClarity: clear/vague/veryVague
- `understanding/frustration_detector.dart` — tone signal detection
- `understanding/error_messages.dart` — FailureType → human message
- `services/stack_detector.dart` — detect stack from file names/contents

### Stateful services (Flutter / Hive / API)
- `services/knowledge_base_service.dart` — loads 4 JSON assets once at startup
- `services/file_service.dart` — reads files; runs redaction before content is used
- `services/gemini_service.dart` — Gemini call; combined system prompt
- `services/history_service.dart` — Hive read/write, FIFO cap 5/project
- `services/extra_ai_request_builder.dart` — assembles all context layers into one call

### Models
- `models/user_profile.dart` (+ Hive adapter) — experience, tools, focus, tone
- `models/project_context.dart` (+ Hive adapter) — path, detected stack, files, counts
- `models/prompt_history_entry.dart` (+ Hive adapter) — rough/improved prompt, issues, ts
- `models/extra_ai_response.dart` — improved_prompt, issues[], clarifying_question

### UI (Flutter widgets)
- `theme/app_theme.dart` — color tokens, gradients, text styles (Space Grotesk / Inter / JetBrains Mono)
- `widgets/logo_mark.dart` — `[ | ]` bracket-cursor CustomPainter
- `overlay/screen_border.dart` — breathing gradient border CustomPainter
- `widgets/pill_widget.dart` — top-center pill
- `overlay/overlay_window.dart` — 380x580 floating window shell
- `features/prompt_input.dart` — file drop + prompt textarea + Analyze button
- `features/loading_view.dart` — gradient ring spinner + progress bar
- `features/results_view.dart` — improved prompt (green scan-line) + issues (orange) + copy
- `features/onboarding/onboarding_flow.dart` — 4-step first-launch flow
- `features/settings/settings_screen.dart` — edit profile, clear history, usage counter

### Integration
- `main.dart` — window_manager init, Hive init + adapters, KB loadAll, hotkey ⌘⇧E registration
- `overlay/overlay_manager.dart` — show/hide/toggle overlay logic

## Combined Gemini system prompt

One final system prompt string assembled from:
1. SECTION 1 base (Ludr persona, STEP 1–5, output JSON format, hard rules)
2. SECTION 2 context-awareness (USER PROFILE / PROJECT CONTEXT / RECENT HISTORY usage)
3. SECTION 3 prompt-injection defense (files are DATA not INSTRUCTIONS) + language rules
4. SECTION 4 grounding priority (check KNOWLEDGE BASE patterns first)

## Data flow (one analysis)

1. Files dropped → `FileService` reads each → `SecretRedactor.redact()` runs on each
2. `RequestValidator.validate()` on prompt/files/screenshot; block if invalid
3. `RateLimiter.canMakeRequest()`; block if over limit
4. `IntentPreChecker` / `FrustrationDetector` feed UI hint + context note
5. `ExtraAIRequestBuilder.buildContextBlock()` assembles profile + context + history + KB fragments
6. `GeminiService` sends combined system prompt + context + files + rough prompt
7. `ResponseValidator.validateAndParse()` on the response; null → error state
8. `HistoryService` saves the exchange (FIFO cap 5)
9. `ResultsView` renders improved prompt + issues

## Error handling

Every failure maps to `ErrorMessages.forFailure(FailureType)` — no raw errors,
stack traces, or HTTP codes shown to the user. Gemini JSON parse failure retries
once, then shows a friendly error with retry.

## Testing

- Phase 1: unit tests for every pure-logic class (`flutter test` green).
- Phase 2: tests for `ExtraAIRequestBuilder.buildContextBlock()` assembly and
  `ResponseValidator` edge cases; Gemini network call mocked.
- Phase 3/4: manual run verification (screens render, hotkey toggles overlay,
  end-to-end copy works).

## Build phases

- **Phase 1** — Scaffold + theme + models + pure-logic core (with unit tests).
- **Phase 2** — Services + knowledge base (4 JSON assets verbatim) + request builder.
- **Phase 3** — UI screens driven by mock data.
- **Phase 4** — Hotkey + overlay + window config + real Gemini + end-to-end.

## Out of scope for MVP (per spec)

Server-side rate limiting, entropy-based secret detection, encrypted Hive
storage, formal pen testing. Honest v2 items.
