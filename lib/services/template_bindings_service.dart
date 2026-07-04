// PRIVACY NOTE: template bindings are stored locally via Hive only.

import 'package:hive/hive.dart';

/// One quick template: a fixed analysis type the user can bind to a hotkey.
class QuickTemplate {
  const QuickTemplate({
    required this.id,
    required this.icon,
    required this.label,
    required this.cannedPrompt,
  });

  final String id;
  final String icon; // emoji glyph per the spec chips
  final String label;

  /// The rough prompt injected when the binding fires.
  final String cannedPrompt;
}

/// The five fixed MVP templates (Screen 6).
const List<QuickTemplate> kQuickTemplates = [
  QuickTemplate(
    id: 'responsive',
    icon: '🌐',
    label: 'Fix responsive',
    cannedPrompt: 'Fix the responsive layout issues on this screen',
  ),
  QuickTemplate(
    id: 'copy',
    icon: '📝',
    label: 'Improve copy',
    cannedPrompt: 'Improve the UI copy on this screen',
  ),
  QuickTemplate(
    id: 'security',
    icon: '🔒',
    label: 'Security check',
    cannedPrompt: 'Run a security check on this code',
  ),
  QuickTemplate(
    id: 'accessibility',
    icon: '♿',
    label: 'Accessibility fix',
    cannedPrompt: 'Find and fix accessibility problems on this screen',
  ),
  QuickTemplate(
    id: 'visual',
    icon: '🎨',
    label: 'Polish visual',
    cannedPrompt: 'Polish the visual design of this screen',
  ),
];

/// Persisted hotkey bindings: templateId → display combo (e.g. "⌘⇧1").
class TemplateBindingsService {
  TemplateBindingsService(this._box);

  static const String boxName = 'template_bindings';
  final Box _box;

  Map<String, String> get all => {
    for (final k in _box.keys) k as String: _box.get(k) as String,
  };

  String? comboFor(String templateId) => _box.get(templateId) as String?;

  Future<void> bind(String templateId, String combo) =>
      _box.put(templateId, combo);

  Future<void> remove(String templateId) => _box.delete(templateId);
}
