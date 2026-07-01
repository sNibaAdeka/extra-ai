# Extra AI — Landing Page Design

Date: 2026-07-01
Status: Approved

## Goal

A premium one-page marketing site for Extra AI (macOS overlay app). Structural
reference is https://www.ludr.dev — layout rhythm, section pacing, the
`~/section-name` terminal-path labeling convention, numbered step sequences,
monospace keyboard-shortcut badges, and large italic emphasis words in
headlines. Copy and color system are original to Extra AI — ludr.dev's actual
text and palette are not reused, only its structural DNA.

Quality bar: Linear / Arc / Raycast / Vercel landing-page tier. Must read as a
specific, funded product — not a templated AI-startup page.

## Repo & Stack

- New, independent repo: `~/extra-ai-landing` (sibling to `Extra AI`, not
  nested inside the Flutter app repo).
- Next.js 15 (App Router), TypeScript strict mode.
- Tailwind CSS v4, tokens as CSS variables (see below).
- shadcn/ui for primitives (accordion, button, badge).
- Framer Motion v12 for scroll-triggered fades and the hero's breathing glow.
- Fonts via `next/font`: Space Grotesk (display/headlines), General Sans
  (body), JetBrains Mono (hotkey badges, code references).
- Icons: Lucide React only — no emoji, no generic lightning-bolt/sparkle
  AI-startup iconography.
- No backend, no CMS, no API calls. Fully static marketing content.

## Design Token System

```css
--bg-void: #170D12;
--bg-mid: #3D2015;
--bg-warm: #6B3620;
--cream-light: #F5E4CC;
--cream-warm: #E8B98A;
--signal-ember: #FF6B35;   /* only for CTAs, active states, step digits */
--grid-line: rgba(245,228,204,0.04);
```

Signature visual devices, carried through every section:
- Faint grid-line texture on dark backgrounds (from the bracket-cursor logo).
- Gradient direction always dark-top-left → warm-bottom-right, never inverted.
- Ember accent reserved for primary CTAs, hover/active states, and the single
  numbered digit in step sequences — never decorative.
- Slightly clipped/cut corners on cards and buttons instead of uniform
  border-radius, echoing the blocky bracket-logo geometry.

## Anti-AI-Slop Requirements

- Apply the `frontend-design` skill's anti-cliché guidance during build: no
  generic AI-startup icon sets, no default shadcn look-and-feel left
  unstyled, no stock gradient blobs.
- Apply `ui-ux-pro-max` skill (mandatory per user's global CLAUDE.md) for
  every UI component: contrast ≥ 4.5:1, touch targets ≥ 44px, mobile-first at
  375/768/1024/1440, semantic color tokens (no raw hex in components), one
  primary CTA per screen.
- Self-critique checkpoint before calling any section done (from the
  original brief):
  1. Does the hero read as Extra AI specifically, or could it be any AI
     startup? Revise if generic.
  2. Is ember used sparingly (CTA/active/digit only)? Pull back if it has
     crept into decoration.
  3. Is there real texture (grid lines, gradient direction, clipped corners),
     or does it read as a flat cream/terracotta template? Add devices back
     if flat.
- Use Magic MCP (`mcp__magic__*`, confirmed connected) for structural
  component reference (hero patterns, pricing layouts, FAQ accordions) —
  adapt fully to Extra AI's token system, never keep default Magic styling
  or copy.

## Sections (in order, with full copy)

### 1. Hero

- Logo: bracket-cursor mark `[|]` + "extra." wordmark, top-left, links to top.
- Small badge above headline: "⌘⇧E · macOS"
- Headline (large, bold geometric, "fix" in ember/gradient emphasis, italic):
  "stop guessing what to *fix* next"
- Subheadline: "Extra AI looks at your site and your code at the same time —
  then writes the exact prompt your next fix needs. Works with Cursor,
  Windsurf, Claude Code, or whatever you're using today."
- CTA button (ember, filled): "Download Extra AI  ⌘⇧E"
- Small text under CTA: "macOS · free to start"
- Background: full gradient (bg-void → bg-warm), faint grid texture, the
  breathing-border visual motif rendered as a subtle ambient glow behind the
  hero content (contained to hero section height, not full-screen).

### 2. `~/the-flow`

- Eyebrow: "~/the-flow"
- Title: "point · describe · *ship.*"
- Subtitle: "three steps. any AI coding tool you already use."
- 01 **Press the hotkey** — Anywhere on your Mac. The overlay appears
  instantly, no app switching.
- 02 **Say what's wrong** — Plain words — "the button looks off on mobile."
  No technical vocabulary needed.
- 03 **Get the exact prompt** — Grounded in your actual screenshot and code —
  copy it straight into Cursor, Windsurf, or Claude Code.

### 3. `~/why`

- Eyebrow: "~/why"
- Title: "it doesn't just read your prompt. *it sees your site.*"
- Subtitle: "most AI tools guess from code alone. Extra AI looks at what
  you're actually looking at."
- Visual: mock screenshot with 3 numbered annotation points:
  1. spacing inconsistent — 13px where the rest of the page uses an 8px scale
  2. contrast 3.8:1 — fails WCAG AA for body text
  3. no mobile breakpoint below 768px
- Caption: "grounded in your real screenshot and your real code — not a
  generic guess."

### 4. `~/memory`

- Eyebrow: "~/memory"
- Title: "it *remembers* your project."
- Subtitle: "switch between Cursor today and Windsurf tomorrow — Extra AI
  still knows what you already tried."
- Thread/log exchange:
  - "Monday, in Cursor: 'fix the header spacing' → Extra AI: adjusted
    .header padding to match your 8px scale"
  - "Wednesday, in Windsurf: 'the header still looks off' → Extra AI: 'You
    already adjusted spacing on Monday — this looks like a different issue:
    the logo image itself is misaligned, not the padding.'"
- Caption: "context that survives switching tools. something no single AI
  coding assistant does today."

### 5. `~/security`

- Eyebrow: "~/security"
- Title: "your secrets *never* leave your machine."
- Subtitle: "API keys, tokens, credentials — redacted locally before
  anything is sent for analysis."
- Three bullets (Lucide icons, not emoji — lock, shield, package glyphs):
  - Local secret redaction — scanned and stripped before any API call
  - Prompt injection defense — your code is treated as data, never as
    commands
  - No backend server — history and project context stay on your device
- Small monospace caption: "only the current request context is sent for
  analysis — nothing else, ever."

### 6. `~/pricing`

- Eyebrow: "~/pricing"
- Title: "start free. *upgrade when it's obvious.*"
- **FREE — $0**: 5 analyses/month · works with any Code AI tool · basic
  prompt grounding · CTA "Download — free"
- **PRO — $9/mo** (marked "Most popular" in ember): unlimited analyses · 1
  active project with memory · tool-specific prompt formatting · CTA "Start
  Pro"
- **STUDIO — $29/mo**: everything in Pro · up to 5 projects · security &
  issue detection included · team sharing · CTA "Start Studio"
- Small text under pricing: "cancel anytime · no credit card for Free"

### 7. `~/faq`

- Eyebrow: "~/faq"
- Title: "questions, *answered.*"
- Which platforms does Extra AI run on? — macOS 13+ (Apple Silicon + Intel
  via universal build). Windows is on the roadmap.
- Does Extra AI work with tools other than Cursor? — Yes — Cursor, Windsurf,
  Claude Code, Codex, and v0 are all supported, with prompt formatting
  adapted to each tool's conventions.
- Where does my code go? — Your screenshot and code are sent only to Gemini
  for the current analysis. Secrets are redacted locally first. Nothing is
  stored on a remote server.
- What's the difference between Free and Pro? — Free gives you 5 analyses a
  month to try it. Pro removes the limit and adds persistent project memory.
- Can I use this without an active Cursor/Windsurf subscription? — Yes —
  Extra AI generates the prompt, you paste it wherever you write code.

### 8. Final CTA

- Eyebrow: "~/⌘⇧e"
- Title: "stop starting from *zero* on every prompt."
- Subtitle: "one hotkey. one look at your screen. one exact prompt."
- CTA (large, ember): "Download Extra AI  ⌘⇧E"
- Small text: "macOS · free to start · 30 second install"

### 9. Footer

- Logo mark, small
- Links: Pricing · Privacy · Terms · GitHub (if applicable)
- © 2026 Extra AI

## Interaction Details

- Hotkey badges: macOS-style keycaps, JetBrains Mono, cream-on-dark, used
  consistently across hero, flow steps, and final CTA.
- Scroll-triggered fade-in per section, 200–300ms, no bounce/elastic easing.
- Hero ambient glow breathing pulse ties web identity to the app's own
  overlay motif.
- Fully responsive at 375/768/1024/1440 — grid texture and gradient
  direction stay consistent at every breakpoint.
- `prefers-reduced-motion` respected everywhere.

## File Structure

```
extra-ai-landing/
├── app/
│   ├── layout.tsx
│   └── page.tsx
├── components/
│   ├── Hero.tsx
│   ├── FlowSteps.tsx
│   ├── GroundingShowcase.tsx
│   ├── MemorySection.tsx
│   ├── SecuritySection.tsx
│   ├── PricingCards.tsx
│   ├── FAQAccordion.tsx
│   ├── FinalCTA.tsx
│   ├── Footer.tsx
│   └── ui/            # shadcn primitives
├── lib/
│   ├── utils.ts        # cn()
│   └── animations.ts   # spring/stagger/easing tokens
├── styles/
│   └── tokens.css
└── public/
    └── logo assets (bracket-cursor mark)
```

## Verification

- Run the dev server and click through the live page in a browser (per
  standing UI-work instructions) — not just a type-check.
- Check all 4 breakpoints for layout/no horizontal scroll.
- Run through the Pre-Delivery Checklist from the user's global CLAUDE.md
  (contrast, focus states, alt text, touch targets, reduced-motion, semantic
  tokens, animation durations).
