import 'package:flutter_test/flutter_test.dart';
import 'package:extra_ai/services/auth_service.dart';

void main() {
  group('AuthService (local/stub)', () {
    late InMemoryAccountStore store;
    late AuthService auth;

    setUp(() {
      store = InMemoryAccountStore();
      auth = AuthService(store: store);
    });

    test('starts signed out', () {
      expect(auth.currentAccount, isNull);
      expect(auth.isSignedIn, isFalse);
    });

    test('registering validates required fields', () async {
      final r = await auth.register(
        fullName: '',
        email: 'x@y.com',
        password: 'password1',
        confirm: 'password1',
      );
      expect(r.ok, isFalse);
      expect(r.error, isNotNull);
    });

    test('rejects a malformed email', () async {
      final r = await auth.register(
        fullName: 'Ada',
        email: 'not-an-email',
        password: 'password1',
        confirm: 'password1',
      );
      expect(r.ok, isFalse);
    });

    test('rejects a short password', () async {
      final r = await auth.register(
        fullName: 'Ada',
        email: 'ada@x.com',
        password: 'short',
        confirm: 'short',
      );
      expect(r.ok, isFalse);
    });

    test('rejects mismatched confirmation', () async {
      final r = await auth.register(
        fullName: 'Ada',
        email: 'ada@x.com',
        password: 'password1',
        confirm: 'password2',
      );
      expect(r.ok, isFalse);
    });

    test('registers a valid account and signs in', () async {
      final r = await auth.register(
        fullName: 'Ada Lovelace',
        email: 'ada@x.com',
        password: 'password1',
        confirm: 'password1',
      );
      expect(r.ok, isTrue);
      expect(auth.isSignedIn, isTrue);
      expect(auth.currentAccount!.email, 'ada@x.com');
      expect(auth.currentAccount!.id, isNotEmpty);
    });

    test('rejects registering a duplicate email', () async {
      await auth.register(
        fullName: 'Ada',
        email: 'ada@x.com',
        password: 'password1',
        confirm: 'password1',
      );
      final dup = await auth.register(
        fullName: 'Ada 2',
        email: 'ADA@x.com', // case-insensitive
        password: 'password1',
        confirm: 'password1',
      );
      expect(dup.ok, isFalse);
    });

    test('sign in requires correct credentials', () async {
      await auth.register(
        fullName: 'Ada',
        email: 'ada@x.com',
        password: 'password1',
        confirm: 'password1',
      );
      await auth.signOut();
      expect(auth.isSignedIn, isFalse);

      final wrong = await auth.signIn(email: 'ada@x.com', password: 'nope');
      expect(wrong.ok, isFalse);
      expect(auth.isSignedIn, isFalse);

      final right =
          await auth.signIn(email: 'ada@x.com', password: 'password1');
      expect(right.ok, isTrue);
      expect(auth.isSignedIn, isTrue);
    });

    test('session persists across a new AuthService over the same store',
        () async {
      await auth.register(
        fullName: 'Ada',
        email: 'ada@x.com',
        password: 'password1',
        confirm: 'password1',
      );
      final id = auth.currentAccount!.id;

      final restored = AuthService(store: store);
      expect(restored.isSignedIn, isTrue);
      expect(restored.currentAccount!.id, id);
    });
  });
}
