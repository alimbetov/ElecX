import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../domain/geometry.dart';
import '../../domain/surfaces.dart';
import 'editor_controller.dart';
import 'editor_interaction_policy.dart';
import 'editor_p2_session.dart';
import 'editor_viewport_commands.dart';
import 'engineering_placement_cursor_session.dart';

/// Desktop-first keyboard layer for the spatial editor.
///
/// Shortcuts invoke the same editor/controller operations as toolbar actions.
/// Viewport shortcuts are emitted as camera commands and consumed by the
/// active Plan/Surface canvas, so keyboard zoom controls the real WorldCamera.
class EditorKeyboardScope extends StatelessWidget {
  const EditorKeyboardScope({
    required this.controller,
    required this.child,
    super.key,
  });

  final EditorController controller;
  final Widget child;

  bool _selectedPointIsUsable(SurfacePointMm point) {
    final component = controller.p2.selectedComponent;
    final surface = controller.activeSurface;
    final space = controller.selectedSpace;
    if (component == null ||
        surface == null ||
        space == null ||
        component.surface != surface ||
        point.xMm < 0 ||
        point.yMm < 0) {
      return false;
    }
    if (surface.type == SurfacePlaneType.wall) {
      final wall = controller.activeWall;
      return wall != null && wall.profile.containsPoint(point.xMm, point.yMm);
    }
    final bounds = space.boundary.bounds;
    if (point.xMm > bounds.width || point.yMm > bounds.height) {
      return false;
    }
    return space.boundary.contains(
      MmPoint(
        point.xMm + bounds.left,
        point.yMm + bounds.bottom,
      ),
    );
  }

  void _nudgeActive(int dx, int dy, {bool coarse = false}) {
    final policy = EditorInteractionPolicy.forMode(
      EditorInputMode.mouseKeyboard,
    );
    final step = policy.nudgeStepMm(coarse: coarse);
    if (controller.placementCursor.active) {
      controller.placementCursor.nudge(
        dxMm: dx * step,
        dyMm: dy * step,
      );
      return;
    }

    final component = controller.p2.selectedComponent;
    if (component == null) {
      return;
    }
    final next = SurfacePointMm(
      component.position.xMm + dx * step,
      component.position.yMm + dy * step,
    );
    if (_selectedPointIsUsable(next)) {
      controller.p2.moveSelectedComponent(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyV): () =>
            controller.setTool(EditorTool.select),
        const SingleActivator(LogicalKeyboardKey.keyR): () {
          if (controller.viewMode == EditorViewMode.plan) {
            controller.setTool(EditorTool.roomRectangle);
          }
        },
        const SingleActivator(LogicalKeyboardKey.keyG): () =>
            controller.setTool(EditorTool.guide),
        const SingleActivator(LogicalKeyboardKey.keyC): () =>
            controller.setTool(EditorTool.cableRoute),
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (controller.placementCursor.active) {
            controller.placementCursor.cancel();
          } else {
            controller.setTool(EditorTool.select);
          }
        },
        const SingleActivator(LogicalKeyboardKey.enter): () {
          if (controller.placementCursor.active) {
            controller.placementCursor.confirm();
          }
        },
        const SingleActivator(LogicalKeyboardKey.numpadEnter): () {
          if (controller.placementCursor.active) {
            controller.placementCursor.confirm();
          }
        },
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            _nudgeActive(-1, 0),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            _nudgeActive(1, 0),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
            _nudgeActive(0, 1),
        const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
            _nudgeActive(0, -1),
        const SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true): () =>
            _nudgeActive(-1, 0, coarse: true),
        const SingleActivator(LogicalKeyboardKey.arrowRight, shift: true): () =>
            _nudgeActive(1, 0, coarse: true),
        const SingleActivator(LogicalKeyboardKey.arrowUp, shift: true): () =>
            _nudgeActive(0, 1, coarse: true),
        const SingleActivator(LogicalKeyboardKey.arrowDown, shift: true): () =>
            _nudgeActive(0, -1, coarse: true),
        const SingleActivator(LogicalKeyboardKey.delete): () {
          if (controller.selectedOpening != null) {
            controller.deleteSelectedOpening();
          } else {
            controller.p2.deleteSelection();
          }
        },
        const SingleActivator(LogicalKeyboardKey.backspace): () {
          if (controller.selectedOpening != null) {
            controller.deleteSelectedOpening();
          } else {
            controller.p2.deleteSelection();
          }
        },
        const SingleActivator(LogicalKeyboardKey.equal): () =>
            controller.requestViewportCommand(EditorViewportCommand.zoomIn),
        const SingleActivator(LogicalKeyboardKey.numpadAdd): () =>
            controller.requestViewportCommand(EditorViewportCommand.zoomIn),
        const SingleActivator(LogicalKeyboardKey.minus): () =>
            controller.requestViewportCommand(EditorViewportCommand.zoomOut),
        const SingleActivator(LogicalKeyboardKey.numpadSubtract): () =>
            controller.requestViewportCommand(EditorViewportCommand.zoomOut),
        const SingleActivator(LogicalKeyboardKey.digit0): () =>
            controller.requestViewportCommand(EditorViewportCommand.reset),
        const SingleActivator(LogicalKeyboardKey.numpad0): () =>
            controller.requestViewportCommand(EditorViewportCommand.reset),
      },
      child: Focus(autofocus: true, child: child),
    );
  }
}
