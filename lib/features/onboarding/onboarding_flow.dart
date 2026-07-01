import 'package:flutter/material.dart';

import '../../models/user_profile.dart';
import '../../widgets/gradient_button.dart';
import 'onboarding_question_card.dart';

/// The 4-step first-launch onboarding. Collects a UserProfile and hands it back
/// via [onComplete]. Shown only when no profile exists yet.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key, required this.onComplete});

  final ValueChanged<UserProfile> onComplete;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  static const _toolChoices = [
    'Cursor',
    'Claude Code',
    'Windsurf',
    'GitHub Copilot',
    'Codex',
    'v0',
    'Other',
  ];

  int _step = 0;

  ExperienceLevel? _experience;
  final Set<String> _tools = {};
  ProjectFocus? _focus;
  ToneLevel? _tone;

  bool get _canAdvance {
    switch (_step) {
      case 0:
        return _experience != null;
      case 1:
        return _tools.isNotEmpty;
      case 2:
        return _focus != null;
      case 3:
        return _tone != null;
      default:
        return false;
    }
  }

  void _next() {
    if (_step < 3) {
      setState(() => _step++);
    } else {
      widget.onComplete(UserProfile(
        experienceLevel: _experience!,
        primaryTools: _tools.toList(),
        projectFocus: _focus!,
        tonePreference: _tone!,
        createdAt: DateTime.now(),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(child: _buildStep());
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _single<ExperienceLevel>(
          title: 'How would you describe your coding experience?',
          values: ExperienceLevel.values,
          current: _experience,
          labelOf: (e) => e.label,
          onPick: (e) => setState(() => _experience = e),
        );
      case 1:
        return OnboardingQuestionCard(
          step: 1,
          totalSteps: 4,
          title: 'Which Code AI tools do you use most?',
          options: [
            for (final t in _toolChoices)
              OnboardingOption(
                label: t,
                multi: true,
                selected: _tools.contains(t),
                onTap: () => setState(() =>
                    _tools.contains(t) ? _tools.remove(t) : _tools.add(t)),
              ),
          ],
          footer: _footer(),
        );
      case 2:
        return _single<ProjectFocus>(
          title: 'What do you mostly build?',
          values: ProjectFocus.values,
          current: _focus,
          labelOf: (e) => e.label,
          onPick: (e) => setState(() => _focus = e),
        );
      case 3:
        return _single<ToneLevel>(
          title: 'How should Extra AI talk to you?',
          values: ToneLevel.values,
          current: _tone,
          labelOf: (e) => e.label,
          onPick: (e) => setState(() => _tone = e),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _single<T>({
    required String title,
    required List<T> values,
    required T? current,
    required String Function(T) labelOf,
    required ValueChanged<T> onPick,
  }) {
    return OnboardingQuestionCard(
      step: _step,
      totalSteps: 4,
      title: title,
      options: [
        for (final v in values)
          OnboardingOption(
            label: labelOf(v),
            selected: current == v,
            onTap: () => onPick(v),
          ),
      ],
      footer: _footer(),
    );
  }

  Widget _footer() {
    return Row(
      children: [
        if (_step > 0)
          GhostButton(
            label: 'Back',
            onPressed: () => setState(() => _step--),
          ),
        if (_step > 0) const SizedBox(width: 10),
        Expanded(
          child: GradientButton(
            label: _step == 3 ? 'Get started' : 'Continue',
            trailing: '→',
            enabled: _canAdvance,
            onPressed: _canAdvance ? _next : null,
          ),
        ),
      ],
    );
  }
}
