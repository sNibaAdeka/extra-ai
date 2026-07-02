import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Full-width brand-gradient button (Analyze, Copy & Insert). One primary CTA
/// per screen. Has a quiet press-scale micro-interaction and a disabled state
/// used while a request is in flight.
class GradientButton extends StatefulWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.trailing,
    this.enabled = true,
    this.height = 48,
  });

  final String label;
  final VoidCallback? onPressed;

  /// Optional trailing glyph such as "→" or "⌘↵".
  final String? trailing;
  final bool enabled;
  final double height;

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton> {
  bool _pressed = false;

  bool get _active => widget.enabled && widget.onPressed != null;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: _active,
      label: widget.label,
      child: GestureDetector(
        onTapDown: _active ? (_) => setState(() => _pressed = true) : null,
        onTapCancel: _active ? () => setState(() => _pressed = false) : null,
        onTapUp: _active ? (_) => setState(() => _pressed = false) : null,
        onTap: _active ? widget.onPressed : null,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: AppTheme.microMs,
          curve: AppTheme.easeOut,
          child: Opacity(
            opacity: _active ? 1.0 : 0.5,
            child: Container(
              height: widget.height,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: AppTheme.brandGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: _active
                    ? [
                        BoxShadow(
                          color: AppTheme.accent.withValues(alpha: 0.35),
                          blurRadius: 20,
                          spreadRadius: -6,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.label,
                    style: AppTheme.ui(
                      size: 15,
                      weight: FontWeight.w600,
                      color: AppTheme.onAccent,
                    ),
                  ),
                  if (widget.trailing != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      widget.trailing!,
                      style: AppTheme.ui(
                        size: 14,
                        weight: FontWeight.w500,
                        color: AppTheme.onAccent.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ghost / outlined secondary button (Edit). Never competes with the primary.
class GhostButton extends StatelessWidget {
  const GhostButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = 48,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppTheme.borderSubtle),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          foregroundColor: AppTheme.textSecondary,
        ),
        child: Text(
          label,
          style: AppTheme.ui(
            size: 14,
            weight: FontWeight.w500,
            color: AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
