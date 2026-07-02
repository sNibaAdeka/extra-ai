import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Extra AI design token system — single source of truth for color, gradient,
/// and typography. Reference this everywhere; never hardcode raw hex in
/// widgets.
///
/// Visual language (matched to the Ludr product family): near-black olive
/// surfaces, a single lime accent used deliberately, serif display headings
/// over a geometric sans for UI — warm, calm, and specific. The breathing
/// screen border stays the one prominent animation.
class AppTheme {
  AppTheme._();

  // ---------------------------------------------------------------------------
  // Color tokens
  // ---------------------------------------------------------------------------
  static const Color bgVoid = Color(0xFF0D0F09);
  static const Color surface = Color(0xFF14170E);
  static const Color surfaceHigh = Color(0xFF1C2013);
  static const Color borderSubtle = Color(0x17FFFFFF); // white @ ~9%, warm
  static const Color borderFocus = Color(0x99B5E04A);

  /// The lime brand accent and its deeper companion (gradients, glows).
  static const Color accent = Color(0xFFB5E04A);
  static const Color accentDeep = Color(0xFF8FBE2B);

  /// Text/icon color placed ON the lime accent (dark, per the Ludr buttons).
  static const Color onAccent = Color(0xFF10120B);

  /// Success shares the brand lime; warnings stay warm orange; destructive red.
  static const Color signalGreen = Color(0xFFB5E04A);
  static const Color signalOrange = Color(0xFFF97316);
  static const Color signalRed = Color(0xFFE05B45);

  static const Color textPrimary = Color(0xFFF2F3EC);
  static const Color textSecondary = Color(0xFFA3A98F);
  static const Color textDim = Color(0xFF6E7360);

  // ---------------------------------------------------------------------------
  // Gradients
  // ---------------------------------------------------------------------------

  /// Brand gradient — logo mark, accents, glow edges. Left → right.
  static const Gradient brandGradient = LinearGradient(
    colors: [Color(0xFFC8E965), accentDeep],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// Border gradient — the breathing screen border. lime → deep → lime so the
  /// animated stop offset loops seamlessly.
  static const Gradient borderGradient = LinearGradient(
    colors: [accent, accentDeep, accent],
    stops: [0.0, 0.5, 1.0],
  );

  // ---------------------------------------------------------------------------
  // Surface decoration helpers
  // ---------------------------------------------------------------------------

  /// Dark glass panel used by the overlay window.
  static BoxDecoration glassPanel({double radius = 20}) => BoxDecoration(
        color: bgVoid.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderSubtle),
        boxShadow: const [
          BoxShadow(
            color: Color(0x99000000),
            blurRadius: 80,
            offset: Offset(0, 32),
          ),
        ],
      );

  // ---------------------------------------------------------------------------
  // Typography
  //   Display / headings : Lora (serif — the Ludr editorial voice)
  //   UI text            : Space Grotesk (geometric, technical warmth)
  //   Code / prompts     : JetBrains Mono
  // ---------------------------------------------------------------------------

  static TextStyle display({
    double size = 20,
    FontWeight weight = FontWeight.w600,
    Color color = textPrimary,
    double? letterSpacing,
  }) =>
      GoogleFonts.lora(
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
      GoogleFonts.spaceGrotesk(
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
        primary: accent,
        onPrimary: onAccent,
        secondary: accentDeep,
        surface: surface,
        error: signalRed,
      ),
      textTheme: GoogleFonts.spaceGroteskTextTheme(base.textTheme),
    );
  }

  // Motion tokens — quiet, fast, disciplined (200–350ms). The border is the
  // only prominent animation.
  static const Duration microMs = Duration(milliseconds: 180);
  static const Duration transitionMs = Duration(milliseconds: 300);
  static const Curve easeOut = Curves.easeOutCubic;
}
