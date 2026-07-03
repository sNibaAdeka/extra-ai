import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Full-bleed animated flowing-line background for the registration hero.
/// Ember/cream curved paths on the dark void, drawn low-opacity and slowly
/// flowing — recolored from the neutral reference into Extra AI's palette.
/// Respects reduced-motion by holding a steady frame.
class FlowingPaths extends StatefulWidget {
  const FlowingPaths({super.key, this.pathCount = 30});

  final int pathCount;

  @override
  State<FlowingPaths> createState() => _FlowingPathsState();
}

class _FlowingPathsState extends State<FlowingPaths>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 25),
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          size: Size.infinite,
          painter: _FlowingPathsPainter(
            t: reduceMotion ? 0.4 : _controller.value,
            pathCount: widget.pathCount,
          ),
        );
      },
    );
  }
}

class _FlowingPathsPainter extends CustomPainter {
  _FlowingPathsPainter({required this.t, required this.pathCount});

  /// Loop phase 0..1.
  final double t;
  final int pathCount;

  @override
  void paint(Canvas canvas, Size size) {
    // Scale the reference path geometry to the actual canvas so the flow fills
    // whatever column width it's given.
    final sx = size.width / 700.0;
    final sy = size.height / 900.0;

    for (var i = 0; i < pathCount; i++) {
      final startX = (-380.0 + i * 5) * sx;
      final startY = (-189.0 + i * 6) * sy;

      final path = Path()
        ..moveTo(startX, startY)
        ..cubicTo(
          startX,
          startY,
          (-312 + i * 5) * sx,
          (216 - i * 6) * sy,
          (152 - i * 5) * sx,
          (343 - i * 6) * sy,
        )
        ..cubicTo(
          (616 - i * 5) * sx,
          (470 - i * 6) * sy,
          (684 - i * 5) * sx,
          (875 - i * 6) * sy,
          (684 - i * 5) * sx,
          (875 - i * 6) * sy,
        );

      final color = Color.lerp(
        AppTheme.textSecondary.withValues(alpha: 0.10 + i * 0.006),
        AppTheme.accent.withValues(alpha: 0.14 + i * 0.006),
        i / pathCount,
      )!;

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5 + i * 0.03
        ..color = color;

      // Slow continuous flow: draw a moving window along each path, staggered
      // per index so they don't move in lockstep.
      final phase = (t + i / pathCount) % 1.0;
      canvas.drawPath(_segment(path, phase), paint);
    }
  }

  /// Extracts a partial-length window of [path] centred on [phase].
  Path _segment(Path path, double phase) {
    final metrics = path.computeMetrics().toList();
    final out = Path();
    for (final m in metrics) {
      final len = m.length;
      const windowFraction = 0.55;
      final window = len * windowFraction;
      var start = (phase * len) - window / 2;
      var end = start + window;
      start = start.clamp(0.0, len);
      end = end.clamp(0.0, len);
      if (end > start) out.addPath(m.extractPath(start, end), Offset.zero);
    }
    return out;
  }

  @override
  bool shouldRepaint(covariant _FlowingPathsPainter old) => old.t != t;
}
