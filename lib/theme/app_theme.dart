import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Extra AI design token system — single source of truth for color, gradient,
/// and typography. Reference this everywhere; never hardcode raw hex in widgets.
///
/// Signature aesthetic: dark glass surfaces, a deliberate purple→blue gradient
/// (never generic neon-green), a breathing screen border, and a scan-line
/// device on result sections. See SECTION 0 of the master build prompt.
class AppTheme {
  AppTheme._();

  // ---------------------------------------------------------------------------
  // Color tokens
  // ---------------------------------------------------------------------------
  static const Color bgVoid = Color(0xFF0A0A0A);
  static const Color surface = Color(0xFF131316);
  static const Color surfaceHigh = Color(0xFF1A1A1A);
  static const Color borderSubtle = Color(0x14FFFFFF); // white @ 8%
  static const Color borderFocus = Color(0x99897FED);

  static const Color purple = Color(0xFF7C3AED);
  static const Color blue = Color(0xFF2563EB);
  static const Color signalGreen = Color(0xFF22C55E);
  static const Color signalOrange = Color(0xFFF97316);

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textDim = Color(0xFF6B7280);

  // ---------------------------------------------------------------------------
  // Gradients
  // ---------------------------------------------------------------------------

  /// Brand gradient — buttons, logo mark, accents. Left → right.
  static const Gradient brandGradient = LinearGradient(
    colors: [purple, blue],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// Border gradient — the breathing screen border. purple → blue → purple so
  /// the animated stop offset loops seamlessly.
  static const Gradient borderGradient = LinearGradient(
    colors: [purple, blue, purple],
    stops: [0.0, 0.5, 1.0],
  );

  // ---------------------------------------------------------------------------
  // Surface decoration helpers
  // ---------------------------------------------------------------------------

  /// Dark glass panel used by the overlay window (rgba(10,10,10,0.92)).
  static BoxDecoration glassPanel({double radius = 20}) => BoxDecoration(
        color: bgVoid.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderSubtle),
        boxShadow: const [
          BoxShadow(
            color: Color(0x99000000), // rgba(0,0,0,0.6)
            blurRadius: 80,
            offset: Offset(0, 32),
          ),
        ],
      );

  // ---------------------------------------------------------------------------
  // Typography
  //   Display / logo : Space Grotesk (geometric, technical)
  //   UI text        : Inter
  //   Code / prompts : JetBrains Mono
  // ---------------------------------------------------------------------------

  static TextStyle display({
    double size = 20,
    FontWeight weight = FontWeight.w600,
    Color color = textPrimary,
    double? letterSpacing,
  }) =>
      GoogleFonts.spaceGrotesk(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
      );

  static TextStyle ui({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = textPrimary,
    double height = 1.4,
  }) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
      );

  static TextStyle mono({
    double size = 13,
    FontWeight weight = FontWeight.w400,
    Color color = textPrimary,
    double height = 1.5,
  }) =>
      GoogleFonts.jetBrainsMono(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
      );

  // ---------------------------------------------------------------------------
  // ThemeData — dark, Material 3, brand-seeded.
  // ---------------------------------------------------------------------------
  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: base.colorScheme.copyWith(
        primary: purple,
        secondary: blue,
        surface: surface,
        error: signalOrange,
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme),
    );
  }

  // Motion tokens — quiet, fast, disciplined (200–350ms). The border is the
  // only prominent animation.
  static const Duration microMs = Duration(milliseconds: 180);
  static const Duration transitionMs = Duration(milliseconds: 300);
  static const Curve easeOut = Curves.easeOutCubic;
}
