import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Minimal loading state: a gradient ring spinner, a title + subtitle, the
/// current step in plain text, and a thin indeterminate progress bar. Quiet by
/// design — no cards, no checklists, no extra effects.
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

  /// Phase labels; only the [activeStep] one is shown, as a single quiet line.
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
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Spacer(),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => SizedBox(
            width: 52,
            height: 52,
            child: CustomPaint(
              painter: _RingPainter(turns: reduceMotion ? 0 : _controller.value),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          widget.title,
          textAlign: TextAlign.center,
          style: AppTheme.display(size: 19, weight: FontWeight.w600),
        ),
        if (widget.subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            widget.subtitle!,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.ui(size: 13, color: AppTheme.textSecondary),
          ),
        ],
        if (widget.steps.isNotEmpty) ...[
          const SizedBox(height: 22),
          _Stepper(
            steps: widget.steps,
            activeStep: widget.activeStep,
            spin: !reduceMotion,
            controller: _controller,
          ),
        ],
        const Spacer(),
        _ProgressBar(reduceMotion: reduceMotion),
      ],
    );
  }
}

/// A neat vertical stepper: done steps get a check, the current one a small
/// pulsing dot, upcoming ones stay dim. Rows animate in as they activate.
class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.steps,
    required this.activeStep,
    required this.spin,
    required this.controller,
  });

  final List<String> steps;
  final int activeStep;
  final bool spin;
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _marker(i),
                const SizedBox(width: 10),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 250),
                  style: AppTheme.ui(
                    size: 12.5,
                    weight: i == activeStep
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: i < activeStep
                        ? AppTheme.textSecondary
                        : i == activeStep
                            ? AppTheme.textPrimary
                            : AppTheme.textDim,
                  ),
                  child: Text(steps[i]),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _marker(int i) {
    if (i < activeStep) {
      // Done.
      return Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: AppTheme.accent.withValues(alpha: 0.18),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check, size: 12, color: AppTheme.accent),
      );
    }
    if (i == activeStep) {
      // Active — gentle pulsing dot.
      return SizedBox(
        width: 18,
        height: 18,
        child: Center(
          child: spin
              ? AnimatedBuilder(
                  animation: controller,
                  builder: (context, _) {
                    final t = (controller.value * 2 - 1).abs(); // 0→1→0
                    return Container(
                      width: 8 + 2 * t,
                      height: 8 + 2 * t,
                      decoration: BoxDecoration(
                        color: AppTheme.accent
                            .withValues(alpha: 0.5 + 0.5 * t),
                        shape: BoxShape.circle,
                      ),
                    );
                  },
                )
              : Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                    color: AppTheme.accent,
                    shape: BoxShape.circle,
                  ),
                ),
        ),
      );
    }
    // Upcoming.
    return Container(
      width: 18,
      height: 18,
      alignment: Alignment.center,
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.textDim.withValues(alpha: 0.5)),
        ),
      ),
    );
  }
}

/// A ~270° gradient arc that rotates.
class _RingPainter extends CustomPainter {
  _RingPainter({required this.turns});

  final double turns;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 3;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, radius, track);

    final sweep = Paint()
      ..shader = SweepGradient(
        colors: const [AppTheme.accent, AppTheme.accentDeep, AppTheme.accent],
        stops: const [0.0, 0.5, 1.0],
        transform: GradientRotation(turns * 2 * math.pi),
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;

    canvas.drawArc(rect, turns * 2 * math.pi, math.pi * 1.5, false, sweep);
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
