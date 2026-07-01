import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// Signature for loading an asset's string content. Defaults to
/// [rootBundle.loadString]; injectable so tests can supply in-memory JSON.
typedef AssetLoader = Future<String> Function(String path);

/// Loads the 4 curated knowledge-base JSON files once at startup into memory
/// and exposes stack/security/design/tool fragments for the request builder.
/// Never fetched remotely — bundled with the app.
class KnowledgeBaseService {
  KnowledgeBaseService._();

  static const _stackPath = 'assets/knowledge/stack_patterns.json';
  static const _securityPath = 'assets/knowledge/security_patterns.json';
  static const _designPath = 'assets/knowledge/design_heuristics.json';
  static const _toolPath = 'assets/knowledge/tool_syntax.json';

  static Map<String, dynamic>? _stackPatterns;
  static Map<String, dynamic>? _securityPatterns;
  static Map<String, dynamic>? _designHeuristics;
  static Map<String, dynamic>? _toolSyntax;

  /// Loads all four assets. Call once in main.dart at startup.
  static Future<void> loadAll({AssetLoader? loader}) async {
    final load = loader ?? rootBundle.loadString;
    _stackPatterns = _decode(await load(_stackPath));
    _securityPatterns = _decode(await load(_securityPath));
    _designHeuristics = _decode(await load(_designPath));
    _toolSyntax = _decode(await load(_toolPath));
  }

  /// Clears loaded state — for tests.
  static void reset() {
    _stackPatterns = null;
    _securityPatterns = null;
    _designHeuristics = null;
    _toolSyntax = null;
  }

  static Map<String, dynamic> _decode(String raw) {
    final decoded = jsonDecode(raw);
    return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
  }

  static String _key(String s) => s.toLowerCase().replaceAll(' ', '_');

  /// Returns the pattern block for a detected stack (e.g. "react", "Vanilla JS"),
  /// or null if no curated patterns exist for it.
  static Map<String, dynamic>? getStackPatterns(String detectedStack) {
    final value = _stackPatterns?[_key(detectedStack)];
    return value is Map<String, dynamic> ? value : null;
  }

  static Map<String, dynamic> getSecurityPatterns() =>
      _securityPatterns ?? const {};

  static Map<String, dynamic> getDesignHeuristics() =>
      _designHeuristics ?? const {};

  /// Returns the formatting convention block for a target Code AI tool, or null.
  static Map<String, dynamic>? getToolSyntax(String primaryTool) {
    final value = _toolSyntax?[_key(primaryTool)];
    return value is Map<String, dynamic> ? value : null;
  }
}
