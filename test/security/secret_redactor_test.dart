import 'package:flutter_test/flutter_test.dart';
import 'package:extra_ai/security/secret_redactor.dart';

void main() {
  group('SecretRedactor', () {
    test('redacts a hardcoded API key assignment', () {
      const input = 'const apiKey = "sk_live_abcdefghijklmnop1234";';
      final result = SecretRedactor.redact(input);
      expect(result, contains('[REDACTED_BY_EXTRA_AI]'));
      expect(result, isNot(contains('sk_live_abcdefghijklmnop1234')));
    });

    test('redacts OpenAI-style sk- keys', () {
      const input = 'OPENAI_KEY=sk-ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890';
      final result = SecretRedactor.redact(input);
      expect(result, isNot(contains('sk-ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890')));
      expect(result, contains('[REDACTED_BY_EXTRA_AI]'));
    });

    test('redacts Google API keys (AIza...)', () {
      const input = 'key: AIzaSyD-1234567890abcdefghijklmnopqrstuvw';
      final result = SecretRedactor.redact(input);
      expect(result, isNot(contains('AIzaSyD-1234567890abcdefghijklmnopqrstuvw')));
      expect(result, contains('[REDACTED_BY_EXTRA_AI]'));
    });

    test('redacts private key headers', () {
      const input = '-----BEGIN RSA PRIVATE KEY-----\nMIIEabc\n';
      final result = SecretRedactor.redact(input);
      expect(result, contains('[REDACTED_BY_EXTRA_AI]'));
      expect(result, isNot(contains('BEGIN RSA PRIVATE KEY')));
    });

    test('redacts database connection strings with credentials', () {
      const input = 'DATABASE_URL=postgres://admin:s3cretpw@db.host:5432/app';
      final result = SecretRedactor.redact(input);
      expect(result, isNot(contains('admin:s3cretpw@')));
      expect(result, contains('[REDACTED_BY_EXTRA_AI]'));
    });

    test('redacts generic password/secret/token assignments', () {
      const input = 'password = "supersecret123"';
      final result = SecretRedactor.redact(input);
      expect(result, isNot(contains('supersecret123')));
      expect(result, contains('[REDACTED_BY_EXTRA_AI]'));
    });

    test('leaves clean code untouched', () {
      const input = 'function add(a, b) { return a + b; }';
      final result = SecretRedactor.redact(input);
      expect(result, equals(input));
    });

    test('reports the number of secrets redacted', () {
      const input =
          'apiKey = "abcdefghijklmnop1234"\npassword = "hunter2password"';
      final result = SecretRedactor.redactWithCount(input);
      expect(result.count, greaterThanOrEqualTo(2));
      expect(result.redacted, contains('[REDACTED_BY_EXTRA_AI]'));
    });

    test('preserves a recognizable prefix so context is not lost', () {
      const input = 'const apiKey = "abcdefghijklmnop1234";';
      final result = SecretRedactor.redact(input);
      // The first 8 chars of the matched segment are kept before the marker.
      expect(result, contains('[REDACTED_BY_EXTRA_AI]'));
    });
  });
}
