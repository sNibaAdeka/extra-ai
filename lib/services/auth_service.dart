// PRIVACY NOTE: accounts are stored locally via Hive only. Auth is stubbed —
// no backend, no real OAuth. Passwords are hashed (not plaintext) but this is
// device-local storage, not a security boundary. Swap in Supabase/Firebase to
// make this real; the AuthService interface is designed for that.

import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/account.dart';

/// Result of an auth operation.
class AuthResult {
  const AuthResult._(this.ok, this.error);
  factory AuthResult.success() => const AuthResult._(true, null);
  factory AuthResult.failure(String error) => AuthResult._(false, error);

  final bool ok;
  final String? error;
}

/// Storage backend for accounts + the active session. Abstracted so the logic
/// is testable without Hive.
abstract class AccountStore {
  /// All accounts by lowercased email.
  Map<String, Map<String, dynamic>> readAccounts();
  Future<void> writeAccount(String emailKey, Map<String, dynamic> record);

  String? readActiveEmail();
  Future<void> writeActiveEmail(String? email);
}

/// In-memory store for tests.
class InMemoryAccountStore implements AccountStore {
  final Map<String, Map<String, dynamic>> _accounts = {};
  String? _active;

  @override
  Map<String, Map<String, dynamic>> readAccounts() => _accounts;

  @override
  Future<void> writeAccount(
    String emailKey,
    Map<String, dynamic> record,
  ) async {
    _accounts[emailKey] = record;
  }

  @override
  String? readActiveEmail() => _active;

  @override
  Future<void> writeActiveEmail(String? email) async => _active = email;
}

/// Local stub authentication. Handles registration, sign-in, sign-out, and a
/// persisted session. The signed-in [Account.id] scopes all per-user data.
class AuthService {
  AuthService({required AccountStore store})
    // ignore: prefer_initializing_formals
    : _store = store {
    _restoreSession();
  }

  final AccountStore _store;
  Account? _current;

  Account? get currentAccount => _current;
  bool get isSignedIn => _current != null;
  String? get activeUserId => _current?.id;

  void _restoreSession() {
    final email = _store.readActiveEmail();
    if (email == null) return;
    final record = _store.readAccounts()[email.toLowerCase()];
    if (record != null) {
      _current = Account.fromMap(Map<String, dynamic>.from(record['account']));
    }
  }

  Future<AuthResult> register({
    required String fullName,
    required String email,
    required String password,
    required String confirm,
  }) async {
    final name = fullName.trim();
    final mail = email.trim();
    if (name.isEmpty) return AuthResult.failure('Enter your full name.');
    if (!_looksLikeEmail(mail)) {
      return AuthResult.failure('Enter a valid email address.');
    }
    if (password.length < 8) {
      return AuthResult.failure('Password must be at least 8 characters.');
    }
    if (password != confirm) {
      return AuthResult.failure('Passwords do not match.');
    }
    final key = mail.toLowerCase();
    if (_store.readAccounts().containsKey(key)) {
      return AuthResult.failure('An account with this email already exists.');
    }

    final account = Account(
      id: _newId(mail),
      fullName: name,
      email: mail,
      createdAt: DateTime.now(),
    );
    await _store.writeAccount(key, {
      'account': account.toMap(),
      'passwordHash': _hash(password),
    });
    await _store.writeActiveEmail(mail);
    _current = account;
    return AuthResult.success();
  }

  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    final key = email.trim().toLowerCase();
    final record = _store.readAccounts()[key];
    if (record == null) {
      return AuthResult.failure('No account found for that email.');
    }
    if (record['passwordHash'] != _hash(password)) {
      return AuthResult.failure('Incorrect email or password.');
    }
    _current = Account.fromMap(Map<String, dynamic>.from(record['account']));
    await _store.writeActiveEmail(_current!.email);
    return AuthResult.success();
  }

  Future<void> signOut() async {
    _current = null;
    await _store.writeActiveEmail(null);
  }

  static bool _looksLikeEmail(String s) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s);

  static String _hash(String password) =>
      sha256.convert(utf8.encode('extra_ai_salt::$password')).toString();

  static String _newId(String email) =>
      'u_${email.hashCode.toUnsigned(32).toRadixString(16)}_'
      '${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}';
}
