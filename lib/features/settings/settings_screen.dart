import 'package:flutter/material.dart';

import '../../models/user_profile.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_button.dart';
import '../onboarding/onboarding_question_card.dart';

/// Settings: edit the onboarding answers, see monthly API usage, and clear
/// project history. Reuses the onboarding option widgets for consistency.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.profile,
    required this.usageThisMonth,
    required this.onSave,
    required this.onClearHistory,
  });

  final UserProfile profile;
  final int usageThisMonth;
  final ValueChanged<UserProfile> onSave;
  final VoidCallback onClearHistory;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _toolChoices = [
    'Cursor',
    'Claude Code',
    'Windsurf',
    'GitHub Copilot',
    'Codex',
    'v0',
    'Other',
  ];

  late ExperienceLevel _experience;
  late Set<String> _tools;
  late ProjectFocus _focus;
  late ToneLevel _tone;

  @override
  void initState() {
    super.initState();
    _experience = widget.profile.experienceLevel;
    _tools = widget.profile.primaryTools.toSet();
    _focus = widget.profile.projectFocus;
    _tone = widget.profile.tonePreference;
  }

  void _save() {
    widget.onSave(widget.profile.copyWith(
      experienceLevel: _experience,
      primaryTools: _tools.toList(),
      projectFocus: _focus,
      tonePreference: _tone,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _group<ExperienceLevel>(
                  'Experience',
                  ExperienceLevel.values,
                  _experience,
                  (e) => e.label,
                  (e) => setState(() => _experience = e),
                ),
                _multiGroup(),
                _group<ProjectFocus>(
                  'What you build',
                  ProjectFocus.values,
                  _focus,
                  (e) => e.label,
                  (e) => setState(() => _focus = e),
                ),
                _group<ToneLevel>(
                  'Tone',
                  ToneLevel.values,
                  _tone,
                  (e) => e.label,
                  (e) => setState(() => _tone = e),
                ),
                const SizedBox(height: 8),
                _UsageRow(count: widget.usageThisMonth),
                const SizedBox(height: 12),
                _ClearHistoryButton(onConfirm: widget.onClearHistory),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        GradientButton(label: 'Save', onPressed: _save),
      ],
    );
  }

  Widget _group<T>(
    String label,
    List<T> values,
    T current,
    String Function(T) labelOf,
    ValueChanged<T> onPick,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionLabel(label),
          for (final v in values) ...[
            OnboardingOption(
              label: labelOf(v),
              selected: current == v,
              onTap: () => onPick(v),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _multiGroup() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionLabel('Primary tools'),
          for (final t in _toolChoices) ...[
            OnboardingOption(
              label: t,
              multi: true,
              selected: _tools.contains(t),
              onTap: () => setState(
                  () => _tools.contains(t) ? _tools.remove(t) : _tools.add(t)),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: AppTheme.ui(
          size: 11,
          weight: FontWeight.w600,
          color: AppTheme.textDim,
        ),
      ),
    );
  }
}

class _UsageRow extends StatelessWidget {
  const _UsageRow({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Row(
        children: [
          Text('Analyses this month',
              style: AppTheme.ui(size: 13, color: AppTheme.textSecondary)),
          const Spacer(),
          Text('$count',
              style: AppTheme.mono(size: 14, weight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ClearHistoryButton extends StatelessWidget {
  const _ClearHistoryButton({required this.onConfirm});
  final VoidCallback onConfirm;

  Future<void> _confirm(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceHigh,
        title: Text('Clear project history?',
            style: AppTheme.ui(size: 15, weight: FontWeight.w600)),
        content: Text(
          'This removes stored analyses for this project. It cannot be undone.',
          style: AppTheme.ui(size: 13, color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: AppTheme.ui(size: 13, color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Clear',
                style: AppTheme.ui(size: 13, color: AppTheme.signalOrange)),
          ),
        ],
      ),
    );
    if (ok == true) onConfirm();
  }

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () => _confirm(context),
      icon: const Icon(Icons.delete_outline,
          size: 16, color: AppTheme.signalOrange),
      label: Text('Clear project history',
          style: AppTheme.ui(size: 13, color: AppTheme.signalOrange)),
    );
  }
}
