import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// A single selectable option row inside an onboarding question. Supports both
/// single-select (radio-like) and multi-select (checkbox-like) behavior via the
/// [selected] flag; the parent owns selection state.
class OnboardingOption extends StatelessWidget {
  const OnboardingOption({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.multi = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool multi;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: AppTheme.microMs,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.accent.withValues(alpha: 0.12)
                : AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? AppTheme.accent.withValues(alpha: 0.6)
                  : AppTheme.borderSubtle,
            ),
          ),
          child: Row(
            children: [
              _Indicator(selected: selected, multi: multi),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: AppTheme.ui(
                    size: 14,
                    color: selected
                        ? AppTheme.textPrimary
                        : AppTheme.textSecondary,
                    weight: selected ? FontWeight.w500 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Indicator extends StatelessWidget {
  const _Indicator({required this.selected, required this.multi});

  final bool selected;
  final bool multi;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: multi ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: multi ? BorderRadius.circular(6) : null,
        gradient: selected ? AppTheme.brandGradient : null,
        border: selected
            ? null
            : Border.all(color: AppTheme.textDim.withValues(alpha: 0.6)),
      ),
      child: selected
          ? const Icon(Icons.check, size: 14, color: AppTheme.onAccent)
          : null,
    );
  }
}

/// The shared scaffold for one onboarding question: progress dots, title,
/// options slot, and a footer action.
class OnboardingQuestionCard extends StatelessWidget {
  const OnboardingQuestionCard({
    super.key,
    required this.step,
    required this.totalSteps,
    required this.title,
    required this.options,
    required this.footer,
  });

  final int step;
  final int totalSteps;
  final String title;
  final List<Widget> options;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ProgressDots(step: step, total: totalSteps),
        const SizedBox(height: 24),
        Text(title, style: AppTheme.display(size: 20, weight: FontWeight.w600)),
        const SizedBox(height: 20),
        for (final o in options) ...[o, const SizedBox(height: 10)],
        const SizedBox(height: 8),
        footer,
      ],
    );
  }
}

class _ProgressDots extends StatelessWidget {
  const _ProgressDots({required this.step, required this.total});

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < total; i++)
          Expanded(
            child: Container(
              height: 3,
              margin: EdgeInsets.only(right: i == total - 1 ? 0 : 6),
              decoration: BoxDecoration(
                gradient: i <= step ? AppTheme.brandGradient : null,
                color: i <= step ? null : AppTheme.borderSubtle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
      ],
    );
  }
}
