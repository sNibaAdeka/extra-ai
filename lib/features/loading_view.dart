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

  String? get _currentStep {
    if (widget.steps.isEmpty) return null;
    final i = widget.activeStep.clamp(0, widget.steps.length - 1);
    return widget.steps[i];
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
            width: 56,
            height: 56,
            child: CustomPaint(
              painter: _RingPainter(turns: reduceMotion ? 0 : _controller.value),
            ),
          ),
        ),
        const SizedBox(height: 22),
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
            style: AppTheme.ui(size: 13, color: AppTheme.textSecondary),
          ),
        ],
        if (_currentStep != null) ...[
          const SizedBox(height: 18),
          Text(
            _currentStep!,
            textAlign: TextAlign.center,
            style: AppTheme.ui(size: 12, color: AppTheme.textDim),
          ),
        ],
        const Spacer(),
        _ProgressBar(reduceMotion: reduceMotion),
      ],
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
