import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Inline hotkey-capture control: shows "Press any key combination..." and
/// resolves the next modifier+key press into a display combo like "⌘⇧E".
/// Used by onboarding Step 2, Settings → Shortcuts, and Quick Templates —
/// one implementation everywhere.
class HotkeyCapture extends StatefulWidget {
  const HotkeyCapture({
    super.key,
    required this.onCaptured,
    this.prompt = 'Press any key combination...',
  });

  final ValueChanged<String> onCaptured;
  final String prompt;

  @override
  State<HotkeyCapture> createState() => _HotkeyCaptureState();
}

class _HotkeyCaptureState extends State<HotkeyCapture> {
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    // Ignore bare modifier presses — wait for the non-modifier key.
    if (_isModifier(key)) return KeyEventResult.handled;

    final pressed = HardwareKeyboard.instance;
    final combo = StringBuffer();
    if (pressed.isControlPressed) combo.write('⌃');
    if (pressed.isAltPressed) combo.write('⌥');
    if (pressed.isShiftPressed) combo.write('⇧');
    if (pressed.isMetaPressed) combo.write('⌘');
    combo.write(_displayKey(key));

    widget.onCaptured(combo.toString());
    return KeyEventResult.handled;
  }

  static bool _isModifier(LogicalKeyboardKey key) => _modifierKeys.contains(key);

  static final Set<LogicalKeyboardKey> _modifierKeys = {
        LogicalKeyboardKey.shiftLeft,
        LogicalKeyboardKey.shiftRight,
        LogicalKeyboardKey.metaLeft,
        LogicalKeyboardKey.metaRight,
        LogicalKeyboardKey.altLeft,
        LogicalKeyboardKey.altRight,
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.controlRight,
      };

  static String _displayKey(LogicalKeyboardKey key) {
    final label = key.keyLabel;
    if (label.isEmpty) return '?';
    if (label == ' ') return 'Space';
    return label.length == 1 ? label.toUpperCase() : label;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.borderFocus),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.keyboard_outlined,
                size: 16, color: AppTheme.accent),
            const SizedBox(width: 8),
            Text(
              widget.prompt,
              style: AppTheme.ui(size: 13, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
