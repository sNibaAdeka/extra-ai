import 'dart:typed_data';

/// Outcome of validating a request before it is sent to Gemini.
class ValidationResult {
  const ValidationResult._(this.isValid, this.message);

  final bool isValid;
  final String? message;

  factory ValidationResult.ok() => const ValidationResult._(true, null);
  factory ValidationResult.error(String message) =>
      ValidationResult._(false, message);
}

/// Validates the request payload before anything is sent to Gemini. Guards
/// against empty prompts, oversized prompts, oversized file payloads, and
/// oversized screenshots — protecting both response quality and API cost.
class RequestValidator {
  RequestValidator._();

  static const int maxPromptChars = 2000;
  static const int maxTotalFileBytes = 500000; // ~500KB
  static const int maxScreenshotBytes = 5000000; // 5MB

  static ValidationResult validate({
    required String roughPrompt,
    required List<String> fileContents,
    required Uint8List? screenshotBytes,
  }) {
    if (roughPrompt.trim().isEmpty) {
      return ValidationResult.error('Write what you want to change first.');
    }
    if (roughPrompt.length > maxPromptChars) {
      return ValidationResult.error(
        "That's a lot — try breaking it into smaller requests for better results.",
      );
    }
    final totalFileSize =
        fileContents.fold<int>(0, (sum, f) => sum + f.length);
    if (totalFileSize > maxTotalFileBytes) {
      return ValidationResult.error(
        'Project is large — Extra AI works best with focused file selections. '
        'Try dropping only the relevant files.',
      );
    }
    if (screenshotBytes != null &&
        screenshotBytes.length > maxScreenshotBytes) {
      return ValidationResult.error('Screenshot too large — try again.');
    }
    return ValidationResult.ok();
  }
}
