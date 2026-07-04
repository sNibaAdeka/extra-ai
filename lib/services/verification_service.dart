import 'dart:convert';

import '../models/extra_ai_response.dart';
import '../models/user_profile.dart';

/// Minimal abstraction over the critic LLM (a structurally different model
/// from the generator) so the verification flow is testable without network.
abstract class CriticModel {
  /// Whether credentials are present. When false, verification is skipped
  /// entirely (feature off) rather than reported as degraded.
  bool get isConfigured;

  /// Returns the raw model text, or null if the model produced nothing.
  Future<String?> chat(String prompt, {bool jsonMode = true});
}

/// The critic's verdict on a draft response.
class VerificationResult {
  const VerificationResult({
    required this.passed,
    required this.failedChecks,
    this.correctionInstruction,
  });

  final bool passed;
  final List<String> failedChecks;

  /// One-sentence instruction for the corrective pass; null when passed.
  final String? correctionInstruction;

  factory VerificationResult.fromJson(Map<String, dynamic> json) {
    final rawInstruction = json['correction_instruction'];
    final instruction = (rawInstruction == null || rawInstruction == 'null')
        ? null
        : rawInstruction.toString();
    return VerificationResult(
      passed: json['passed'] == true,
      failedChecks: ((json['failed_checks'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      correctionInstruction: (instruction != null && instruction.trim().isEmpty)
          ? null
          : instruction,
    );
  }
}

/// Two-model verification (generator + critic pattern). Gemini generates;
/// this service asks a structurally different model (GPT-4o-mini on Azure)
/// to check the draft against the ground-truth files BEFORE it reaches the
/// user — catching hallucinated file/class references, over-length prompts,
/// invented issues, and tone mismatches. A same-family critic would share the
/// generator's blind spots; a different architecture catches a different
/// class of errors.
///
/// Returns null when the critic is unreachable or unparseable — the caller
/// degrades gracefully (shows the draft with an honest note) rather than
/// blocking the user on the quality gate.
class VerificationService {
  VerificationService({required CriticModel critic})
    : _critic = critic; // ignore: prefer_initializing_formals

  final CriticModel _critic;

  bool get isConfigured => _critic.isConfigured;

  Future<VerificationResult?> verify({
    required ExtraAIResponse draft,
    required String originalFileContents,
    required UserProfile userProfile,
  }) async {
    final checkPrompt =
        '''
You are a strict quality checker for an AI coding assistant's output.
You do not generate new content — you only verify.

DRAFT RESPONSE TO CHECK:
improved_prompt: "${draft.improvedPrompt}"
issues: ${jsonEncode(draft.issues)}

ORIGINAL PROJECT FILES (ground truth):
$originalFileContents

USER EXPERIENCE LEVEL: ${userProfile.experienceLevel.description}

Check these four things and respond with JSON only:
1. Does improved_prompt reference file names or class/element names that
   actually appear in the project files above? (true/false)
2. Is improved_prompt under 150 words and phrased as a direct instruction,
   not a question? (true/false)
3. Do the issues describe patterns that are actually visible in the
   provided files, not generic or invented problems? (true/false)
4. Is the language complexity appropriate for a "${userProfile.experienceLevel.description}" user? (true/false)

{
  "passed": boolean (true only if ALL four checks pass),
  "failed_checks": ["which check numbers failed, if any"],
  "correction_instruction": "if failed, a specific one-sentence instruction for what to fix — null if passed"
}
''';

    try {
      final raw = await _critic.chat(checkPrompt, jsonMode: true);
      if (raw == null) return null;
      final decoded = jsonDecode(_stripCodeFences(raw));
      if (decoded is! Map<String, dynamic>) return null;
      return VerificationResult.fromJson(decoded);
    } catch (_) {
      // Unreachable critic or malformed verdict — report unavailable, never
      // block the user's result on the quality gate.
      return null;
    }
  }

  static String _stripCodeFences(String input) {
    var s = input.trim();
    if (s.startsWith('```')) {
      final firstNewline = s.indexOf('\n');
      if (firstNewline != -1) s = s.substring(firstNewline + 1);
      final lastFence = s.lastIndexOf('```');
      if (lastFence != -1) s = s.substring(0, lastFence);
    }
    return s.trim();
  }
}
