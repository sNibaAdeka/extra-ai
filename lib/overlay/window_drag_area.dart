import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// Makes its whole subtree a drag handle for the current OS window.
///
/// `windowManager.startDragging()` silently fails inside a
/// desktop_multi_window sub-engine (the native mouse-down event is gone by
/// the time the method-channel call lands), so the overlay island could not
/// be moved at all. This widget moves the window manually instead —
/// getPosition/setPosition demonstrably work in the overlay engine (they
/// already power setSize/center/hide).
///
/// Interactive children keep working: taps never reach the pan recognizer,
/// and deeper drag recognizers (text selection, scrollables) win the gesture
/// arena over this ancestor.
class WindowDragArea extends StatefulWidget {
  const WindowDragArea({super.key, required this.child});

  final Widget child;

  @override
  State<WindowDragArea> createState() => _WindowDragAreaState();
}

class _WindowDragAreaState extends State<WindowDragArea> {
  Offset? _windowPos;
  bool _moving = false;

  Future<void> _onPanStart(DragStartDetails details) async {
    _windowPos = await windowManager.getPosition();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final pos = _windowPos;
    if (pos == null) return;
    _windowPos = pos + details.delta;
    // Coalesce: never queue a second native call while one is in flight —
    // _windowPos keeps accumulating, so the next call catches up.
    if (_moving) return;
    _moving = true;
    windowManager.setPosition(_windowPos!).whenComplete(() => _moving = false);
  }

  void _onPanEnd(DragEndDetails details) {
    final pos = _windowPos;
    if (pos != null) windowManager.setPosition(pos);
    _windowPos = null;
  }

  @override
  Widget build(BuildContext context) {
    // RawGestureDetector with a high-slop pan: a mouse pan normally claims
    // the arena after ~2px, which would steal ordinary clicks (trackpads
    // drift a pixel or two) from buttons inside the island. Requiring a
    // deliberate 10px drag keeps every tappable child working.
    return RawGestureDetector(
      behavior: HitTestBehavior.translucent,
      gestures: {
        _DeliberatePanRecognizer:
            GestureRecognizerFactoryWithHandlers<_DeliberatePanRecognizer>(
              () => _DeliberatePanRecognizer(debugOwner: this),
              (recognizer) => recognizer
                ..onStart = _onPanStart
                ..onUpdate = _onPanUpdate
                ..onEnd = _onPanEnd,
            ),
      },
      child: widget.child,
    );
  }
}

/// Pan that only wins the gesture arena after a clearly intentional drag.
class _DeliberatePanRecognizer extends PanGestureRecognizer {
  _DeliberatePanRecognizer({super.debugOwner});

  static const double _slop = 10;

  @override
  bool hasSufficientGlobalDistanceToAccept(
    PointerDeviceKind pointerDeviceKind,
    double? deviceTouchSlop,
  ) => globalDistanceMoved.abs() > _slop;
}
