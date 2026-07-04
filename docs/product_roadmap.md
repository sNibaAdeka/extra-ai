# Extra AI Product Roadmap

## Product Direction

Extra AI should feel like a small professional agent that lives above the user's coding stack, not like another chat window. The core product promise is speed: the user says the rough thing, Extra AI reads the screen and project, then produces a precise prompt or agent instruction with minimal ceremony.

## Strongest Product Upgrades

1. Project Intelligence
   - Build a local project brief for every selected folder: stack, source roots, entrypoints, toolchain, important files, likely checks, and risk flags.
   - Refresh this brief before every analysis so Gemini never uses stale project context.
   - Show a compact project status in the overlay and dashboard.

2. Agent Workflow Modes
   - Prompt: copy-ready instruction for Cursor, Codex, Claude Code, or Windsurf.
   - Full Access: instruction asks the coding agent to inspect related files first.
   - Auto Edit: instruction asks the coding agent to edit, run checks, and summarize changes.
   - Bug/Security Audit: optional pass that adds risk checks without overwhelming the normal flow.

3. Production-Grade Response Pipeline
   - One stable JSON schema for Gemini output.
   - One verification pass that checks whether the prompt references real files and matches the user's requested action.
   - Better error surfaces: invalid API key, quota, no selected project, stale project, empty context.

4. Backend-Ready Architecture
   - Keep local-first privacy for code and secrets.
   - Introduce clean service boundaries for future cloud sync: accounts, projects, histories, billing, templates, and telemetry.
   - Use local adapters now, cloud adapters later.

5. Frontend Polish
   - Minimal composer by default; advanced controls behind a clear expand control.
   - Draggable overlay, readable hover tooltips, professional loading states.
   - Dashboard should make projects, recent analyses, and product health obvious at a glance.

6. Quality and Safety
   - Secret redaction before any network request.
   - Prompt-injection framing: user code is data, never instructions.
   - Regression tests for project scanning, prompt building, fallback behavior, and UI overflow.

## Implementation Phases

### Phase 1 - Product Foundation

- Create project intelligence model and service.
- Inject project intelligence into every Gemini request.
- Make the overlay controls understandable and low-noise.
- Keep all code context fresh when a project changes.

### Phase 2 - Reliable Agent Output

- Harden the output schema.
- Add response validation for real file references.
- Add actionable error states and retry controls.
- Add copy/edit state so the overlay never loses user input unexpectedly.

### Phase 3 - App Shell

- Improve dashboard project list.
- Add per-project health/status cards.
- Add history filters by project/tool/mode.
- Add settings for model, privacy, hotkeys, and integrations.

### Phase 4 - Production Backend

- Add account/billing abstraction.
- Add encrypted cloud sync option for project metadata only.
- Add team/project sharing without uploading raw code by default.
- Add telemetry that tracks product health without collecting code.

## First Vertical Slice

The first slice is Project Intelligence. It is high-leverage because every other feature depends on knowing what project is active and what files matter.
