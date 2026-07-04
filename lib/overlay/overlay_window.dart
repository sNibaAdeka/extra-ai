import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:window_manager/window_manager.dart';

import '../theme/app_theme.dart';
import '../widgets/logo_mark.dart';

/// Floating glass panel for loading/results surfaces. The input state uses the
/// compact composer directly; this keeps secondary states consistent without
/// reintroducing a fullscreen overlay background.
class OverlayWindow extends StatelessWidget {
  const OverlayWindow({
    super.key,
    required this.child,
    this.onClose,
    this.onSettings,
    this.onHome,
    this.statusDotColor,
    this.statusTooltip,
    this.width = 620,
    this.height = 580,
  });

  final Widget child;
  final VoidCallback? onClose;
  final VoidCallback? onSettings;

  /// Opens the app shell (dashboard) from the compact analysis window.
  final VoidCallback? onHome;

  /// Calm service-health indicator next to the settings gear (amber when a
  /// backing service is degraded). Null hides the dot entirely.
  final Color? statusDotColor;
  final String? statusTooltip;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final panel = ClipRRect(
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
              _Header(
                onClose: onClose,
                onSettings: onSettings,
                onHome: onHome,
                statusDotColor: statusDotColor,
                statusTooltip: statusTooltip,
              ),
              const Divider(height: 1, color: AppTheme.borderSubtle),
              Expanded(
                child: Padding(padding: const EdgeInsets.all(16), child: child),
              ),
            ],
          ),
        ),
      ),
    );

    return panel
        .animate()
        .slideY(
          begin: 0.04,
          end: 0,
          duration: 350.ms,
          curve: Curves.easeOutCubic,
        )
        .fadeIn(duration: 250.ms);
  }
}

class _Header extends StatelessWidget {
  const _Header({
    this.onClose,
    this.onSettings,
    this.onHome,
    this.statusDotColor,
    this.statusTooltip,
  });

  final VoidCallback? onClose;
  final VoidCallback? onSettings;
  final VoidCallback? onHome;
  final Color? statusDotColor;
  final String? statusTooltip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Row(
        children: [
          Expanded(
            child: _WindowDragRegion(
              child: SizedBox(
                height: 30,
                child: Row(
                  children: [
                    const LogoMark(size: 22),
                    const SizedBox(width: 10),
                    Text(
                      'Extra AI',
                      style: AppTheme.display(
                        size: 16,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (onHome != null)
            _IconButton(
              icon: Icons.grid_view_outlined,
              tooltip: 'Dashboard',
              onTap: onHome!,
            ),
          if (statusDotColor != null)
            Tooltip(
              message: statusTooltip ?? 'Service status',
              child: Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: statusDotColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: statusDotColor!.withValues(alpha: 0.5),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ),
          if (onSettings != null)
            _IconButton(
              icon: Icons.settings_outlined,
              tooltip: 'Settings',
              onTap: onSettings!,
            ),
          if (onClose != null)
            _IconButton(icon: Icons.close, tooltip: 'Close', onTap: onClose!),
        ],
      ),
    );
  }
}

class _WindowDragRegion extends StatelessWidget {
  const _WindowDragRegion({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.move,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanStart: (_) => windowManager.startDragging(),
        child: child,
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
