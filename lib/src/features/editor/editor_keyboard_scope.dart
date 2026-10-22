import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../domain/geometry.dart';
import '../../domain/surfaces.dart';
import '../../engine/editor_layers.dart';
import 'cable_edit_access.dart';
import 'component_transform_session.dart';
import 'editor_controller.dart';
import 'editor_document_history.dart';
import 'editor_interaction_policy.dart';
import 'editor_p2_session.dart';
import 'editor_viewport_commands.dart';
import 'engineering_placement_cursor_session.dart';
import 'manual_cable_draft_persistence.dart';
import 'route_selection_session.dart';

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
    } else if (controller.tool == EditorTool.cableRoute &&
        controller.routeSegments.isNotEmpty) {
      controller.cancelManualCableDraft();
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
    } else if (controller.tool == EditorTool.cableRoute &&
        controller.routeSegments.isNotEmpty) {
      controller.finishManualCableDraft();
    }
  }

  void _cycleSceneSelection({required bool reverse}) {
    if (_persistentEditActive) return;
    final surface = controller.activeSurface;
    if (surface == null) return;
    final items = <({String id, bool route})>[];
    if (controller.p2.layers.isVisible(EditorLayerId.electrical)) {
      for (final component in controller.p2.components) {
        if (component.surface == surface) {
          items.add((id: component.id, route: false));
        }
      }
    }
    if (controller.p2.layers.isVisible(EditorLayerId.cableRoutes)) {
      for (final route in controller.p2.routes) {
        if (route.segments.any((segment) => segment.surface == surface)) {
          items.add((id: route.id, route: true));
        }
      }
    }
    if (items.isEmpty) return;
    final selectedRouteId = controller.routeSelection.selectedRouteId;
    final selectedComponentId = controller.p2.selection.primaryId;
    var currentIndex = -1;
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      final selected = item.route
          ? item.id == selectedRouteId
          : item.id == selectedComponentId;
      if (selected) {
        currentIndex = index;
        break;
      }
    }
    final nextIndex = currentIndex < 0
        ? (reverse ? items.length - 1 : 0)
        : (currentIndex + (reverse ? -1 : 1)) % items.length;
    final normalizedIndex = nextIndex < 0 ? items.length - 1 : nextIndex;
    final next = items[normalizedIndex];
    if (next.route) {
      controller.p2.clearSelection();
      controller.routeSelection.select(next.id);
    } else {
      controller.routeSelection.clear();
      controller.p2.select(next.id);
    }
  }

  void _undo() {
    if (_persistentEditActive) return;
    controller.documentHistory.undo();
  }

  void _redo() {
    if (_persistentEditActive) return;
    controller.documentHistory.redo();
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
        // Keep plain Tab/Shift+Tab available to Flutter's focus traversal so
        // AppBar, navigator and inspector controls remain keyboard reachable.
        // Scene-object cycling is an explicit CAD shortcut instead of a global
        // accessibility override.
        const SingleActivator(LogicalKeyboardKey.tab, control: true): () =>
            _cycleSceneSelection(reverse: false),
        const SingleActivator(
          LogicalKeyboardKey.tab,
          control: true,
          shift: true,
        ): () => _cycleSceneSelection(reverse: true),
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
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true):
            _redo,
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
