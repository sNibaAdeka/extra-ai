// PRIVACY NOTE: preferences are stored locally via Hive only.

import 'package:hive/hive.dart';

/// App preferences (Settings screens 8–13). Thin typed wrapper over a Hive
/// key/value box; every setter persists immediately.
class SettingsService {
  SettingsService(this._box);

  static const String boxName = 'app_settings';
  final Box _box;

  // --- General ---------------------------------------------------------------
  String get themeMode => _box.get('themeMode', defaultValue: 'system');
  Future<void> setThemeMode(String v) => _box.put('themeMode', v);

  bool get launchAtLogin => _box.get('launchAtLogin', defaultValue: false);
  Future<void> setLaunchAtLogin(bool v) => _box.put('launchAtLogin', v);

  /// '30d' | '90d' | 'forever'. Note: independent of this setting, the data
  /// layer always keeps at most the 5 most recent analyses per project for
  /// request context (HistoryService.maxPerProject).
  String get historyRetention =>
      _box.get('historyRetention', defaultValue: 'forever');
  Future<void> setHistoryRetention(String v) => _box.put('historyRetention', v);

  /// Display combo for the global analysis hotkey (capture UI). The actual
  /// system registration happens at startup in main.dart.
  String get hotkeyCombo => _box.get('hotkeyCombo', defaultValue: '⌘⇧E');
  Future<void> setHotkeyCombo(String v) => _box.put('hotkeyCombo', v);

  // --- Experimental ------------------------------------------------------------
  bool get visualGrounding => _box.get('visualGrounding', defaultValue: false);
  Future<void> setVisualGrounding(bool v) => _box.put('visualGrounding', v);

  bool get autoDetectStack => _box.get('autoDetectStack', defaultValue: true);
  Future<void> setAutoDetectStack(bool v) => _box.put('autoDetectStack', v);

  bool get stealthMode => _box.get('stealthMode', defaultValue: false);
  Future<void> setStealthMode(bool v) => _box.put('stealthMode', v);

  // --- Profile extras ----------------------------------------------------------
  String get firstName => _box.get('firstName', defaultValue: '');
  String get lastName => _box.get('lastName', defaultValue: '');
  Future<void> setName(String first, String last) async {
    await _box.put('firstName', first);
    await _box.put('lastName', last);
  }

  /// Avatar background as an ARGB int (simple color picker, no photo upload).
  int get avatarColor => _box.get('avatarColor', defaultValue: 0xFFFF6B35);
  Future<void> setAvatarColor(int argb) => _box.put('avatarColor', argb);

  String get initials {
    final f = firstName.isNotEmpty ? firstName[0] : 'E';
    final l = lastName.isNotEmpty ? lastName[0] : 'A';
    return '$f$l'.toUpperCase();
  }
}
