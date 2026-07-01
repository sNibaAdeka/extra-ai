import 'dart:async';
import 'dart:typed_data';

import 'package:google_generative_ai/google_generative_ai.dart';

import '../models/extra_ai_response.dart';
import '../security/response_validator.dart';
import '../understanding/error_messages.dart';
import 'system_prompt.dart';

/// Thrown when a Gemini request exceeds the timeout budget.
class GeminiTimeout implements Exception {
  @override
  String toString() => 'GeminiTimeout';
}

/// Minimal abstraction over the underlying LLM so GeminiService's parse +
/// validate + error-map flow is testable without a network call or API key.
abstract class PromptModel {
  /// Returns the raw model text, or null if the model produced nothing.
  Future<String?> generate(String prompt, {List<int>? screenshotBytes});
}

/// Real implementation backed by google_generative_ai. Sends the combined
/// system prompt as a system instruction and requests JSON output.
class GeminiPromptModel implements PromptModel {
  GeminiPromptModel({
    required String apiKey,
    String modelName = 'gemini-2.0-flash',
    Duration timeout = const Duration(seconds: 15),
  })  : _timeout = timeout, // ignore: prefer_initializing_formals
        _model = GenerativeModel(
          model: modelName,
          apiKey: apiKey,
          systemInstruction: Content.system(kExtraAiSystemPrompt),
          generationConfig: GenerationConfig(
            responseMimeType: 'application/json',
          ),
        );

  final GenerativeModel _model;
  final Duration _timeout;

  @override
  Future<String?> generate(String prompt, {List<int>? screenshotBytes}) async {
    final parts = <Content>[
      if (screenshotBytes != null)
        Content.data('image/png', Uint8List.fromList(screenshotBytes)),
      Content.text(prompt),
    ];
    try {
      final response =
          await _model.generateContent(parts).timeout(_timeout);
      return response.text;
    } on TimeoutException {
      throw GeminiTimeout();
    }
  }
}

/// Outcome of an analyze call: either a validated response, or a FailureType
/// the UI maps to a human message. Never carries raw errors.
class AnalyzeResult {
  const AnalyzeResult._(this.response, this.failure);

  final ExtraAIResponse? response;
  final FailureType? failure;

  bool get isSuccess => response != null;

  factory AnalyzeResult.success(ExtraAIResponse response) =>
      AnalyzeResult._(response, null);
  factory AnalyzeResult.failed(FailureType failure) =>
      AnalyzeResult._(null, failure);
}

/// Orchestrates a single analysis: calls the model, validates the JSON, retries
/// once on a bad parse, and maps every error to a FailureType.
class GeminiService {
  GeminiService({required PromptModel model}) : _model = model; // ignore: prefer_initializing_formals

  final PromptModel _model;

  Future<AnalyzeResult> analyze({
    required String fullPrompt,
    List<int>? screenshotBytes,
  }) async {
    try {
      final first = await _attempt(fullPrompt, screenshotBytes);
      if (first != null) return AnalyzeResult.success(first);

      // Retry once on invalid/empty JSON before giving up.
      final second = await _attempt(fullPrompt, screenshotBytes);
      if (second != null) return AnalyzeResult.success(second);

      return AnalyzeResult.failed(FailureType.invalidResponse);
    } on GeminiTimeout {
      return AnalyzeResult.failed(FailureType.networkTimeout);
    } on InvalidApiKey {
      return AnalyzeResult.failed(FailureType.noApiKey);
    } on UnsupportedUserLocation {
      return AnalyzeResult.failed(FailureType.unknown);
    } on ServerException {
      return AnalyzeResult.failed(FailureType.networkTimeout);
    } on TimeoutException {
      return AnalyzeResult.failed(FailureType.networkTimeout);
    } catch (_) {
      return AnalyzeResult.failed(FailureType.unknown);
    }
  }

  /// One model call + validation. Returns null if the reply is null/invalid.
  Future<ExtraAIResponse?> _attempt(
    String fullPrompt,
    List<int>? screenshotBytes,
  ) async {
    final raw = await _model.generate(fullPrompt, screenshotBytes: screenshotBytes);
    if (raw == null) return null;
    return ResponseValidator.validateAndParse(raw);
  }
}
