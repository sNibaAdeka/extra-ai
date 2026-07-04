import 'dart:async';

/// Wraps any async API call with a timeout, bounded retries, and linear
/// backoff. Applied to both the Gemini generation call and the Azure
/// verification call so a single slow/failed request never freezes the UI —
/// the caller always gets either a result or an exception it can map to a
/// human error message.
class ReliableApiCaller {
  ReliableApiCaller._();

  static Future<T> callWithRetry<T>(
    Future<T> Function() call, {
    int maxAttempts = 2,
    Duration timeout = const Duration(seconds: 45),
    Duration backoffBase = const Duration(milliseconds: 500),
  }) async {
    Object? lastError;
    StackTrace? lastStack;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await call().timeout(timeout);
      } catch (e, st) {
        lastError = e;
        lastStack = st;
        if (attempt < maxAttempts) {
          await Future<void>.delayed(backoffBase * attempt);
        }
      }
    }
    Error.throwWithStackTrace(lastError!, lastStack!);
  }
}
