import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The Extra AI logo mark: `[ | ]` — a bracket pair in the brand gradient with
/// a glowing white cursor line centered between them. Reads as both a logo and
/// a metaphor: "your input, given structure." Deliberately NOT a lightning
/// bolt / sparkle / generic AI-startup icon.
class LogoMark extends StatelessWidget {
  const LogoMark({super.key, this.size = 24});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _LogoPainter()),
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Bracket geometry — proportional to the box.
    final stroke = w * 0.11;
    final bracketH = h * 0.62;
    final top = (h - bracketH) / 2;
    final bottom = top + bracketH;
    final armLen = w * 0.16;
    final radius = stroke * 0.9;

    final gradient = AppTheme.brandGradient.createShader(
      Rect.fromLTWH(0, 0, w, h),
    );
    final bracketPaint = Paint()
      ..shader = gradient
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Left bracket  [
    final leftX = w * 0.20;
    final left = Path()
      ..moveTo(leftX + armLen, top)
      ..lineTo(leftX + radius, top)
      ..quadraticBezierTo(leftX, top, leftX, top + radius)
      ..lineTo(leftX, bottom - radius)
      ..quadraticBezierTo(leftX, bottom, leftX + radius, bottom)
      ..lineTo(leftX + armLen, bottom);
    canvas.drawPath(left, bracketPaint);

    // Right bracket  ]
    final rightX = w * 0.80;
    final right = Path()
      ..moveTo(rightX - armLen, top)
      ..lineTo(rightX - radius, top)
      ..quadraticBezierTo(rightX, top, rightX, top + radius)
      ..lineTo(rightX, bottom - radius)
      ..quadraticBezierTo(rightX, bottom, rightX - radius, bottom)
      ..lineTo(rightX - armLen, bottom);
    canvas.drawPath(right, bracketPaint);

    // Center cursor  |  — glowing white line.
    final cursorX = w * 0.5;
    final cursorTop = h * 0.30;
    final cursorBottom = h * 0.70;
    final glowPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke * 1.8
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawLine(
      Offset(cursorX, cursorTop),
      Offset(cursorX, cursorBottom),
      glowPaint,
    );
    final cursorPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke * 0.75
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(cursorX, cursorTop),
      Offset(cursorX, cursorBottom),
      cursorPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _LogoPainter oldDelegate) => false;
}
