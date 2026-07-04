import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The signature element: a glowing gradient border around the whole screen
/// that "breathes" like a heartbeat (~1Hz), synchronized with the pill widget.
/// This is the ONLY prominent animation in the app — everything else stays
/// quiet. Respects prefers-reduced-motion by holding a steady glow.
class ScreenBorder extends StatefulWidget {
  const ScreenBorder({super.key, this.thickness = 8});

  final double thickness;

  @override
  State<ScreenBorder> createState() => _ScreenBorderState();
}

class _ScreenBorderState extends State<ScreenBorder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // One full cycle ~= a slow heartbeat. Gradient rotation + breathing share it.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
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
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            size: Size.infinite,
            painter: _BorderPainter(
              progress: reduceMotion ? 0.5 : _controller.value,
              thickness: widget.thickness,
              reduceMotion: reduceMotion,
            ),
          );
        },
      ),
    );
  }
}

class _BorderPainter extends CustomPainter {
  _BorderPainter({
    required this.progress,
    required this.thickness,
    required this.reduceMotion,
  });

  final double progress;
  final double thickness;
  final bool reduceMotion;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Breathing: opacity oscillates between ~0.65 and 1.0 at ~1Hz. Held steady
    // when reduced motion is requested.
    final breath = reduceMotion
        ? 0.85
        : 0.65 + 0.35 * (0.5 + 0.5 * math.sin(progress * 2 * math.pi));

    // Rotating gradient so the light appears to travel along the edges.
    final sweep = SweepGradient(
      startAngle: 0,
      endAngle: 2 * math.pi,
      transform: GradientRotation(progress * 2 * math.pi),
      colors: const [
        AppTheme.accent,
        AppTheme.accentDeep,
        AppTheme.accent,
        AppTheme.accentDeep,
        AppTheme.accent,
      ],
      stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
    ).createShader(rect);

    // Outer glow — a thick, blurred stroke just inside the edge.
    final glowPaint = Paint()
      ..shader = sweep
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness * 2.6
      ..color = Colors.white.withValues(alpha: breath)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);
    canvas.drawRect(rect.deflate(thickness), glowPaint);

    // Crisp gradient border.
    final borderPaint = Paint()
      ..shader = sweep
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..color = Colors.white.withValues(alpha: breath);
    canvas.drawRect(rect.deflate(thickness / 2), borderPaint);

    // Corner concentration — brighter dabs at the four corners.
    _paintCornerGlow(canvas, size, breath);
  }

  void _paintCornerGlow(Canvas canvas, Size size, double breath) {
    final cornerPaint = Paint()
      ..color = AppTheme.accent.withValues(alpha: 0.5 * breath)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);
    const inset = 6.0;
    final corners = [
      Offset(inset, inset),
      Offset(size.width - inset, inset),
      Offset(inset, size.height - inset),
      Offset(size.width - inset, size.height - inset),
    ];
    for (final c in corners) {
      canvas.drawCircle(c, thickness * 3, cornerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BorderPainter old) =>
      old.progress != progress || old.thickness != thickness;
}
