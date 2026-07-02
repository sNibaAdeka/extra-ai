import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../understanding/intent_pre_checker.dart';
import '../widgets/gradient_button.dart';

/// The input view: file-drop zone, prompt textarea, and the Analyze button.
/// Shows a live intent-clarity hint when the prompt is very broad, so the user
/// knows a terse prompt yields a broad result (expectation-setting, not a block).
class PromptInput extends StatefulWidget {
  const PromptInput({
    super.key,
    required this.onAnalyze,
    required this.onPickFiles,
    this.fileCount = 0,
  });

  /// Called with the current rough prompt when Analyze is pressed.
  final ValueChanged<String> onAnalyze;
  final VoidCallback onPickFiles;
  final int fileCount;

  @override
  State<PromptInput> createState() => _PromptInputState();
}

class _PromptInputState extends State<PromptInput> {
  final _controller = TextEditingController();
  IntentClarity _clarity = IntentClarity.clear;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged() {
    setState(() {
      _clarity = IntentPreChecker.check(_controller.text);
      if (_validationError != null && _controller.text.trim().isNotEmpty) {
        _validationError = null;
      }
    });
  }

  void _analyze() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() => _validationError = 'Write what you want to change first.');
      return;
    }
    widget.onAnalyze(text);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DropZone(fileCount: widget.fileCount, onTap: widget.onPickFiles),
        const SizedBox(height: 18),
        Text(
          'What do you want to fix?',
          style: AppTheme.ui(size: 12, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 8),
        _PromptField(controller: _controller, errorText: _validationError),
        if (_clarity == IntentClarity.veryVague) ...[
          const SizedBox(height: 10),
          _ClarityHint(),
        ],
        const Spacer(),
        GradientButton(
          label: 'Analyze',
          trailing: '→',
          onPressed: _analyze,
        ),
      ],
    );
  }
}

class _DropZone extends StatelessWidget {
  const _DropZone({required this.fileCount, required this.onTap});

  final int fileCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasFiles = fileCount > 0;
    return Semantics(
      button: true,
      label: hasFiles
          ? '$fileCount files loaded. Tap to change.'
          : 'Drop project files or click to browse',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: DottedBorderBox(
          child: SizedBox(
            height: 80,
            child: Center(
              child: hasFiles
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_outline,
                            size: 18, color: AppTheme.signalGreen),
                        const SizedBox(width: 8),
                        Text(
                          '$fileCount files loaded',
                          style: AppTheme.ui(
                            size: 13,
                            color: AppTheme.signalGreen,
                            weight: FontWeight.w500,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.upload_file_outlined,
                            size: 20,
                            color: AppTheme.textDim.withValues(alpha: 0.9)),
                        const SizedBox(height: 6),
                        Text(
                          'Drop project files or click to browse',
                          style: AppTheme.ui(
                              size: 12, color: AppTheme.textDim),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A dashed-border container (Flutter has no built-in dashed border).
class DottedBorderBox extends StatelessWidget {
  const DottedBorderBox({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(),
      child: Padding(padding: const EdgeInsets.all(1), child: child),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(12),
    );
    final path = Path()..addRRect(rrect);
    const dash = 6.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var dist = 0.0;
      while (dist < metric.length) {
        canvas.drawPath(
          metric.extractPath(dist, dist + dash),
          paint,
        );
        dist += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PromptField extends StatelessWidget {
  const _PromptField({required this.controller, this.errorText});

  final TextEditingController controller;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      minLines: 3,
      maxLines: 6,
      style: AppTheme.mono(size: 13),
      cursorColor: AppTheme.accent,
      decoration: InputDecoration(
        hintText: 'make the button prettier...',
        hintStyle: AppTheme.mono(size: 13, color: AppTheme.textDim),
        errorText: errorText,
        filled: true,
        fillColor: AppTheme.surface,
        contentPadding: const EdgeInsets.all(12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              BorderSide(color: AppTheme.accent.withValues(alpha: 0.6)),
        ),
      ),
    );
  }
}

class _ClarityHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.info_outline,
            size: 14, color: AppTheme.textSecondary.withValues(alpha: 0.9)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            "This is pretty broad — Extra AI will do its best, but a bit more detail helps.",
            style: AppTheme.ui(size: 11, color: AppTheme.textSecondary),
          ),
        ),
      ],
    );
  }
}
