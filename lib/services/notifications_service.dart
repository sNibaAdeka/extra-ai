// PRIVACY NOTE: notifications are stored locally via Hive only.

import 'package:hive/hive.dart';

/// One in-app notification card (Screen 5).
class AppNotification {
  const AppNotification({
    required this.id,
    required this.icon,
    required this.title,
    required this.body,
    required this.timestamp,
  });

  final String id;
  final String icon;
  final String title;
  final String body;
  final DateTime timestamp;

  Map<String, dynamic> toMap() => {
    'id': id,
    'icon': icon,
    'title': title,
    'body': body,
    'timestamp': timestamp.toIso8601String(),
  };

  factory AppNotification.fromMap(Map<String, dynamic> m) => AppNotification(
    id: m['id'] as String? ?? '',
    icon: m['icon'] as String? ?? '🔔',
    title: m['title'] as String? ?? '',
    body: m['body'] as String? ?? '',
    timestamp:
        DateTime.tryParse(m['timestamp'] as String? ?? '') ?? DateTime.now(),
  );
}

/// Local notification store. Seeds the first-run welcome card once; dismiss
/// and clear-all are permanent (the welcome card does not respawn).
class NotificationsService {
  NotificationsService(this._box);

  static const String boxName = 'notifications';
  static const String _seededKey = '_seeded';
  final Box _box;

  /// Call once at startup: adds the welcome notification on fresh installs.
  Future<void> seedIfNeeded() async {
    if (_box.get(_seededKey) == true) return;
    await _box.put(_seededKey, true);
    await add(
      AppNotification(
        id: 'welcome',
        icon: '👋',
        title: 'Welcome to Extra AI!',
        body:
            'Press ⌘⇧E to analyze anything on your screen. '
            'Secrets are redacted automatically before anything is sent.',
        timestamp: DateTime.now(),
      ),
    );
  }

  List<AppNotification> get all =>
      _box.keys
          .where((k) => k != _seededKey)
          .map(
            (k) => AppNotification.fromMap(
              Map<String, dynamic>.from(_box.get(k) as Map),
            ),
          )
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

  Future<void> add(AppNotification n) => _box.put(n.id, n.toMap());

  Future<void> dismiss(String id) => _box.delete(id);

  Future<void> clearAll() async {
    final ids = _box.keys.where((k) => k != _seededKey).toList();
    await _box.deleteAll(ids);
  }
}
