import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Extra AI design token system — single source of truth for color, gradient,
/// and typography. Reference this everywhere; never hardcode raw hex in
/// widgets.
///
/// Brand: the ember/orange palette live on extra-ai-landing.netlify.app —
/// warm near-black surfaces, cream text, a single ember accent used
/// deliberately (CTAs, active states). Green appears nowhere in the app
/// except [success], reserved for small universal success checkmarks.
class AppTheme {
  AppTheme._();

  // ---------------------------------------------------------------------------
  // Color tokens — exact values from the landing page CSS custom properties.
  // ---------------------------------------------------------------------------
  // Violet-plum base with warm ember corners — matches the landing's hero
  // (deep purple field, warm glow bleeding in from the edges).
  static const Color bgVoid = Color(0xFF221327); // dark violet-plum
  static const Color bgMid = Color(0xFF45243C); // violet-warm blend
  static const Color bgViolet = Color(0xFF321D4D); // gradient companion
  static const Color surface = Color(0xFF2B1B2F);
  static const Color surfaceHigh = Color(0xFF3D2842);
  static const Color borderSubtle = Color(0x26F5E4CC); // cream @ 15%
  static const Color borderFocus = Color(0x99F46F3D);

  /// --signal-ember: CTAs, active states, selected chips, live indicators.
  static const Color accent = Color(0xFFF46F3D);

  /// Softer ember used for broad surfaces so the UI does not feel neon.
  static const Color accentSoft = Color(0xFFE06439);

  /// Deeper terracotta companion for gradients and pressed states.
  static const Color accentDeep = Color(0xFFC85632);

  /// Secondary violet used ONLY inside iridescent shimmer/glow effects
  /// (see widgets/shimmer_text.dart) — never a primary UI color. Ember stays
  /// the one brand accent for buttons, CTAs, and selected states.
  static const Color accentViolet = Color(0xFFA855F7);

  /// Text/icon color placed ON ember fills (dark warm, ~7:1 contrast).
  static const Color onAccent = Color(0xFF1B0E07);

  /// Small universal success checkmarks ONLY (onboarding completion badge).
  /// Never used as a brand/accent color anywhere else.
  static const Color success = Color(0xFF57A863);

  static const Color signalOrange = Color(0xFFFFA24C); // warnings (issues)
  static const Color signalRed = Color(0xFFE05B45); // destructive

  static const Color textPrimary = Color(0xFFF5E4CC); // --cream-light
  static const Color textSecondary = Color(0xFFE8B98A); // --cream-warm
  static const Color textDim = Color(0xFF9A7E66);

  // ---------------------------------------------------------------------------
  // Gradients
  // ---------------------------------------------------------------------------

  /// Brand gradient — logo mark, primary CTAs. Left → right.
  static const Gradient brandGradient = LinearGradient(
    colors: [accentSoft, accentDeep],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// Border gradient — the breathing screen border. ember → violet → ember so
  /// the animated stop offset loops seamlessly with an iridescent flow.
  static const Gradient borderGradient = LinearGradient(
    colors: [accent, accentViolet, accent],
    stops: [0.0, 0.5, 1.0],
  );

  // ---------------------------------------------------------------------------
  // Surface decoration helpers
  // ---------------------------------------------------------------------------

  /// Dark glass panel used by the overlay windows — violet field warming to
  /// ember at the far corner, like the landing hero.
  static BoxDecoration glassPanel({double radius = 20}) => BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        bgVoid.withValues(alpha: 0.97),
        bgViolet.withValues(alpha: 0.9),
        bgMid.withValues(alpha: 0.88),
      ],
    ),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: accent.withValues(alpha: 0.16)),
    boxShadow: [
      BoxShadow(
        color: accent.withValues(alpha: 0.14),
        blurRadius: 72,
        spreadRadius: -24,
        offset: const Offset(0, 28),
      ),
      BoxShadow(
        color: accentViolet.withValues(alpha: 0.12),
        blurRadius: 88,
        spreadRadius: -28,
        offset: const Offset(0, 20),
      ),
      const BoxShadow(
        color: Color(0xAA000000),
        blurRadius: 80,
        offset: Offset(0, 32),
      ),
    ],
  );

  static BoxDecoration islandPanel({double radius = 28}) => BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        bgVoid.withValues(alpha: 0.98),
        bgViolet.withValues(alpha: 0.94),
        bgMid.withValues(alpha: 0.85),
      ],
      stops: const [0, 0.58, 1],
    ),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: accent.withValues(alpha: 0.24)),
    boxShadow: [
      // Dual ember + violet glow = the iridescent halo around the island.
      BoxShadow(
        color: accent.withValues(alpha: 0.2),
        blurRadius: 68,
        spreadRadius: -22,
        offset: const Offset(0, 24),
      ),
      BoxShadow(
        color: accentViolet.withValues(alpha: 0.16),
        blurRadius: 80,
        spreadRadius: -26,
        offset: const Offset(0, 16),
      ),
      const BoxShadow(
        color: Color(0x99000000),
        blurRadius: 42,
        offset: Offset(0, 22),
      ),
    ],
  );

  /// Card-on-surface decoration used across dashboard/settings cards.
  /// Apple-style materials: a translucent cream lift over the violet field
  /// with a hairline border — depth from layering, not from heavy outlines.
  static BoxDecoration card({double radius = 16}) => BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        textPrimary.withValues(alpha: 0.055),
        textPrimary.withValues(alpha: 0.035),
      ],
    ),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: textPrimary.withValues(alpha: 0.07)),
  );

  // ---------------------------------------------------------------------------
  // Typography
  //   Display / headings : Space Grotesk (landing --font-display)
  //   UI text            : Inter (stand-in for General Sans)
  //   Code / prompts     : JetBrains Mono
  // ---------------------------------------------------------------------------

  static TextStyle display({
    double size = 20,
    FontWeight weight = FontWeight.w600,
    Color color = textPrimary,
    double? letterSpacing,
  }) => GoogleFonts.spaceGrotesk(
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
  }) => GoogleFonts.inter(
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
  }) => GoogleFonts.jetBrainsMono(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
  );

  /// Small-caps section label (TEMPLATES, BINDINGS, EXPERIMENTAL...).
  static TextStyle sectionLabel() => ui(
    size: 11,
    weight: FontWeight.w600,
    color: textDim,
  ).copyWith(letterSpacing: 1.2);

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
      textTheme: GoogleFonts.interTextTheme(base.textTheme),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 500),
        decoration: BoxDecoration(
          color: surfaceHigh,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: borderSubtle),
        ),
        textStyle: ui(size: 12, color: textSecondary),
      ),
    );
  }

  // Motion tokens — quiet, fast, disciplined (150–350ms). The border is the
  // only prominent animation.
  static const Duration microMs = Duration(milliseconds: 160);
  static const Duration transitionMs = Duration(milliseconds: 300);
  static const Curve easeOut = Curves.easeOutCubic;
}
