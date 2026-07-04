import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:google_generative_ai/google_generative_ai.dart';

import '../models/extra_ai_response.dart';
import '../reliability/reliable_api_caller.dart';
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
    String modelName = 'gemini-2.5-flash',
    // 2.5-flash "thinks" before answering (~13-25s with context), so the
    // budget is generous. The outer ReliableApiCaller uses the same window.
    Duration timeout = const Duration(seconds: 45),
  }) : _timeout = timeout, // ignore: prefer_initializing_formals
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
      final response = await _model.generateContent(parts).timeout(_timeout);
      return response.text;
    } on TimeoutException {
      throw GeminiTimeout();
    }
  }

  /// Lightweight connectivity/auth probe for the launch health check —
  /// a countTokens call, never a full generation.
  Future<bool> healthCheck() async {
    try {
      await _model
          .countTokens([Content.text('ping')])
          .timeout(const Duration(seconds: 6));
      return true;
    } catch (_) {
      return false;
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
  GeminiService({required PromptModel model, this.modelLabel = 'Gemini'})
    : _model = model; // ignore: prefer_initializing_formals

  final PromptModel _model;
  final String modelLabel;

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
    } on ServerException catch (e) {
      return AnalyzeResult.failed(_failureForServerException(e));
    } on TimeoutException {
      return AnalyzeResult.failed(FailureType.networkTimeout);
    } catch (_) {
      return AnalyzeResult.failed(FailureType.unknown);
    }
  }

  /// One corrective pass after a failed verification: resend the original
  /// request together with the previous draft and the critic's specific
  /// instruction, asking Gemini to fix only the flagged issue. Never loops —
  /// best-effort after one retry, latency over perfection.
  Future<AnalyzeResult> correctDraft({
    required String fullPrompt,
    required ExtraAIResponse draft,
    required String correctionInstruction,
    List<int>? screenshotBytes,
  }) async {
    final correctivePrompt =
        '''
$fullPrompt

PREVIOUS DRAFT (JSON):
${jsonEncode(draft.toJson())}

QUALITY CHECK FLAGGED THIS PROBLEM:
$correctionInstruction

Return the corrected JSON only. Change ONLY what is needed to fix the flagged
problem; keep everything else identical to the previous draft.
''';
    try {
      final fixed = await _attempt(correctivePrompt, screenshotBytes);
      if (fixed != null) return AnalyzeResult.success(fixed);
      return AnalyzeResult.failed(FailureType.invalidResponse);
    } on GeminiTimeout {
      return AnalyzeResult.failed(FailureType.networkTimeout);
    } catch (_) {
      return AnalyzeResult.failed(FailureType.unknown);
    }
  }

  /// One anti-stale pass when Gemini returns a valid but replayed answer from
  /// project history. This is deliberately separate from [correctDraft]:
  /// freshness means the draft should be regenerated, not minimally patched.
  Future<AnalyzeResult> regenerateStaleDraft({
    required String fullPrompt,
    required ExtraAIResponse staleDraft,
    required String roughPrompt,
    List<int>? screenshotBytes,
  }) async {
    final freshnessPrompt =
        '''
$fullPrompt

STALE DRAFT THAT MUST NOT BE REUSED:
${jsonEncode(staleDraft.toJson())}

The draft above appears copied from a previous request. Regenerate the JSON from
scratch for THIS CURRENT USER PROMPT only:
"$roughPrompt"

Do not preserve old file targets unless they are clearly relevant to the current
project files and current user prompt. Return corrected JSON only.
''';
    try {
      final fresh = await _attempt(freshnessPrompt, screenshotBytes);
      if (fresh != null) return AnalyzeResult.success(fresh);
      return AnalyzeResult.failed(FailureType.invalidResponse);
    } on GeminiTimeout {
      return AnalyzeResult.failed(FailureType.networkTimeout);
    } catch (_) {
      return AnalyzeResult.failed(FailureType.unknown);
    }
  }

  /// One model call + validation. Returns null if the reply is null/invalid.
  /// The network call itself is wrapped with timeout + retry so a single slow
  /// or dropped request never stalls the pipeline.
  Future<ExtraAIResponse?> _attempt(
    String fullPrompt,
    List<int>? screenshotBytes,
  ) async {
    // gemini-2.5-flash "thinks" before answering (~13-25s with context), so
    // the budget is generous. maxAttempts:1 here because analyze() already
    // does its own retry on a null/invalid parse — a second timeout-retry
    // would stack to 90s.
    final raw = await ReliableApiCaller.callWithRetry(
      () => _model.generate(fullPrompt, screenshotBytes: screenshotBytes),
      timeout: const Duration(seconds: 45),
      maxAttempts: 1,
    );
    if (raw == null) return null;
    return ResponseValidator.validateAndParse(raw);
  }

  FailureType _failureForServerException(ServerException e) {
    final message = e.message.toLowerCase();
    if (message.contains('resource_exhausted') ||
        message.contains('quota') ||
        message.contains('rate') ||
        message.contains('credit') ||
        message.contains('billing')) {
      return FailureType.rateLimited;
    }
    return FailureType.networkTimeout;
  }
}
