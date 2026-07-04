import 'package:flutter/material.dart';

import '../../services/template_bindings_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/controls.dart';
import '../../widgets/hotkey_capture.dart';

/// Screen 6 — Quick Templates: bind a hotkey to a fixed analysis type.
class QuickTemplatesScreen extends StatefulWidget {
  const QuickTemplatesScreen({
    super.key,
    required this.bindings,
    required this.onBindingsChanged,
  });

  final TemplateBindingsService bindings;

  /// Called after any bind/remove so main.dart can re-register hotkeys.
  final VoidCallback onBindingsChanged;

  @override
  State<QuickTemplatesScreen> createState() => _QuickTemplatesScreenState();
}

class _QuickTemplatesScreenState extends State<QuickTemplatesScreen> {
  /// Template currently in hotkey-capture mode (inline panel, not a screen).
  QuickTemplate? _capturing;

  Future<void> _bind(String combo) async {
    final template = _capturing!;
    await widget.bindings.bind(template.id, combo);
    setState(() => _capturing = null);
    widget.onBindingsChanged();
  }

  @override
  Widget build(BuildContext context) {
    final bindings = widget.bindings.all;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt, size: 20, color: AppTheme.accent),
              const SizedBox(width: 8),
              Text(
                'Quick Templates',
                style: AppTheme.display(size: 24, weight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Bind a hotkey to a fixed analysis type. Press anywhere, get the '
            'same kind of check every time.',
            style: AppTheme.ui(size: 14, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 24),
          Text('TEMPLATES', style: AppTheme.sectionLabel()),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final t in kQuickTemplates)
                SelectChip(
                  label: t.label,
                  leading: Icon(
                    t.icon,
                    size: 14,
                    color: _capturing?.id == t.id
                        ? AppTheme.onAccent
                        : AppTheme.textSecondary,
                  ),
                  selected: _capturing?.id == t.id,
                  onTap: () => setState(() => _capturing = t),
                ),
            ],
          ),
          if (_capturing != null) ...[
            const SizedBox(height: 14),
            HotkeyCapture(
              prompt:
                  "Press a key combination to bind to '${_capturing!.label}'",
              onCaptured: _bind,
            ),
          ],
          const SizedBox(height: 28),
          Text('BINDINGS', style: AppTheme.sectionLabel()),
          const SizedBox(height: 10),
          if (bindings.isEmpty)
            _emptyState()
          else
            for (final entry in bindings.entries)
              _BindingRow(
                combo: entry.value,
                template: kQuickTemplates.firstWhere(
                  (t) => t.id == entry.key,
                  orElse: () => kQuickTemplates.first,
                ),
                onEdit: () => setState(
                  () => _capturing = kQuickTemplates.firstWhere(
                    (t) => t.id == entry.key,
                    orElse: () => kQuickTemplates.first,
                  ),
                ),
                onRemove: () async {
                  await widget.bindings.remove(entry.key);
                  setState(() {});
                  widget.onBindingsChanged();
                },
              ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No quick templates yet',
            style: AppTheme.display(size: 20, weight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Pick a template above, or bind ',
                style: AppTheme.ui(size: 13, color: AppTheme.textSecondary),
              ),
              const KeycapBadge(keys: ['⌘', '⇧', '1'], size: KeycapSize.small),
              Text(
                " → 'Security check'. Then press it anywhere to run that "
                'check instantly.',
                style: AppTheme.ui(size: 13, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BindingRow extends StatelessWidget {
  const _BindingRow({
    required this.combo,
    required this.template,
    required this.onEdit,
    required this.onRemove,
  });

  final String combo;
  final QuickTemplate template;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: AppTheme.card(radius: 10),
      child: Row(
        children: [
          KeycapBadge.combo(combo, size: KeycapSize.small),
          const SizedBox(width: 12),
          Icon(template.icon, size: 15, color: AppTheme.textSecondary),
          const SizedBox(width: 6),
          Text(template.label, style: AppTheme.ui(size: 13)),
          const Spacer(),
          PressableScale(
            onTap: onEdit,
            child: Text(
              'Edit',
              style: AppTheme.ui(size: 12, color: AppTheme.textDim),
            ),
          ),
          const SizedBox(width: 14),
          PressableScale(
            onTap: onRemove,
            child: Text(
              'Remove',
              style: AppTheme.ui(size: 12, color: AppTheme.textDim),
            ),
          ),
        ],
      ),
    );
  }
}
