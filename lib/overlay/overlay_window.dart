import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/app_theme.dart';
import '../widgets/logo_mark.dart';

/// The floating glass panel (380x580) that hosts the input / loading / results
/// views. Provides the header (logo + optional settings + close) and the glass
/// surface; the body is swapped by the caller. Slides in from the right.
class OverlayWindow extends StatelessWidget {
  const OverlayWindow({
    super.key,
    required this.child,
    this.onClose,
    this.onSettings,
    this.width = 380,
    this.height = 580,
  });

  final Widget child;
  final VoidCallback? onClose;
  final VoidCallback? onSettings;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          width: width,
          height: height,
          decoration: AppTheme.glassPanel(radius: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(onClose: onClose, onSettings: onSettings),
              const Divider(height: 1, color: AppTheme.borderSubtle),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().slideX(
          begin: 0.15,
          end: 0,
          duration: 350.ms,
          curve: Curves.easeOutCubic,
        ).fadeIn(duration: 250.ms);
  }
}

class _Header extends StatelessWidget {
  const _Header({this.onClose, this.onSettings});

  final VoidCallback? onClose;
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Row(
        children: [
          const LogoMark(size: 22),
          const SizedBox(width: 10),
          Text(
            'Extra AI',
            style: AppTheme.display(size: 16, weight: FontWeight.w600),
          ),
          const Spacer(),
          if (onSettings != null)
            _IconButton(
              icon: Icons.settings_outlined,
              tooltip: 'Settings',
              onTap: onSettings!,
            ),
          if (onClose != null)
            _IconButton(
              icon: Icons.close,
              tooltip: 'Close',
              onTap: onClose!,
            ),
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 18, color: AppTheme.textSecondary),
        ),
      ),
    );
  }
}
