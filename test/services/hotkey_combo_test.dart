import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:extra_ai/services/hotkey_combo.dart';

void main() {
  group('parseCombo', () {
    test('parses ⌘⇧E into meta+shift+keyE', () {
      final hk = parseCombo('⌘⇧E');
      expect(hk, isNotNull);
      expect(hk!.key, PhysicalKeyboardKey.keyE);
      expect(
        hk.modifiers,
        containsAll([HotKeyModifier.meta, HotKeyModifier.shift]),
      );
    });

    test('parses digits (⌘⇧1)', () {
      final hk = parseCombo('⌘⇧1');
      expect(hk!.key, PhysicalKeyboardKey.digit1);
    });

    test('parses control and alt glyphs', () {
      final hk = parseCombo('⌃⌥K');
      expect(hk!.key, PhysicalKeyboardKey.keyK);
      expect(
        hk.modifiers,
        containsAll([HotKeyModifier.control, HotKeyModifier.alt]),
      );
    });

    test('returns null for unsupported keys', () {
      expect(parseCombo('⌘⇧Ф'), isNull);
      expect(parseCombo(''), isNull);
      expect(parseCombo('⌘⇧'), isNull); // modifiers only
    });
  });
}
