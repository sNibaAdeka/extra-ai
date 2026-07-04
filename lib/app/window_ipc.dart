import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';

import '../models/project_context.dart';
import '../models/prompt_history_entry.dart';

/// Cross-window IPC over desktop_multi_window 0.3.0 named channels.
///
/// Why both directions exist (the classic bug this avoids): Window 2 is often
/// created AFTER a project was selected in Window 1, and stays alive (hidden)
/// while state changes in Window 1. A push-only model misses the initial
/// state; a pull-only model misses later changes. So:
///   - the overlay PULLS current state on its own startup (getState), and
///   - the main window PUSHES stateSync on every overlay show / selection
///     change, and
///   - the overlay pushes back analysisSaved / projectSelected so the main
///     window's dashboards stay fresh (Hive boxes are per-engine copies —
///     two isolates never see each other's in-memory writes).
class WindowIpc {
  WindowIpc._();

  /// Handler lives in the OVERLAY engine; the main window invokes it.
  static const overlayChannel = WindowMethodChannel(
    'extra_ai/overlay',
    mode: ChannelMode.unidirectional,
  );

  /// Handler lives in the MAIN engine; the overlay invokes it.
  static const mainChannel = WindowMethodChannel(
    'extra_ai/main',
    mode: ChannelMode.unidirectional,
  );

  // --- payload codec -----------------------------------------------------------

  static String encodeState({
    required List<ProjectContext> projects,
    required String? selectedHash,
  }) => jsonEncode({
    'selectedHash': selectedHash,
    'projects': [for (final p in projects) p.toMap()],
  });

  static ({List<ProjectContext> projects, String? selectedHash}) decodeState(
    String raw,
  ) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return (
      projects: [
        for (final m in (json['projects'] as List? ?? const []))
          ProjectContext.fromMap(Map<String, dynamic>.from(m as Map)),
      ],
      selectedHash: json['selectedHash'] as String?,
    );
  }

  // --- main window → overlay -----------------------------------------------------

  /// Push the authoritative project state to the overlay. Safe to call even
  /// when the overlay hasn't registered yet (first frames after creation) —
  /// retries briefly, then gives up quietly; the overlay's startup pull
  /// covers that window.
  static Future<void> pushStateToOverlay({
    required List<ProjectContext> projects,
    required String? selectedHash,
    int attempts = 5,
  }) async {
    final payload = encodeState(projects: projects, selectedHash: selectedHash);
    for (var i = 0; i < attempts; i++) {
      try {
        await overlayChannel.invokeMethod('stateSync', payload);
        return;
      } catch (_) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
    }
    debugPrint('[ipc] pushStateToOverlay: overlay channel unavailable');
  }

  // --- overlay → main window -----------------------------------------------------

  /// Pull current state on overlay startup.
  static Future<({List<ProjectContext> projects, String? selectedHash})?>
  fetchStateFromMain() async {
    try {
      final raw = await mainChannel.invokeMethod<String>('getState');
      if (raw == null) return null;
      return decodeState(raw);
    } catch (e) {
      debugPrint('[ipc] fetchStateFromMain failed: $e');
      return null;
    }
  }

  /// Tell the main window an analysis was persisted (its Hive instance won't
  /// see the overlay's write — it merges this entry in memory instead).
  static Future<void> notifyAnalysisSaved(PromptHistoryEntry entry) async {
    try {
      await mainChannel.invokeMethod(
        'analysisSaved',
        jsonEncode(entry.toMap()),
      );
    } catch (e) {
      debugPrint('[ipc] notifyAnalysisSaved failed: $e');
    }
  }

  /// Tell the main window the user switched projects in the overlay picker,
  /// so the selection is persisted by the single Hive writer (main window).
  static Future<void> notifyProjectSelected(String pathHash) async {
    try {
      await mainChannel.invokeMethod('projectSelected', pathHash);
    } catch (e) {
      debugPrint('[ipc] notifyProjectSelected failed: $e');
    }
  }
}
