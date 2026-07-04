import '../models/analysis_preferences.dart';
import '../models/extra_ai_response.dart';
import '../models/project_intelligence.dart';
import '../models/response_quality_report.dart';

/// Fast local response gate. It catches the most expensive failure modes before
/// the user copies the prompt: invented @file paths, generic output, and audit
/// toggles that were requested but not reflected in the response.
class ResponseQualityService {
  ResponseQualityService._();

  static ResponseQualityReport evaluate({
    required ExtraAIResponse response,
    required List<String> knownFiles,
    required AnalysisPreferences preferences,
    ProjectIntelligence? intelligence,
  }) {
    final prompt = response.improvedPrompt.trim();
    final lowerPrompt = prompt.toLowerCase();
    final passed = <String>[];
    final warnings = <String>[];
    final failed = <String>[];

    if (prompt.split(RegExp(r'\s+')).length <= 150) {
      passed.add('Prompt is short enough to paste quickly.');
    } else {
      warnings.add('Prompt is long; consider editing before pasting.');
    }

    final refs = _extractFileRefs(prompt);
    if (refs.isEmpty) {
      if (knownFiles.isEmpty) {
        warnings.add('No project files were available for reference checking.');
      } else {
        warnings.add('Prompt does not reference a concrete project file.');
      }
    } else {
      final known = knownFiles.map(_normalizePath).toSet();
      final missing = refs
          .where((ref) => !_matchesKnownFile(_normalizePath(ref), known))
          .toList();
      if (missing.isEmpty) {
        passed.add('All @file references match the selected project snapshot.');
      } else {
        failed.add('Unknown file reference: @${missing.first}.');
      }
    }

    if (_hasConcreteAction(lowerPrompt)) {
      passed.add('Prompt contains a concrete implementation action.');
    } else {
      warnings.add('Prompt may be too broad; it needs a clearer action verb.');
    }

    if (preferences.securityAudit &&
        !_mentionsAny(lowerPrompt, const [
          'security',
          'secret',
          'api key',
          'token',
          'unsafe',
        ])) {
      warnings.add(
        'Security audit is enabled, but the prompt does not mention safety checks.',
      );
    }

    if (preferences.bugAudit &&
        response.issues.isEmpty &&
        !_mentionsAny(lowerPrompt, const [
          'bug',
          'regression',
          'responsive',
          'overflow',
          'check',
        ])) {
      warnings.add(
        'Bug audit is enabled, but no bug/regression check is visible.',
      );
    }

    if (intelligence != null &&
        intelligence.recommendedChecks.isNotEmpty &&
        !_mentionsAny(
          lowerPrompt,
          intelligence.recommendedChecks.map((e) => e.toLowerCase()).toList(),
        )) {
      warnings.add('Prompt does not mention the recommended project checks.');
    }

    final status = failed.isNotEmpty
        ? ResponseQualityStatus.failed
        : warnings.isNotEmpty
        ? ResponseQualityStatus.warning
        : ResponseQualityStatus.passed;

    return ResponseQualityReport(
      status: status,
      passedChecks: passed,
      warnings: warnings,
      failedChecks: failed,
    );
  }

  static List<String> _extractFileRefs(String prompt) {
    final refs = <String>[];
    final pattern = RegExp(r'@([A-Za-z0-9_\-./]+\.[A-Za-z0-9]+)');
    for (final match in pattern.allMatches(prompt)) {
      final ref = match.group(1);
      if (ref != null && ref.trim().isNotEmpty) refs.add(ref.trim());
    }
    return refs;
  }

  static bool _matchesKnownFile(String ref, Set<String> knownFiles) {
    return knownFiles.any((file) => file == ref || file.endsWith('/$ref'));
  }

  static String _normalizePath(String path) => path
      .replaceAll('\\', '/')
      .replaceFirst(RegExp(r'^\./'), '')
      .toLowerCase();

  static bool _hasConcreteAction(String lowerPrompt) {
    const verbs = [
      'add',
      'adjust',
      'change',
      'create',
      'fix',
      'implement',
      'make',
      'move',
      'remove',
      'replace',
      'update',
      'verify',
      'добав',
      'измени',
      'исправ',
      'замени',
      'проверь',
      'сделай',
      'убери',
    ];
    return verbs.any(lowerPrompt.contains);
  }

  static bool _mentionsAny(String lowerPrompt, List<String> needles) {
    return needles.any((needle) => lowerPrompt.contains(needle.toLowerCase()));
  }
}
