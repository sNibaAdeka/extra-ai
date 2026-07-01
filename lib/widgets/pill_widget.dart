import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'logo_mark.dart';

/// Top-center floating pill: `[|] Extra AI  ⌘⇧E`. Dark glass with backdrop
/// blur, brand-purple border, and a soft purple glow underneath. Shown both in
/// the collapsed idle state and above the overlay.
class PillWidget extends StatelessWidget {
  const PillWidget({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Extra AI — activate with Command Shift E',
      button: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(100),
          boxShadow: [
            BoxShadow(
              color: AppTheme.purple.withValues(alpha: 0.35),
              blurRadius: 28,
              spreadRadius: -4,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(100),
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  constraints: const BoxConstraints(minWidth: 220),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D0D0D).withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: AppTheme.purple.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const LogoMark(size: 22),
                      const SizedBox(width: 10),
                      Text(
                        'Extra AI',
                        style: AppTheme.display(
                          size: 15,
                          weight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const _HotkeyBadge(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The ⌘⇧E keyboard-shortcut badge.
class _HotkeyBadge extends StatelessWidget {
  const _HotkeyBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Text(
        '⌘⇧E',
        style: AppTheme.ui(
          size: 12,
          weight: FontWeight.w500,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }
}
