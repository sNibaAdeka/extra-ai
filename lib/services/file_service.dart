import 'dart:io';

import '../security/secret_redactor.dart';

/// A project's files after reading + secret redaction, ready to embed in a
/// Gemini request. The original unredacted content is never retained here.
class LoadedProject {
  const LoadedProject({
    required this.fileNames,
    required this.redactedContentByName,
    required this.concatenatedContent,
    required this.redactedSecretCount,
  });

  final List<String> fileNames;
  final Map<String, String> redactedContentByName;

  /// All files concatenated, each labeled by name — the block sent to Gemini.
  final String concatenatedContent;

  /// How many secrets were redacted across all files (for the trust notice).
  final int redactedSecretCount;

  bool get isEmpty => fileNames.isEmpty;
}

/// Reads project files and — critically — redacts secrets BEFORE the content is
/// ever used, concatenated, stored, or transmitted. Disk/picker reading is a
/// thin wrapper over the pure [buildFromRaw] assembly so the security-critical
/// logic is fully testable.
class FileService {
  FileService._();

  /// Pure assembly from an in-memory map of fileName -> raw content. Runs
  /// redaction on each file, then concatenates with per-file labels.
  static LoadedProject buildFromRaw(Map<String, String> rawByName) {
    final redactedByName = <String, String>{};
    final buffer = StringBuffer();
    var totalRedactions = 0;

    for (final entry in rawByName.entries) {
      final result = SecretRedactor.redactWithCount(entry.value);
      redactedByName[entry.key] = result.redacted;
      totalRedactions += result.count;

      buffer.writeln('--- ${entry.key} ---');
      buffer.writeln(result.redacted);
      buffer.writeln();
    }

    return LoadedProject(
      fileNames: rawByName.keys.toList(growable: false),
      redactedContentByName: redactedByName,
      concatenatedContent: buffer.toString(),
      redactedSecretCount: totalRedactions,
    );
  }

  /// Reads the given file paths from disk (best-effort, skipping unreadable or
  /// binary-looking files) and returns a redacted [LoadedProject].
  static Future<LoadedProject> loadFromPaths(List<String> paths) async {
    final raw = <String, String>{};
    for (final path in paths) {
      final file = File(path);
      try {
        if (!await file.exists()) continue;
        final content = await file.readAsString();
        raw[_baseName(path)] = content;
      } catch (_) {
        // Unreadable / binary file — skip it rather than fail the whole load.
        continue;
      }
    }
    return buildFromRaw(raw);
  }

  static String _baseName(String path) {
    final normalized = path.replaceAll('\\', '/');
    final idx = normalized.lastIndexOf('/');
    return idx == -1 ? normalized : normalized.substring(idx + 1);
  }
}
