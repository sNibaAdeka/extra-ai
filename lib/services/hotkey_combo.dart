import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

/// Parses a display combo captured by HotkeyCapture ("⌘⇧E", "⌃⌥K", "⌘⇧1")
/// into a registrable system HotKey. Returns null when the trailing key is
/// not a Latin letter or digit (unsupported for global registration).
HotKey? parseCombo(String combo) {
  if (combo.isEmpty) return null;

  final modifiers = <HotKeyModifier>[];
  var rest = combo;
  var consumed = true;
  while (consumed && rest.isNotEmpty) {
    consumed = true;
    if (rest.startsWith('⌃')) {
      modifiers.add(HotKeyModifier.control);
    } else if (rest.startsWith('⌥')) {
      modifiers.add(HotKeyModifier.alt);
    } else if (rest.startsWith('⇧')) {
      modifiers.add(HotKeyModifier.shift);
    } else if (rest.startsWith('⌘')) {
      modifiers.add(HotKeyModifier.meta);
    } else {
      consumed = false;
    }
    if (consumed) rest = rest.substring(1);
  }

  if (rest.length != 1) return null;
  final key = _keyFor(rest.toUpperCase());
  if (key == null) return null;

  return HotKey(key: key, modifiers: modifiers, scope: HotKeyScope.system);
}

PhysicalKeyboardKey? _keyFor(String char) {
  const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  const digits = '0123456789';
  final letterKeys = [
    PhysicalKeyboardKey.keyA, PhysicalKeyboardKey.keyB, PhysicalKeyboardKey.keyC, //
    PhysicalKeyboardKey.keyD, PhysicalKeyboardKey.keyE, PhysicalKeyboardKey.keyF,
    PhysicalKeyboardKey.keyG, PhysicalKeyboardKey.keyH, PhysicalKeyboardKey.keyI,
    PhysicalKeyboardKey.keyJ, PhysicalKeyboardKey.keyK, PhysicalKeyboardKey.keyL,
    PhysicalKeyboardKey.keyM, PhysicalKeyboardKey.keyN, PhysicalKeyboardKey.keyO,
    PhysicalKeyboardKey.keyP, PhysicalKeyboardKey.keyQ, PhysicalKeyboardKey.keyR,
    PhysicalKeyboardKey.keyS, PhysicalKeyboardKey.keyT, PhysicalKeyboardKey.keyU,
    PhysicalKeyboardKey.keyV, PhysicalKeyboardKey.keyW, PhysicalKeyboardKey.keyX,
    PhysicalKeyboardKey.keyY, PhysicalKeyboardKey.keyZ,
  ];
  final digitKeys = [
    PhysicalKeyboardKey.digit0, PhysicalKeyboardKey.digit1, //
    PhysicalKeyboardKey.digit2, PhysicalKeyboardKey.digit3,
    PhysicalKeyboardKey.digit4, PhysicalKeyboardKey.digit5,
    PhysicalKeyboardKey.digit6, PhysicalKeyboardKey.digit7,
    PhysicalKeyboardKey.digit8, PhysicalKeyboardKey.digit9,
  ];
  final li = letters.indexOf(char);
  if (li != -1) return letterKeys[li];
  final di = digits.indexOf(char);
  if (di != -1) return digitKeys[di];
  return null;
}
