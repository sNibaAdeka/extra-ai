import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Text with a slow-moving ember/violet iridescent shimmer, matching the
/// landing page's `.extra-iridescent-text` treatment. Used sparingly — a
/// rare, deliberate accent (a hero headline, a featured price), never for
/// frequent or small text. Respects prefers-reduced-motion by holding the
/// gradient steady, same convention as [AppTheme] motion tokens elsewhere.
class IridescentText extends StatefulWidget {
  const IridescentText(
    this.text, {
    super.key,
    required this.style,
    this.period = const Duration(milliseconds: 5200),
    this.textAlign,
  });

  final String text;
  final TextStyle style;
  final Duration period;
  final TextAlign? textAlign;

  @override
  State<IridescentText> createState() => _IridescentTextState();
}

class _IridescentTextState extends State<IridescentText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.period)
      ..repeat(reverse: true);
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
    final text = Text(widget.text, style: widget.style, textAlign: widget.textAlign);

    if (reduceMotion) {
      return ShaderMask(
        shaderCallback: (bounds) => _gradient(0.5).createShader(bounds),
        child: text,
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) => _gradient(_controller.value).createShader(bounds),
          child: child,
        );
      },
      child: text,
    );
  }

  Gradient _gradient(double t) {
    // Sweeps left-to-right across the four-stop cream/ember/violet/cream
    // sequence as t runs 0→1→0 (repeat(reverse: true) avoids a visible jump).
    final begin = Alignment(-1 - 2 * t, 0);
    final end = Alignment(1 - 2 * t, 0);
    return LinearGradient(
      begin: begin,
      end: end,
      colors: const [
        AppTheme.textPrimary,
        AppTheme.accent,
        AppTheme.accentViolet,
        AppTheme.textPrimary,
      ],
      stops: const [0.0, 0.35, 0.65, 1.0],
      tileMode: TileMode.mirror,
    );
  }
}
