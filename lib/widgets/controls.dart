import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// THE keycap component. Every hotkey rendered anywhere in the app goes
/// through this widget — never re-implemented per screen.
/// `KeycapBadge(keys: ['⌘','⇧','E'])` renders three macOS-style keycaps.
class KeycapBadge extends StatelessWidget {
  const KeycapBadge({
    super.key,
    required this.keys,
    this.size = KeycapSize.medium,
  });

  /// Single-string convenience: `KeycapBadge.combo('⌘⇧E')` splits per rune.
  KeycapBadge.combo(String combo, {super.key, this.size = KeycapSize.medium})
    : keys = combo.runes.map(String.fromCharCode).toList();

  final List<String> keys;
  final KeycapSize size;

  @override
  Widget build(BuildContext context) {
    final compact = size == KeycapSize.small;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < keys.length; i++) ...[
          if (i > 0) SizedBox(width: compact ? 3 : 5),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 5 : 8,
              vertical: compact ? 2 : 5,
            ),
            decoration: BoxDecoration(
              color: AppTheme.surfaceHigh,
              borderRadius: BorderRadius.circular(compact ? 4 : 6),
              border: Border.all(color: AppTheme.borderSubtle),
              boxShadow: const [
                BoxShadow(color: Color(0x33000000), offset: Offset(0, 1)),
              ],
            ),
            child: Text(
              keys[i],
              style: AppTheme.mono(
                size: compact ? 10 : 12,
                weight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

enum KeycapSize { small, medium }

/// Hover/press wrapper giving any child the mandated three states:
/// default → hover (subtle lighten) → pressed (scale 0.98).
class PressableScale extends StatefulWidget {
  const PressableScale({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap == null
          ? MouseCursor.defer
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTapDown: widget.onTap == null
            ? null
            : (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? 0.98 : 1.0,
          duration: AppTheme.microMs,
          curve: AppTheme.easeOut,
          child: AnimatedOpacity(
            opacity: _hover ? 0.92 : 1.0,
            duration: AppTheme.microMs,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Selectable chip — single- and multi-select flows share this one widget.
/// Selected: ember filled with dark text. Unselected: outlined, cream-dim.
class SelectChip extends StatelessWidget {
  const SelectChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.leading,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppTheme.microMs,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppTheme.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: selected ? AppTheme.accent : AppTheme.borderSubtle,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 6)],
            Text(
              label,
              style: AppTheme.ui(
                size: 13,
                weight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? AppTheme.onAccent : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ember toggle switch: muted track off, ember track on, 150ms slide.
class EmberToggle extends StatelessWidget {
  const EmberToggle({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        width: 42,
        height: 24,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value
              ? AppTheme.accent
              : AppTheme.textDim.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(100),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 18,
            height: 18,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

/// Segmented control (Theme System/Light/Dark, tone preference, billing
/// period). Active segment: ember filled.
class SegmentedControl<T> extends StatelessWidget {
  const SegmentedControl({
    super.key,
    required this.options,
    required this.labels,
    required this.value,
    required this.onChanged,
  });

  final List<T> options;
  final List<String> labels;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppTheme.bgVoid.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < options.length; i++)
            PressableScale(
              onTap: () => onChanged(options[i]),
              child: AnimatedContainer(
                duration: AppTheme.microMs,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: options[i] == value
                      ? AppTheme.accent
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  labels[i],
                  style: AppTheme.ui(
                    size: 13,
                    weight: options[i] == value
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: options[i] == value
                        ? AppTheme.onAccent
                        : AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Small outlined pill tag ("Recommended", "EXPERIMENTAL", "Most popular").
class PillTag extends StatelessWidget {
  const PillTag(this.text, {super.key, this.filled = false});

  final String text;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? AppTheme.accent : Colors.transparent,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.6)),
      ),
      child: Text(
        text,
        style: AppTheme.ui(
          size: 10,
          weight: FontWeight.w600,
          color: filled ? AppTheme.onAccent : AppTheme.accent,
        ),
      ),
    );
  }
}
