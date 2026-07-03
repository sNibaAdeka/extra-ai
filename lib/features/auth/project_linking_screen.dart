import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../services/project_context_service.dart';
import '../../services/project_detection_service.dart';
import '../../services/stack_detector.dart';
import '../../theme/app_theme.dart';
import '../../widgets/controls.dart';
import '../../widgets/gradient_button.dart';

/// Project linking — runs after registration, before onboarding. Auto-detects
/// projects from Cursor / VS Code / Claude Code and lets the user check which
/// to link. Each checked project becomes a ProjectContext (linkedAtOnboarding).
class ProjectLinkingScreen extends StatefulWidget {
  const ProjectLinkingScreen({
    super.key,
    required this.projects,
    required this.onContinue,
  });

  final ProjectContextService projects;
  final VoidCallback onContinue;

  @override
  State<ProjectLinkingScreen> createState() => _ProjectLinkingScreenState();
}

class _ProjectLinkingScreenState extends State<ProjectLinkingScreen> {
  bool _scanning = true;
  List<DetectedProject> _detected = const [];
  final Set<String> _checked = {};

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    final found = await ProjectDetectionService.detectAll();
    if (!mounted) return;
    setState(() {
      _detected = found;
      _scanning = false;
    });
  }

  Future<void> _browse() async {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Pick a project folder to link',
    );
    if (path == null) return;
    final stack = await _detectStack(path);
    if (!mounted) return;
    setState(() {
      if (!_detected.any((d) => d.path == path)) {
        _detected = [
          DetectedProject(path: path, source: 'Manual', stack: stack),
          ..._detected,
        ];
      }
      _checked.add(path);
    });
  }

  Future<void> _linkAndContinue() async {
    for (final d in _detected.where((d) => _checked.contains(d.path))) {
      await widget.projects.link(
        projectPath: d.path,
        fileNames: const [],
        detectedStack: d.stack,
        atOnboarding: true,
      );
    }
    widget.onContinue();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Link your projects',
                  style: AppTheme.display(size: 30, weight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(
                'Extra AI can detect projects you’re already working on. '
                'Pick which ones to link — you can add more anytime.',
                style: AppTheme.ui(size: 14, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 22),
              Flexible(child: _body()),
              const SizedBox(height: 20),
              Row(
                children: [
                  if (_detected.isNotEmpty)
                    GhostButton(
                      label: 'Browse for a folder',
                      height: 44,
                      onPressed: _browse,
                    ),
                  const Spacer(),
                  SizedBox(
                    width: 200,
                    child: GradientButton(
                      label: _checked.isEmpty ? 'Skip for now' : 'Continue',
                      onPressed: _linkAndContinue,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_scanning) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppTheme.accent),
            ),
            const SizedBox(width: 12),
            Text('Scanning for projects...',
                style: AppTheme.ui(size: 13, color: AppTheme.textDim)),
          ],
        ),
      );
    }

    if (_detected.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: AppTheme.card(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('No projects detected automatically',
                style: AppTheme.ui(size: 14, weight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(
              'You can link one manually, or skip and add projects later.',
              style: AppTheme.ui(size: 13, color: AppTheme.textDim),
            ),
            const SizedBox(height: 14),
            GhostButton(
              label: 'Browse for a folder',
              height: 42,
              onPressed: _browse,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      itemCount: _detected.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final d = _detected[i];
        final checked = _checked.contains(d.path);
        return PressableScale(
          onTap: () => setState(() =>
              checked ? _checked.remove(d.path) : _checked.add(d.path)),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: checked
                  ? AppTheme.accent.withValues(alpha: 0.08)
                  : AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: checked ? AppTheme.borderFocus : AppTheme.borderSubtle,
              ),
            ),
            child: Row(
              children: [
                _checkbox(checked),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(d.name,
                            style: AppTheme.ui(
                                size: 14, weight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        _stackBadge(d.stack),
                      ]),
                      const SizedBox(height: 2),
                      Text('${d.source} · ${d.path}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.ui(
                              size: 11, color: AppTheme.textDim)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _checkbox(bool checked) => Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: checked ? AppTheme.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: checked
              ? null
              : Border.all(color: AppTheme.textDim.withValues(alpha: 0.6)),
        ),
        child: checked
            ? const Icon(Icons.check, size: 14, color: AppTheme.onAccent)
            : null,
      );

  Widget _stackBadge(String stack) {
    if (stack == 'Unknown') return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Text(stack,
          style: AppTheme.ui(size: 10, color: AppTheme.textSecondary)),
    );
  }

  static Future<String> _detectStack(String path) async {
    try {
      final dir = Directory(path);
      final files = <String, String>{};
      await for (final e in dir.list(followLinks: false)) {
        if (e is! File) continue;
        final name = e.path.split('/').last;
        if (name == 'package.json' ||
            name.endsWith('.config.js') ||
            name.endsWith('.html')) {
          try {
            files[name] = await e.readAsString();
          } catch (_) {
            files[name] = '';
          }
        } else {
          files[name] = '';
        }
      }
      return StackDetector.detect(files);
    } catch (_) {
      return 'Unknown';
    }
  }
}
