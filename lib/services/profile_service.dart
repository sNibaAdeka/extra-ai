// PRIVACY NOTE: The UserProfile is stored locally via Hive. It is never
// transmitted anywhere except as the specific fields embedded in the Gemini
// context block for a request. No backend, no telemetry.

import 'package:hive/hive.dart';

import '../models/user_profile.dart';

/// Persists the UserProfile locally. Onboarding is shown only when [current]
/// is null. Backed by a simple key/value box (map-serialized, no codegen).
class ProfileService {
  ProfileService(this._box);

  static const String boxName = 'user_profile';
  static const String _key = 'profile';

  final Box _box;

  UserProfile? get current {
    final raw = _box.get(_key);
    if (raw is Map) {
      return UserProfile.fromMap(Map<String, dynamic>.from(raw));
    }
    return null;
  }

  bool get hasProfile => _box.containsKey(_key);

  Future<void> save(UserProfile profile) async {
    await _box.put(_key, profile.toMap());
  }

  /// Monthly usage counter (analyses this month), kept alongside the profile.
  int get usageThisMonth {
    final stored = _box.get(_usageKey);
    if (stored is Map && stored['month'] == _currentMonth) {
      return (stored['count'] as int?) ?? 0;
    }
    return 0;
  }

  Future<void> incrementUsage() async {
    await _box.put(_usageKey, {'month': _currentMonth, 'count': usageThisMonth + 1});
  }

  static const String _usageKey = 'usage';
  String get _currentMonth {
    final now = DateTime.now();
    return '${now.year}-${now.month}';
  }
}
