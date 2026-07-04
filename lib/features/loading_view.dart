import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The loading state: a gradient ring spinner, a status line, a file-count
/// subtitle, and a thin animated progress bar at the bottom. Shown while Gemini
/// runs. A skeleton-grade indicator, never a bare frozen UI.
class LoadingView extends StatefulWidget {
  const LoadingView({
    super.key,
    this.title = 'Analyzing your code...',
    this.subtitle,
    this.steps = const [],
    this.activeStep = 0,
  });

  final String title;
  final String? subtitle;
  final List<String> steps;
  final int activeStep;

  @override
  State<LoadingView> createState() => _LoadingViewState();
}

class _LoadingViewState extends State<LoadingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return SizedBox(
                  width: 62,
                  height: 62,
                  child: CustomPaint(
                    painter: _RingPainter(
                      turns: reduceMotion ? 0 : _controller.value,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        color: AppTheme.accent,
                        size: 22,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: AppTheme.ui(size: 17, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    widget.subtitle ?? 'Preparing a copy-ready prompt.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.ui(
                      size: 13,
                      color: AppTheme.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => _LiveScanCard(
            progress: reduceMotion ? 0.35 : _controller.value,
            label: _activeLabel,
            passLabel: _passLabel,
          ),
        ),
        if (widget.steps.isNotEmpty) ...[
          const SizedBox(height: 18),
          Expanded(
            child: _StepTimeline(
              steps: widget.steps,
              activeStep: widget.activeStep,
              pulse: reduceMotion ? 0 : _controller.value,
            ),
          ),
        ] else
          const Spacer(),
        const SizedBox(height: 12),
        _ProgressBar(reduceMotion: reduceMotion),
      ],
    );
  }

  String get _activeLabel {
    if (widget.steps.isEmpty) return 'Generating answer';
    final index = widget.activeStep.clamp(0, widget.steps.length - 1);
    return widget.steps[index];
  }

  String get _passLabel {
    if (widget.activeStep <= 1) return 'Pass 1 · context';
    if (widget.activeStep == 2) return 'Pass 2 · draft';
    if (widget.activeStep == 3) return 'Pass 3 · verify';
    return 'Done';
  }
}

class _LiveScanCard extends StatelessWidget {
  const _LiveScanCard({
    required this.progress,
    required this.label,
    required this.passLabel,
  });

  final double progress;
  final String label;
  final String passLabel;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: AppTheme.bgVoid.withValues(alpha: 0.34),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderSubtle),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _ScanCardPainter(progress: progress)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.accent.withValues(alpha: 0.35),
                      ),
                    ),
                    child: const Icon(
                      Icons.screenshot_monitor_rounded,
                      color: AppTheme.accent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Live context pass',
                          style: AppTheme.ui(
                            size: 11,
                            weight: FontWeight.w800,
                            color: AppTheme.signalOrange,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTheme.ui(
                                  size: 13,
                                  weight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _PassPill(label: passLabel),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PassPill extends StatelessWidget {
  const _PassPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: AppTheme.ui(
          size: 10.5,
          weight: FontWeight.w800,
          color: AppTheme.accent,
        ),
      ),
    );
  }
}

class _ScanCardPainter extends CustomPainter {
  const _ScanCardPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.035)
      ..strokeWidth = 1;
    const step = 24.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final scanX = (size.width + 48) * progress - 24;
    final rect = Rect.fromLTWH(scanX - 18, 0, 36, size.height);
    final scan = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          AppTheme.accent.withValues(alpha: 0.22),
          Colors.transparent,
        ],
      ).createShader(rect);
    canvas.drawRect(rect, scan);
  }

  @override
  bool shouldRepaint(covariant _ScanCardPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _StepTimeline extends StatelessWidget {
  const _StepTimeline({
    required this.steps,
    required this.activeStep,
    required this.pulse,
  });

  final List<String> steps;
  final int activeStep;
  final double pulse;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          _StepRow(
            label: steps[i],
            done: i < activeStep,
            active: i == activeStep,
            pulse: pulse,
          ),
          if (i != steps.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.label,
    required this.done,
    required this.active,
    required this.pulse,
  });

  final String label;
  final bool done;
  final bool active;
  final double pulse;

  @override
  Widget build(BuildContext context) {
    final color = done || active ? AppTheme.accent : AppTheme.textDim;
    final opacity = active
        ? 0.55 + 0.35 * math.sin(pulse * math.pi * 2).abs()
        : 0.18;
    return Row(
      children: [
        AnimatedContainer(
          duration: AppTheme.microMs,
          width: 18,
          height: 18,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: opacity),
            shape: BoxShape.circle,
            border: Border.all(
              color: color.withValues(alpha: active ? 0.8 : 0.35),
            ),
          ),
          child: Icon(
            done ? Icons.check_rounded : Icons.more_horiz_rounded,
            size: 12,
            color: done ? AppTheme.onAccent : color,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.ui(
              size: 12,
              weight: active ? FontWeight.w700 : FontWeight.w500,
              color: active || done ? AppTheme.textPrimary : AppTheme.textDim,
            ),
          ),
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.turns});

  final double turns;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 4;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Faint full track.
    final track = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(center, radius, track);

    // Bright gradient sweep — a ~270° arc that rotates.
    final sweep = Paint()
      ..shader = SweepGradient(
        colors: const [AppTheme.accent, AppTheme.accentDeep, AppTheme.accent],
        stops: const [0.0, 0.5, 1.0],
        transform: GradientRotation(turns * 2 * math.pi),
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4;

    final start = turns * 2 * math.pi;
    canvas.drawArc(rect, start, math.pi * 1.5, false, sweep);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.turns != turns;
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.reduceMotion});

  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 3,
        // An indeterminate LinearProgressIndicator animates itself — no
        // external controller needed.
        child: reduceMotion
            ? Container(color: AppTheme.accent.withValues(alpha: 0.5))
            : LinearProgressIndicator(
                backgroundColor: Colors.white.withValues(alpha: 0.06),
                valueColor: const AlwaysStoppedAnimation(AppTheme.accent),
              ),
      ),
    );
  }
}
