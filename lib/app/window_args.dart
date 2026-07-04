import 'dart:convert';

/// Identifies which of the two windows an engine is hosting.
///
/// The main app window (Window 1) launches with empty arguments; the overlay
/// window (Window 2) is created via desktop_multi_window with the encoded
/// [OverlayWindowArgs] so its engine knows to render the overlay UI.
enum WindowKind { main, overlay }

class WindowArgs {
  const WindowArgs({required this.kind, this.activeUserId});

  final WindowKind kind;

  /// The signed-in user id, passed to the overlay so its Hive-scoped data
  /// matches the main window. Null before sign-in.
  final String? activeUserId;

  static const String _overlayBusinessId = 'overlay';

  /// Parse the raw `arguments` string a window receives at launch.
  factory WindowArgs.parse(String raw) {
    if (raw.isEmpty) return const WindowArgs(kind: WindowKind.main);
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['businessId'] == _overlayBusinessId) {
        return WindowArgs(
          kind: WindowKind.overlay,
          activeUserId: json['activeUserId'] as String?,
        );
      }
    } catch (_) {
      // Malformed → treat as the main window rather than crash.
    }
    return const WindowArgs(kind: WindowKind.main);
  }

  /// Encode for `WindowController.create(WindowConfiguration(arguments: ...))`.
  static String encodeOverlay({String? activeUserId}) => jsonEncode({
    'businessId': _overlayBusinessId,
    // ignore: use_null_aware_elements
    if (activeUserId != null) 'activeUserId': activeUserId,
  });
}
