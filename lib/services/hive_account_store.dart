import 'package:hive/hive.dart';

import 'auth_service.dart';

/// Hive-backed [AccountStore]. One box holds all account records keyed by
/// lowercased email, plus the active-session pointer.
class HiveAccountStore implements AccountStore {
  HiveAccountStore(this._box);

  static const String boxName = 'accounts';
  static const String _activeKey = '_activeEmail';

  final Box _box;

  @override
  Map<String, Map<String, dynamic>> readAccounts() {
    final out = <String, Map<String, dynamic>>{};
    for (final key in _box.keys) {
      if (key == _activeKey) continue;
      final v = _box.get(key);
      if (v is Map) out[key as String] = Map<String, dynamic>.from(v);
    }
    return out;
  }

  @override
  Future<void> writeAccount(String emailKey, Map<String, dynamic> record) =>
      _box.put(emailKey, record);

  @override
  String? readActiveEmail() => _box.get(_activeKey) as String?;

  @override
  Future<void> writeActiveEmail(String? email) async {
    if (email == null) {
      await _box.delete(_activeKey);
    } else {
      await _box.put(_activeKey, email);
    }
  }
}
