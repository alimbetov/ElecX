import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'editable_spatial_canvas.dart' as editable;
import 'editor_controller.dart';
import 'room_world_overlay.dart';

/// Plan-canvas host that keeps direct editing intact and adds a high-level
/// navigation gesture: double-tap/click enters the currently selected room.
class SpatialCanvas extends StatefulWidget {
  const SpatialCanvas({required this.controller, super.key});

  final EditorController controller;

  @override
  State<SpatialCanvas> createState() => _SpatialCanvasState();
}

class _SpatialCanvasState extends State<SpatialCanvas> {
  Offset? _pointerDown;
  bool _pointerMoved = false;
  DateTime? _lastTapAt;
  Offset? _lastTapPosition;

  EditorController get controller => widget.controller;

  void _pointerDownHandler(PointerDownEvent event) {
    if (event.buttons != kPrimaryMouseButton) return;
    _pointerDown = event.localPosition;
    _pointerMoved = false;
  }

  void _pointerMoveHandler(PointerMoveEvent event) {
    final start = _pointerDown;
    if (start == null) return;
    if ((event.localPosition - start).distance > 8) {
      _pointerMoved = true;
    }
  }

  void _pointerUpHandler(PointerUpEvent event) {
    final start = _pointerDown;
    _pointerDown = null;
    if (start == null || _pointerMoved) return;
    if (controller.tool != EditorTool.select ||
        controller.selectedSpace == null ||
        controller.selectedOpening != null) {
      _lastTapAt = null;
      _lastTapPosition = null;
      return;
    }

    final now = DateTime.now();
    final previousAt = _lastTapAt;
    final previousPosition = _lastTapPosition;
    final isDoubleTap = previousAt != null &&
        now.difference(previousAt) <= const Duration(milliseconds: 360) &&
        previousPosition != null &&
        (event.localPosition - previousPosition).distance <= 24;

    if (isDoubleTap) {
      _lastTapAt = null;
      _lastTapPosition = null;
      showRoomWorldOverlay(context, controller);
      return;
    }

    _lastTapAt = now;
    _lastTapPosition = event.localPosition;
  }

  @override
  Widget build(BuildContext context) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _pointerDownHandler,
        onPointerMove: _pointerMoveHandler,
        onPointerUp: _pointerUpHandler,
        onPointerCancel: (_) {
          _pointerDown = null;
          _pointerMoved = false;
        },
        child: editable.SpatialCanvas(controller: controller),
      );
}
