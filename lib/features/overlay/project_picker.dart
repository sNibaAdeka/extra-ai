import 'package:flutter/material.dart';

import '../../models/project_context.dart';
import '../../theme/app_theme.dart';
import '../../widgets/controls.dart';

/// "Working on: [Project ▾]" strip at the top of the overlay composer.
/// Three states per the spec:
///  - many linked  → a dropdown to switch, plus "+ Add new project"
///  - one linked    → a static non-interactive label (no pointless dropdown)
///  - none linked   → "No project selected" + a "Link a project" action
class ProjectPicker extends StatelessWidget {
  const ProjectPicker({
    super.key,
    required this.projects,
    required this.selected,
    required this.onSelect,
    required this.onAddProject,
  });

  final List<ProjectContext> projects;
  final ProjectContext? selected;
  final ValueChanged<String> onSelect; // pathHash
  final VoidCallback onAddProject;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.borderSubtle)),
      ),
      child: Row(
        children: [
          Text('Working on: ',
              style: AppTheme.ui(size: 12, color: AppTheme.textDim)),
          Expanded(child: _body(context)),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (projects.isEmpty) {
      return Row(children: [
        Text('No project selected',
            style: AppTheme.ui(size: 12, color: AppTheme.textSecondary)),
        const SizedBox(width: 8),
        PressableScale(
          onTap: onAddProject,
          child: Text('Link a project',
              style: AppTheme.ui(
                  size: 12,
                  weight: FontWeight.w600,
                  color: AppTheme.accent)),
        ),
      ]);
    }

    if (projects.length == 1) {
      // One project — a static label, no dropdown to click through.
      return Text(projects.first.displayName,
          style: AppTheme.ui(size: 12, weight: FontWeight.w600));
    }

    final current = selected ?? projects.first;
    return Align(
      alignment: Alignment.centerLeft,
      child: PopupMenuButton<String>(
        color: AppTheme.surfaceHigh,
        position: PopupMenuPosition.under,
        onSelected: (value) {
          if (value == '__add__') {
            onAddProject();
          } else {
            onSelect(value);
          }
        },
        itemBuilder: (context) => [
          for (final p in projects)
            PopupMenuItem(
              value: p.pathHash,
              child: Text(p.displayName,
                  style: AppTheme.ui(size: 13, color: AppTheme.textPrimary)),
            ),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: '__add__',
            child: Text('+ Add new project',
                style: AppTheme.ui(size: 13, color: AppTheme.accent)),
          ),
        ],
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(current.displayName,
                style: AppTheme.ui(size: 12, weight: FontWeight.w600)),
            const Icon(Icons.keyboard_arrow_down,
                size: 16, color: AppTheme.textDim),
          ],
        ),
      ),
    );
  }
}
