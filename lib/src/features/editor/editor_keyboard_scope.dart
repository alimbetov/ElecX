import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../domain/geometry.dart';
import '../../domain/surfaces.dart';
import 'cable_edit_access.dart';
import 'component_transform_session.dart';
import 'editor_controller.dart';
import 'editor_interaction_policy.dart';
import 'editor_p2_session.dart';
import 'editor_viewport_commands.dart';
import 'engineering_placement_cursor_session.dart';

/// Desktop-first keyboard layer for the spatial editor.
///
/// Shortcuts invoke the same transactional editor operations as pointer/touch
/// adapters. Viewport shortcuts are emitted as camera commands and consumed by
/// the active Plan/Surface canvas.
class EditorKeyboardScope extends StatelessWidget {
  const EditorKeyboardScope({
    required this.controller,
    required this.child,
    super.key,
  });

  final EditorController controller;
  final Widget child;

  bool get _persistentEditActive =>
      controller.cableEndpointTransform.active ||
      controller.cableRouteEdit.active ||
      controller.componentTransform.active ||
      controller.placementCursor.active;

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
      MmPoint(point.xMm + bounds.left, point.yMm + bounds.bottom),
    );
  }

  void _nudgeActive(int dx, int dy, {bool coarse = false}) {
    final policy = EditorInteractionPolicy.forMode(
      EditorInputMode.mouseKeyboard,
    );
    final step = policy.nudgeStepMm(coarse: coarse);
    if (controller.placementCursor.active) {
      controller.placementCursor.nudge(dxMm: dx * step, dyMm: dy * step);
      return;
    }

    if (controller.p2.selectedComponent == null) return;
    final transform = controller.componentTransform;
    if (!transform.begin()) return;
    final valid = transform.nudge(
      dxMm: dx * step,
      dyMm: dy * step,
      validator: (_, point) => _selectedPointIsUsable(point),
    );
    if (valid) {
      transform.commit();
    } else {
      transform.cancel();
    }
  }

  void _cancelActiveEdit() {
    if (controller.cableEndpointTransform.active) {
      controller.cableEndpointTransform.cancel();
    } else if (controller.cableRouteEdit.active) {
      controller.cableRouteEdit.cancel();
    } else if (controller.componentTransform.active) {
      controller.componentTransform.cancel();
    } else if (controller.placementCursor.active) {
      controller.placementCursor.cancel();
    } else {
      controller.setTool(EditorTool.select);
    }
    controller.requestEditCancellation();
  }

  void _commitActiveEdit() {
    if (controller.cableEndpointTransform.active) {
      controller.cableEndpointTransform.commit();
    } else if (controller.cableRouteEdit.active) {
      controller.cableRouteEdit.commit();
    } else if (controller.componentTransform.active) {
      controller.componentTransform.commit();
    } else if (controller.placementCursor.active) {
      controller.placementCursor.confirm();
    }
  }

  void _undo() {
    if (_persistentEditActive) return;
    controller.p2.undo();
  }

  void _redo() {
    if (_persistentEditActive) return;
    controller.p2.redo();
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
        const SingleActivator(LogicalKeyboardKey.escape): _cancelActiveEdit,
        const SingleActivator(LogicalKeyboardKey.enter): _commitActiveEdit,
        const SingleActivator(LogicalKeyboardKey.numpadEnter):
            _commitActiveEdit,
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): _undo,
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): _undo,
        const SingleActivator(
          LogicalKeyboardKey.keyZ,
          control: true,
          shift: true,
        ): _redo,
        const SingleActivator(
          LogicalKeyboardKey.keyZ,
          meta: true,
          shift: true,
        ): _redo,
        const SingleActivator(LogicalKeyboardKey.keyY, control: true): _redo,
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
          if (_persistentEditActive) return;
          if (controller.selectedOpening != null) {
            controller.deleteSelectedOpening();
          } else {
            controller.p2.deleteSelection();
          }
        },
        const SingleActivator(LogicalKeyboardKey.backspace): () {
          if (_persistentEditActive) return;
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
