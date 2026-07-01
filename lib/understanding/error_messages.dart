/// Every failure the app can hit, mapped to a specific state. The UI never
/// shows raw errors, stack traces, or HTTP codes — only these human messages.
enum FailureType {
  networkTimeout,
  rateLimited,
  invalidResponse,
  fileTooLarge,
  noApiKey,
  unknown,
}

/// Maps a failure to a calm, non-technical, human message. Graceful degradation
/// — the user should never feel the app "broke", only that something needs a
/// retry or a small adjustment.
class ErrorMessages {
  ErrorMessages._();

  static String forFailure(FailureType type) {
    switch (type) {
      case FailureType.networkTimeout:
        return 'This is taking longer than usual — check your connection and try again.';
      case FailureType.rateLimited:
        return "Slow down a bit — you've hit the request limit. Try again in a minute.";
      case FailureType.invalidResponse:
        return 'Something went sideways reading the result — try again.';
      case FailureType.fileTooLarge:
        return "That's a lot of code — try dropping just the relevant files.";
      case FailureType.noApiKey:
        return "Extra AI isn't fully set up yet — check settings.";
      case FailureType.unknown:
        return 'Something went wrong — try again in a moment.';
    }
  }
}
