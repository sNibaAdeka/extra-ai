import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../app/app_state.dart' show VerificationStatus;
import '../models/analysis_trace.dart';
import '../models/extra_ai_response.dart';
import '../models/project_audit_report.dart';
import '../models/response_quality_report.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_button.dart';
import '../widgets/issue_card.dart';

/// Results view: the improved prompt (lime scan-line accent + copy), the
/// issues section (orange accent, or a locked/unlock state on the free tier),
/// an optional clarifying-question card, and the bottom action buttons.
/// Shows the two-model quality-gate outcome: a quiet "Verified" chip when the
/// critic passed the draft, and an honest note when the check couldn't run.
class ResultsView extends StatefulWidget {
  const ResultsView({
    super.key,
    required this.response,
    required this.onCopyInsert,
    required this.onEdit,
    this.trace,
    this.auditReport,
    this.qualityReport,
    this.verificationStatus = VerificationStatus.skipped,
    this.primaryActionLabel = 'Copy Prompt',
    this.primaryActionShortcut = '⌘C',
    this.issuesLocked = false,
    this.readOnly = false,
    this.onUnlock,
    this.onReanalyze,
  });

  final ExtraAIResponse response;
  final VoidCallback onCopyInsert;
  final VoidCallback onEdit;
  final AnalysisTrace? trace;
  final ProjectAuditReport? auditReport;
  final ResponseQualityReport? qualityReport;
  final VerificationStatus verificationStatus;
  final String primaryActionLabel;
  final String primaryActionShortcut;

  /// History detail mode: no Copy & Insert / Edit actions, view only.
  final bool readOnly;

  /// Free-tier: issues shown locked behind an Unlock pill.
  final bool issuesLocked;
  final VoidCallback? onUnlock;

  /// Called with the answer when the user responds to a clarifying question.
  final ValueChanged<String>? onReanalyze;

  @override
  State<ResultsView> createState() => _ResultsViewState();
}

class _ResultsViewState extends State<ResultsView> {
  bool _primaryCopied = false;

  void _copyPrimary() {
    widget.onCopyInsert();
    setState(() => _primaryCopied = true);
    Future.delayed(const Duration(milliseconds: 1300), () {
      if (mounted) setState(() => _primaryCopied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.keyC, meta: true):
                _copyPrimary,
            const SingleActivator(LogicalKeyboardKey.keyE, meta: true):
                widget.onEdit,
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              final promptMaxHeight = (constraints.maxHeight * 0.38).clamp(
                170.0,
                260.0,
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (widget.qualityReport != null) ...[
                            _LocalQualityCard(report: widget.qualityReport!),
                            const SizedBox(height: 12),
                          ],
                          if (widget.auditReport != null) ...[
                            _ProjectAuditCard(report: widget.auditReport!),
                            const SizedBox(height: 12),
                          ],
                          if (widget.trace != null) ...[
                            _AnalysisTraceCard(trace: widget.trace!),
                            const SizedBox(height: 12),
                          ],
                          _ImprovedPromptSection(
                            text: widget.response.improvedPrompt,
                            maxHeight: promptMaxHeight,
                            verified:
                                widget.verificationStatus ==
                                    VerificationStatus.verified ||
                                widget.verificationStatus ==
                                    VerificationStatus.corrected,
                          ),
                          const SizedBox(height: 20),
                          if (widget.response.issues.isNotEmpty ||
                              widget.issuesLocked)
                            _IssuesSection(
                              issues: widget.response.issues,
                              locked: widget.issuesLocked,
                              onUnlock: widget.onUnlock,
                            ),
                          if (widget.response.hasClarifyingQuestion &&
                              widget.onReanalyze != null) ...[
                            const SizedBox(height: 20),
                            _ClarifyingCard(
                              question: widget.response.clarifyingQuestion!,
                              onReanalyze: widget.onReanalyze!,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (!widget.readOnly) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: GradientButton(
                            label: _primaryCopied
                                ? 'Copied'
                                : widget.primaryActionLabel,
                            trailing: _primaryCopied
                                ? '✓'
                                : widget.primaryActionShortcut,
                            onPressed: _copyPrimary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GhostButton(
                            label: 'Edit',
                            onPressed: widget.onEdit,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              );
            },
          ),
        )
        .animate(delay: 100.ms)
        .fadeIn(duration: 300.ms)
        .slideY(begin: 0.05, end: 0);
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
    return Stack(
      children: [
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          child: Container(
            width: 3,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [accent, accent.withValues(alpha: 0.2)],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Padding(padding: const EdgeInsets.only(left: 15), child: child),
      ],
    );
  }
}

class _PromptTextCard extends StatelessWidget {
  const _PromptTextCard({required this.text, required this.maxHeight});

  final String text;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(maxHeight: maxHeight),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.bgVoid.withValues(alpha: 0.72),
            AppTheme.bgMid.withValues(alpha: 0.42),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
      ),
      child: Scrollbar(
        child: SingleChildScrollView(
          padding: EdgeInsets.zero,
          child: SelectableText(
            text,
            style: AppTheme.mono(size: 12.5, height: 1.55),
          ),
        ),
      ),
    );
  }
}

class _LocalQualityCard extends StatelessWidget {
  const _LocalQualityCard({required this.report});

  final ResponseQualityReport report;

  @override
  Widget build(BuildContext context) {
    final color = switch (report.status) {
      ResponseQualityStatus.passed => AppTheme.accent,
      ResponseQualityStatus.warning => AppTheme.signalOrange,
      ResponseQualityStatus.failed => AppTheme.signalRed,
    };
    final icon = switch (report.status) {
      ResponseQualityStatus.passed => Icons.fact_check_outlined,
      ResponseQualityStatus.warning => Icons.manage_search_outlined,
      ResponseQualityStatus.failed => Icons.error_outline_rounded,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.label,
                  style: AppTheme.ui(
                    size: 12,
                    weight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  report.summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.ui(
                    size: 11.5,
                    height: 1.3,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Tooltip(
            message: _details,
            child: Icon(
              Icons.info_outline_rounded,
              size: 15,
              color: AppTheme.textDim,
            ),
          ),
        ],
      ),
    );
  }

  String get _details {
    final parts = [
      ...report.failedChecks.map((c) => '✗ $c'),
      ...report.warnings.map((c) => '! $c'),
      ...report.passedChecks.map((c) => '✓ $c'),
    ];
    return parts.isEmpty ? 'Quick automatic check of the response.' : parts.join('\n');
  }
}

class _ProjectAuditCard extends StatelessWidget {
  const _ProjectAuditCard({required this.report});

  final ProjectAuditReport report;

  @override
  Widget build(BuildContext context) {
    final color = switch (report.status) {
      'risk' => AppTheme.signalRed,
      'warning' => AppTheme.signalOrange,
      _ => AppTheme.accent,
    };
    final icon = switch (report.status) {
      'risk' => Icons.security_outlined,
      'warning' => Icons.manage_search_outlined,
      _ => Icons.verified_outlined,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Local audit · ${report.label}',
                  style: AppTheme.ui(
                    size: 12,
                    weight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
              Text(
                '${report.issues.length}',
                style: AppTheme.mono(size: 11, color: AppTheme.textDim),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            report.summary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.ui(
              size: 11.5,
              height: 1.3,
              color: AppTheme.textSecondary,
            ),
          ),
          if (report.issues.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final issue in report.issues.take(3))
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('•', style: AppTheme.ui(size: 13, color: color)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        issue.file == null
                            ? issue.title
                            : '${issue.title} · ${issue.file}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.ui(
                          size: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _AnalysisTraceCard extends StatelessWidget {
  const _AnalysisTraceCard({required this.trace});

  final AnalysisTrace trace;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh.withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Material(
        color: Colors.transparent,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 2,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            leading: const Icon(
              Icons.radar_outlined,
              size: 17,
              color: AppTheme.signalOrange,
            ),
            title: Text(
              'How this was made',
              style: AppTheme.ui(size: 12.5, weight: FontWeight.w800),
            ),
            // The collapsed one-liner is the live-demo proof — no clicks needed.
            subtitle: Text(
              trace.groundedSummary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.ui(
                size: 11,
                weight: FontWeight.w600,
                color: AppTheme.accent,
              ),
            ),
            iconColor: AppTheme.textSecondary,
            collapsedIconColor: AppTheme.textDim,
            children: [
              _TraceLine(
                icon: Icons.folder_open_outlined,
                label: trace.readLine,
              ),
              if (trace.filesSample.isNotEmpty)
                _TraceLine(
                  icon: Icons.description_outlined,
                  label: trace.filesSample.take(6).join(', '),
                ),
              _TraceLine(
                icon: Icons.verified_user_outlined,
                label: trace.wasVerified
                    ? 'Verified by a second model'
                    : 'Quality check unavailable',
              ),
              if (trace.redactedSecrets > 0)
                _TraceLine(
                  icon: Icons.lock_outline_rounded,
                  label:
                      '${trace.redactedSecrets} ${trace.redactedSecrets == 1 ? 'secret' : 'secrets'} redacted',
                ),
              if (trace.recommendedChecks.isNotEmpty)
                _TraceLine(
                  icon: Icons.fact_check_outlined,
                  label: trace.recommendedChecks.join(', '),
                ),
              // Only when a stale repeat was actually detected + regenerated.
              if (trace.freshnessRegenerated)
                _TraceLine(
                  icon: Icons.refresh_rounded,
                  label: 'Re-analyzed with fresh context',
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TraceLine extends StatelessWidget {
  const _TraceLine({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 13, color: AppTheme.textDim),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.ui(
                size: 11,
                height: 1.3,
                color: AppTheme.textSecondary,
              ),
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
          const Icon(Icons.verified_outlined, size: 12, color: AppTheme.accent),
          const SizedBox(width: 4),
          Text(
            'Verified',
            style: AppTheme.ui(
              size: 10.5,
              weight: FontWeight.w600,
              color: AppTheme.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _ImprovedPromptSection extends StatefulWidget {
  const _ImprovedPromptSection({
    required this.text,
    required this.maxHeight,
    this.verified = false,
  });

  final String text;
  final double maxHeight;
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
              Icon(
                Icons.check_circle_outline,
                size: 16,
                color: AppTheme.accent,
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('generated prompt', style: AppTheme.sectionLabel()),
                  Text(
                    'Ready to paste',
                    style: AppTheme.ui(
                      size: 14,
                      weight: FontWeight.w700,
                      color: AppTheme.accent,
                    ),
                  ),
                ],
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
          _PromptTextCard(text: widget.text, maxHeight: widget.maxHeight),
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
                  Text(
                    'Copied!',
                    style: AppTheme.ui(size: 11, color: AppTheme.accent),
                  ),
                ],
              )
            : Icon(
                Icons.copy_outlined,
                key: const ValueKey('copy'),
                size: 16,
                color: AppTheme.textSecondary,
              ),
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
              const Icon(
                Icons.warning_amber_rounded,
                size: 17,
                color: AppTheme.signalOrange,
              ),
              const SizedBox(width: 8),
              Text(
                'Issues Found',
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
                      bottom: i == issues.length - 1 ? 0 : 8,
                    ),
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
        child: Text(
          'Unlock',
          style: AppTheme.ui(size: 12, weight: FontWeight.w600),
        ),
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
                child: Text(
                  widget.question,
                  style: AppTheme.ui(size: 13, color: AppTheme.textPrimary),
                ),
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
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
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
              child: Text(
                'Re-analyze',
                style: AppTheme.ui(
                  size: 13,
                  weight: FontWeight.w600,
                  color: AppTheme.accentDeep,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
