import 'dart:convert';

import '../models/extra_ai_response.dart';

/// Validates and parses Gemini's response before it is rendered. The model can
/// occasionally return malformed JSON, markdown-fenced JSON, or content outside
/// expected bounds — never trust it blindly. On any validation failure this
/// returns null and the caller shows a friendly error state (never raw JSON).
class ResponseValidator {
  ResponseValidator._();

  static const int maxImprovedPromptChars = 3000;
  static const int maxIssues = 3;

  static ExtraAIResponse? validateAndParse(String rawResponse) {
    try {
      final cleaned = _stripCodeFences(rawResponse).trim();
      final decoded = jsonDecode(cleaned);
      if (decoded is! Map<String, dynamic>) return null;

      final improved = decoded['improved_prompt'];
      if (improved == null || improved is! String || improved.isEmpty) {
        return null;
      }
      if (improved.length > maxImprovedPromptChars) return null;

      // Normalize issues: coerce to list, cap at maxIssues.
      final rawIssues = decoded['issues'];
      final issues = (rawIssues is List)
          ? rawIssues.map((e) => e.toString()).take(maxIssues).toList()
          : <String>[];
      decoded['issues'] = issues;

      return ExtraAIResponse.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  /// Removes ```json ... ``` (or plain ``` ... ```) fences the model sometimes
  /// wraps around JSON despite being asked for raw JSON.
  static String _stripCodeFences(String input) {
    var s = input.trim();
    if (s.startsWith('```')) {
      final firstNewline = s.indexOf('\n');
      if (firstNewline != -1) {
        s = s.substring(firstNewline + 1);
      }
      final lastFence = s.lastIndexOf('```');
      if (lastFence != -1) {
        s = s.substring(0, lastFence);
      }
    }
    return s;
  }
}
