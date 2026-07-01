/// Result of a redaction pass, carrying how many secrets were replaced so the
/// UI can show the trust-building notice ("Redacted 1 potential secret").
class RedactionResult {
  const RedactionResult(this.redacted, this.count);

  final String redacted;
  final int count;
}

/// Scans and redacts likely secrets from file content BEFORE anything leaves
/// the device. This protects the user even if they forgot a .env file was
/// included, or hardcoded a key. The original secret is never logged, stored,
/// or transmitted — only the redacted form travels onward.
///
/// Regex-pattern based (not exhaustive entropy detection) — catches common
/// patterns, which is the honest MVP scope.
class SecretRedactor {
  SecretRedactor._();

  static const String _marker = '[REDACTED_BY_EXTRA_AI]';

  /// Ordered so more specific patterns (private keys, DB strings, provider
  /// keys) run before the broad key/value catch-alls.
  static final List<RegExp> secretPatterns = [
    // Private keys — match the whole BEGIN header line.
    RegExp(r'-----BEGIN (RSA |EC )?PRIVATE KEY-----'),
    // DB connection strings with embedded user:pass@
    RegExp(r'(postgres|postgresql|mysql|mongodb)(\+srv)?:\/\/[^:\s]+:[^@\s]+@'),
    // OpenAI-style keys
    RegExp(r'sk-[a-zA-Z0-9]{20,}'),
    // Google API keys
    RegExp(r'AIza[0-9A-Za-z\-_]{35}'),
    // Generic api_key / apikey = "..." assignments
    RegExp(
      '''(api[_-]?key|apikey)\\s*[:=]\\s*["']([a-zA-Z0-9_\\-]{16,})["']''',
      caseSensitive: false,
    ),
    // Generic secret / password / token = "..." assignments
    RegExp(
      '''(secret|password|token)\\s*[:=]\\s*["']([^"']{8,})["']''',
      caseSensitive: false,
    ),
  ];

  /// Redacts secrets, preserving a short recognizable prefix so surrounding
  /// context is not lost. Returns just the redacted string.
  static String redact(String fileContent) => redactWithCount(fileContent).redacted;

  /// Redacts secrets and reports how many replacements were made.
  static RedactionResult redactWithCount(String fileContent) {
    var result = fileContent;
    var count = 0;
    for (final pattern in secretPatterns) {
      result = result.replaceAllMapped(pattern, (match) {
        count++;
        final matched = match.group(0)!;
        final prefixLen = matched.length < 8 ? matched.length : 8;
        return '${matched.substring(0, prefixLen)}$_marker';
      });
    }
    return RedactionResult(result, count);
  }
}
