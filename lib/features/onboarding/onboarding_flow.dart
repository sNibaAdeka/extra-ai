import 'package:flutter/material.dart';

import '../../models/user_profile.dart';
import '../../theme/app_theme.dart';
import '../../widgets/controls.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/hotkey_capture.dart';
import '../../widgets/shimmer_text.dart';

/// Three-step onboarding (Screens 1–3): welcome, hotkey, profile questions.
/// Two-column layout — text content left (max 480px), framed preview right —
/// with dot pagination. Saves the UserProfile via [onComplete].
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({
    super.key,
    required this.onComplete,
    this.onHotkeyChanged,
  });

  final ValueChanged<UserProfile> onComplete;

  /// Persists a re-captured hotkey combo (Settings wiring).
  final ValueChanged<String>? onHotkeyChanged;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  static const _toolChoices = [
    'Cursor',
    'Windsurf',
    'Claude Code',
    'Codex',
    'v0',
    'GitHub Copilot',
    'Other',
  ];

  int _step = 0;
  String _hotkey = '⌘⇧E';
  bool _capturingHotkey = false;

  ExperienceLevel? _experience;
  final Set<String> _tools = {};
  ProjectFocus? _focus;
  ToneLevel _tone = ToneLevel.explained; // defaults if untouched

  bool get _canFinish =>
      _experience != null && _tools.isNotEmpty && _focus != null;

  void _finish() {
    widget.onComplete(
      UserProfile(
        experienceLevel: _experience!,
        primaryTools: _tools.toList(),
        projectFocus: _focus!,
        tonePreference: _tone,
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Left column: step content + pagination.
        Expanded(
          flex: 11,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedSwitcher(
                    duration: AppTheme.transitionMs,
                    child: KeyedSubtree(
                      key: ValueKey(_step),
                      child: _leftColumn(),
                    ),
                  ),
                  const SizedBox(height: 28),
                  _DotPagination(step: _step),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 32),
        // Right column: framed preview / step cards.
        Expanded(flex: 9, child: _rightColumn()),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Left columns per step
  // ---------------------------------------------------------------------------

  Widget _leftColumn() {
    switch (_step) {
      case 0:
        return _welcomeStep();
      case 1:
        return _hotkeyStep();
      default:
        return _questionsStep();
    }
  }

  Widget _welcomeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _IconPill(
          icon: Icons.shield_outlined,
          label: 'Your data stays local',
        ),
        const SizedBox(height: 18),
        IridescentText(
          'Welcome to Extra AI',
          style: AppTheme.display(size: 40, weight: FontWeight.w600),
        ),
        const SizedBox(height: 14),
        Text(
          'Extra AI looks at your screen and your code, then writes the '
          'exact prompt your next fix needs.',
          style: AppTheme.ui(size: 15, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 20),
        for (final bullet in const [
          'Works with any Code AI — Cursor, Windsurf, Claude Code, Codex',
          "Remembers your project's history, even across tools",
          'Only the current request is ever sent for analysis',
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 3),
                  child: Icon(Icons.check, size: 14, color: AppTheme.accent),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    bullet,
                    style: AppTheme.ui(size: 14, color: AppTheme.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 22),
        SizedBox(
          width: 220,
          child: GradientButton(
            label: 'Get started',
            height: 44,
            onPressed: () => setState(() => _step = 1),
          ),
        ),
      ],
    );
  }

  Widget _hotkeyStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Set your hotkey',
          style: AppTheme.display(size: 34, weight: FontWeight.w600),
        ),
        const SizedBox(height: 14),
        Text(
          'This shortcut activates Extra AI from any app. Press it to open '
          'the overlay and start an analysis.',
          style: AppTheme.ui(size: 15, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            KeycapBadge.combo(_hotkey),
            const SizedBox(width: 12),
            const PillTag('Recommended'),
          ],
        ),
        const SizedBox(height: 16),
        if (_capturingHotkey)
          HotkeyCapture(
            onCaptured: (combo) {
              setState(() {
                _hotkey = combo;
                _capturingHotkey = false;
              });
              widget.onHotkeyChanged?.call(combo);
            },
          )
        else
          GhostButton(
            label: 'Change hotkey',
            height: 38,
            onPressed: () => setState(() => _capturingHotkey = true),
          ),
        const SizedBox(height: 28),
        Row(
          children: [
            GhostButton(
              label: 'Back',
              onPressed: () => setState(() => _step = 0),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 180,
              child: GradientButton(
                label: 'Continue',
                onPressed: () => setState(() => _step = 2),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _questionsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'A few quick questions',
          style: AppTheme.display(size: 34, weight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Text(
          'This helps Extra AI match your experience level and tools.',
          style: AppTheme.ui(size: 15, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 22),
        _selector(
          'Experience level',
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in ExperienceLevel.values)
                SelectChip(
                  label: _experienceLabel(e),
                  selected: _experience == e,
                  onTap: () => setState(() => _experience = e),
                ),
            ],
          ),
        ),
        _selector(
          'Primary tools',
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in _toolChoices)
                SelectChip(
                  label: t,
                  selected: _tools.contains(t),
                  onTap: () => setState(
                    () => _tools.contains(t) ? _tools.remove(t) : _tools.add(t),
                  ),
                ),
            ],
          ),
        ),
        _selector(
          'What you build',
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final f in ProjectFocus.values)
                SelectChip(
                  label: _focusLabel(f),
                  selected: _focus == f,
                  onTap: () => setState(() => _focus = f),
                ),
            ],
          ),
        ),
        _selector(
          'Tone preference',
          SegmentedControl<ToneLevel>(
            options: ToneLevel.values,
            labels: const ['Just the facts', 'Explain a bit'],
            value: _tone,
            onChanged: (v) => setState(() => _tone = v),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            GhostButton(
              label: 'Back',
              onPressed: () => setState(() => _step = 1),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GradientButton(
                label: 'Start using Extra AI',
                enabled: _canFinish,
                onPressed: _canFinish ? _finish : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _selector(String label, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTheme.ui(
              size: 13,
              weight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  static String _experienceLabel(ExperienceLevel e) {
    switch (e) {
      case ExperienceLevel.vibeCoder:
        return 'I vibe-code';
      case ExperienceLevel.promptFirst:
        return 'I write some code';
      case ExperienceLevel.developer:
        return "I'm a developer";
    }
  }

  static String _focusLabel(ProjectFocus f) {
    switch (f) {
      case ProjectFocus.clientSites:
        return 'Client sites';
      case ProjectFocus.saas:
        return 'SaaS';
      case ProjectFocus.personal:
        return 'Personal';
      case ProjectFocus.mobile:
        return 'Mobile';
    }
  }

  // ---------------------------------------------------------------------------
  // Right column per step
  // ---------------------------------------------------------------------------

  Widget _rightColumn() {
    if (_step == 1) return const _FlowStepCards();
    return _FramedPreview(showSuccessBadge: _step == 2);
  }
}

/// Dot pagination: completed steps solid, current filled ember, rest outlined.
class _DotPagination extends StatelessWidget {
  const _DotPagination({required this.step});
  final int step;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < 3; i++)
          Container(
            width: i == step ? 22 : 8,
            height: 8,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: i < step
                  ? AppTheme.accent.withValues(alpha: 0.55)
                  : i == step
                  ? AppTheme.accent
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(100),
              border: i > step
                  ? Border.all(color: AppTheme.textDim.withValues(alpha: 0.6))
                  : null,
            ),
          ),
      ],
    );
  }
}

/// Framed macOS-style window mockup: traffic lights + simplified static
/// preview of an analysis result. Decorative, not interactive.
class _FramedPreview extends StatelessWidget {
  const _FramedPreview({this.showSuccessBadge = false});

  final bool showSuccessBadge;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.borderSubtle),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Traffic lights.
              Row(
                children: [
                  for (final c in const [
                    Color(0xFFFF5F57),
                    Color(0xFFFEBC2E),
                    Color(0xFF28C840),
                  ])
                    Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Improved Prompt',
                style: AppTheme.ui(
                  size: 11,
                  weight: FontWeight.w600,
                  color: AppTheme.accent,
                ),
              ),
              const SizedBox(height: 8),
              for (final w in const [0.92, 0.98, 0.7])
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: FractionallySizedBox(
                    widthFactor: w,
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppTheme.textDim.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                'Issues Found',
                style: AppTheme.ui(
                  size: 11,
                  weight: FontWeight.w600,
                  color: AppTheme.signalOrange,
                ),
              ),
              const SizedBox(height: 8),
              for (final w in const [0.85, 0.6])
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: FractionallySizedBox(
                    widthFactor: w,
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppTheme.textDim.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              Container(
                height: 30,
                decoration: BoxDecoration(
                  gradient: AppTheme.brandGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Copy & Insert',
                  style: AppTheme.ui(
                    size: 11,
                    weight: FontWeight.w600,
                    color: AppTheme.onAccent,
                  ),
                ),
              ),
            ],
          ),
        ),
        // The ONE small green success checkmark allowed in the app —
        // universal "setup complete" signal, deliberately not brand ember.
        if (showSuccessBadge)
          Positioned(
            top: -10,
            right: -10,
            child: Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: AppTheme.success,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, size: 15, color: Colors.white),
            ),
          ),
      ],
    );
  }
}

class _IconPill extends StatelessWidget {
  const _IconPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppTheme.accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTheme.ui(
              size: 11,
              weight: FontWeight.w700,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Step 2 right column: three connected flow cards with arrow connectors.
class _FlowStepCards extends StatelessWidget {
  const _FlowStepCards();

  @override
  Widget build(BuildContext context) {
    const steps = [
      (Icons.keyboard_command_key_rounded, 'Press hotkey'),
      (Icons.center_focus_weak_rounded, 'Point at issue'),
      (Icons.check_circle_outline_rounded, 'Get exact prompt'),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          if (i > 0)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Icon(
                Icons.arrow_forward,
                size: 14,
                color: AppTheme.textDim,
              ),
            ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
              decoration: AppTheme.card(radius: 12),
              child: Column(
                children: [
                  Icon(steps[i].$1, size: 20, color: AppTheme.accent),
                  const SizedBox(height: 8),
                  Text(
                    steps[i].$2,
                    textAlign: TextAlign.center,
                    style: AppTheme.ui(size: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
