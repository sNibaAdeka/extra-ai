import 'package:flutter/material.dart';

import '../../services/notifications_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/controls.dart';

/// Screen 5 — Notifications dropdown, anchored below-right of the bell icon
/// with a small triangular pointer. Not a modal; click-outside is handled by
/// the shell's barrier.
class NotificationsPanel extends StatelessWidget {
  const NotificationsPanel({
    super.key,
    required this.notifications,
    required this.onDismiss,
    required this.onClearAll,
  });

  final List<AppNotification> notifications;
  final ValueChanged<String> onDismiss;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Triangular pointer connecting the panel to the bell.
        Padding(
          padding: const EdgeInsets.only(right: 18),
          child: CustomPaint(
            size: const Size(16, 8),
            painter: _PointerPainter(),
          ),
        ),
        Container(
          width: 340,
          constraints: const BoxConstraints(maxHeight: 380),
          decoration: BoxDecoration(
            color: AppTheme.surfaceHigh,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.borderSubtle),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 40,
                offset: Offset(0, 16),
              ),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Notifications',
                    style: AppTheme.ui(size: 14, weight: FontWeight.w600),
                  ),
                  const Spacer(),
                  PressableScale(
                    onTap: onClearAll,
                    child: Text(
                      'Clear all',
                      style: AppTheme.ui(size: 12, color: AppTheme.textDim),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (notifications.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: Text(
                      'No notifications',
                      style: AppTheme.ui(size: 13, color: AppTheme.textDim),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: notifications.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) => _NotificationCard(
                      notification: notifications[i],
                      onDismiss: () => onDismiss(notifications[i].id),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.onDismiss,
  });

  final AppNotification notification;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              notification.icon,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title,
                  style: AppTheme.ui(size: 13, weight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  notification.body,
                  style: AppTheme.ui(size: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 5),
                Text(
                  '${notification.timestamp.month}/${notification.timestamp.day}/${notification.timestamp.year}',
                  style: AppTheme.ui(size: 11, color: AppTheme.textDim),
                ),
              ],
            ),
          ),
          PressableScale(
            onTap: onDismiss,
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(Icons.close, size: 13, color: AppTheme.textDim),
            ),
          ),
        ],
      ),
    );
  }
}

class _PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(0, size.height)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = AppTheme.surfaceHigh);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
