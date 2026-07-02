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
  });

  final String title;
  final String? subtitle;

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
      children: [
        const Spacer(),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return SizedBox(
              width: 72,
              height: 72,
              child: CustomPaint(
                painter: _RingPainter(
                  turns: reduceMotion ? 0 : _controller.value,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        Text(
          widget.title,
          textAlign: TextAlign.center,
          style: AppTheme.ui(size: 16, weight: FontWeight.w600),
        ),
        if (widget.subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            widget.subtitle!,
            textAlign: TextAlign.center,
            style: AppTheme.ui(size: 13, color: AppTheme.textSecondary),
          ),
        ],
        const Spacer(),
        _ProgressBar(reduceMotion: reduceMotion),
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
