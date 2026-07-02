import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../app/app_state.dart' show VerificationStatus;
import '../models/extra_ai_response.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_button.dart';
import '../widgets/issue_card.dart';

/// Results view: the improved prompt (lime scan-line accent + copy), the
/// issues section (orange accent, or a locked/unlock state on the free tier),
/// an optional clarifying-question card, and the bottom action buttons.
/// Shows the two-model quality-gate outcome: a quiet "Verified" chip when the
/// critic passed the draft, and an honest note when the check couldn't run.
class ResultsView extends StatelessWidget {
  const ResultsView({
    super.key,
    required this.response,
    required this.onCopyInsert,
    required this.onEdit,
    this.verificationStatus = VerificationStatus.skipped,
    this.issuesLocked = false,
    this.readOnly = false,
    this.onUnlock,
    this.onReanalyze,
  });

  final ExtraAIResponse response;
  final VoidCallback onCopyInsert;
  final VoidCallback onEdit;
  final VerificationStatus verificationStatus;

  /// History detail mode: no Copy & Insert / Edit actions, view only.
  final bool readOnly;

  /// Free-tier: issues shown locked behind an Unlock pill.
  final bool issuesLocked;
  final VoidCallback? onUnlock;

  /// Called with the answer when the user responds to a clarifying question.
  final ValueChanged<String>? onReanalyze;

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
                if (verificationStatus == VerificationStatus.unavailable) ...[
                  const _QualityCheckNote(),
                  const SizedBox(height: 12),
                ],
                _ImprovedPromptSection(
                  text: response.improvedPrompt,
                  verified: verificationStatus == VerificationStatus.verified ||
                      verificationStatus == VerificationStatus.corrected,
                ),
                const SizedBox(height: 20),
                if (response.issues.isNotEmpty || issuesLocked)
                  _IssuesSection(
                    issues: response.issues,
                    locked: issuesLocked,
                    onUnlock: onUnlock,
                  ),
                if (response.hasClarifyingQuestion && onReanalyze != null) ...[
                  const SizedBox(height: 20),
                  _ClarifyingCard(
                    question: response.clarifyingQuestion!,
                    onReanalyze: onReanalyze!,
                  ),
                ],
              ],
            ),
          ),
        ),
        if (!readOnly) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: GradientButton(
                  label: 'Copy & Insert',
                  trailing: '⌘↵',
                  onPressed: onCopyInsert,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GhostButton(label: 'Edit', onPressed: onEdit),
              ),
            ],
          ),
        ],
      ],
    ).animate(delay: 100.ms).fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0);
  }
}

/// A thin vertical gradient scan-line on the left edge of a result section —
/// the signature layout device ("this was scanned/analyzed").
class _ScanLineSection extends StatelessWidget {
  const _ScanLineSection({required this.accent, required this.child});

  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 3,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [accent, accent.withValues(alpha: 0.2)],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// Honest degradation note: the critic was unreachable, the best available
/// draft is shown anyway — reliability means graceful degradation, not an
/// all-or-nothing gate.
class _QualityCheckNote extends StatelessWidget {
  const _QualityCheckNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.signalOrange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border:
            Border.all(color: AppTheme.signalOrange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline,
              size: 14, color: AppTheme.signalOrange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Quality check unavailable — showing best result.',
              style: AppTheme.ui(size: 12, color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Quiet chip shown when the independent critic model checked this response.
class _VerifiedChip extends StatelessWidget {
  const _VerifiedChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified_outlined,
              size: 12, color: AppTheme.accent),
          const SizedBox(width: 4),
          Text('Verified',
              style: AppTheme.ui(
                  size: 10.5,
                  weight: FontWeight.w600,
                  color: AppTheme.accent)),
        ],
      ),
    );
  }
}

class _ImprovedPromptSection extends StatefulWidget {
  const _ImprovedPromptSection({required this.text, this.verified = false});
  final String text;
  final bool verified;

  @override
  State<_ImprovedPromptSection> createState() => _ImprovedPromptSectionState();
}

class _ImprovedPromptSectionState extends State<_ImprovedPromptSection> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    setState(() => _copied = true);
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return _ScanLineSection(
      accent: AppTheme.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_outline,
                  size: 16, color: AppTheme.accent),
              const SizedBox(width: 8),
              Text(
                'Improved Prompt',
                style: AppTheme.ui(
                  size: 14,
                  weight: FontWeight.w600,
                  color: AppTheme.accent,
                ),
              ),
              if (widget.verified) ...[
                const SizedBox(width: 8),
                const _VerifiedChip(),
              ],
              const Spacer(),
              _CopyButton(copied: _copied, onTap: _copy),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: SelectableText(
              widget.text,
              style: AppTheme.mono(size: 12.5, height: 1.55),
            ),
          ),
        ],
      ),
    );
  }
}

class _CopyButton extends StatelessWidget {
  const _CopyButton({required this.copied, required this.onTap});
  final bool copied;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 20,
      child: AnimatedSwitcher(
        duration: AppTheme.microMs,
        child: copied
            ? Row(
                key: const ValueKey('copied'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check, size: 14, color: AppTheme.accent),
                  const SizedBox(width: 4),
                  Text('Copied!',
                      style: AppTheme.ui(
                          size: 11, color: AppTheme.accent)),
                ],
              )
            : Icon(Icons.copy_outlined,
                key: const ValueKey('copy'),
                size: 16,
                color: AppTheme.textSecondary),
      ),
    );
  }
}

class _IssuesSection extends StatelessWidget {
  const _IssuesSection({
    required this.issues,
    required this.locked,
    this.onUnlock,
  });

  final List<String> issues;
  final bool locked;
  final VoidCallback? onUnlock;

  @override
  Widget build(BuildContext context) {
    return _ScanLineSection(
      accent: AppTheme.signalOrange,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                '⚠  Issues Found',
                style: AppTheme.ui(
                  size: 14,
                  weight: FontWeight.w600,
                  color: AppTheme.signalOrange,
                ),
              ),
              const Spacer(),
              if (locked && onUnlock != null) _UnlockPill(onTap: onUnlock!),
            ],
          ),
          const SizedBox(height: 10),
          if (locked)
            Column(
              children: List.generate(
                issues.isEmpty ? 3 : issues.length,
                (i) => Padding(
                  padding: EdgeInsets.only(bottom: i == 2 ? 0 : 8),
                  child: LockedIssueCard(
                    hint: i < issues.length ? issues[i] : 'Issue ${i + 1}',
                  ),
                ),
              ),
            )
          else
            Column(
              children: [
                for (var i = 0; i < issues.length; i++)
                  Padding(
                    padding: EdgeInsets.only(
                        bottom: i == issues.length - 1 ? 0 : 8),
                    child: IssueCard(text: issues[i])
                        .animate(delay: (i * 80).ms)
                        .fadeIn()
                        .slideX(begin: 0.05, end: 0),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _UnlockPill extends StatelessWidget {
  const _UnlockPill({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          gradient: AppTheme.brandGradient,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text('Unlock',
            style: AppTheme.ui(size: 12, weight: FontWeight.w600)),
      ),
    );
  }
}

class _ClarifyingCard extends StatefulWidget {
  const _ClarifyingCard({required this.question, required this.onReanalyze});

  final String question;
  final ValueChanged<String> onReanalyze;

  @override
  State<_ClarifyingCard> createState() => _ClarifyingCardState();
}

class _ClarifyingCardState extends State<_ClarifyingCard> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.accentDeep.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.accentDeep.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.help_outline, size: 16, color: AppTheme.accentDeep),
              const SizedBox(width: 8),
              Expanded(
                child: Text(widget.question,
                    style: AppTheme.ui(size: 13, color: AppTheme.textPrimary)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _controller,
            style: AppTheme.ui(size: 13),
            cursorColor: AppTheme.accentDeep,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Answer...',
              hintStyle: AppTheme.ui(size: 13, color: AppTheme.textDim),
              filled: true,
              fillColor: AppTheme.surface,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.borderSubtle),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                final answer = _controller.text.trim();
                if (answer.isNotEmpty) widget.onReanalyze(answer);
              },
              child: Text('Re-analyze',
                  style: AppTheme.ui(
                      size: 13,
                      weight: FontWeight.w600,
                      color: AppTheme.accentDeep)),
            ),
          ),
        ],
      ),
    );
  }
}
