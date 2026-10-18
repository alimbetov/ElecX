import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'editor_controller.dart';
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

  void _nudgeCursor(int dx, int dy, {int multiplier = 1}) {
    if (controller.p2.placementType == null) return;
    controller.placementCursor.nudgeGrid(
      dxSteps: dx,
      dySteps: dy,
      multiplier: multiplier,
    );
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
          if (controller.p2.placementType != null) {
            controller.placementCursor.cancel();
          } else {
            controller.setTool(EditorTool.select);
          }
        },
        const SingleActivator(LogicalKeyboardKey.enter): () {
          if (controller.p2.placementType != null) {
            controller.placementCursor.confirm();
          }
        },
        const SingleActivator(LogicalKeyboardKey.numpadEnter): () {
          if (controller.p2.placementType != null) {
            controller.placementCursor.confirm();
          }
        },
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            _nudgeCursor(-1, 0),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            _nudgeCursor(1, 0),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
            _nudgeCursor(0, 1),
        const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
            _nudgeCursor(0, -1),
        const SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true): () =>
            _nudgeCursor(-1, 0, multiplier: 10),
        const SingleActivator(LogicalKeyboardKey.arrowRight, shift: true): () =>
            _nudgeCursor(1, 0, multiplier: 10),
        const SingleActivator(LogicalKeyboardKey.arrowUp, shift: true): () =>
            _nudgeCursor(0, 1, multiplier: 10),
        const SingleActivator(LogicalKeyboardKey.arrowDown, shift: true): () =>
            _nudgeCursor(0, -1, multiplier: 10),
        const SingleActivator(LogicalKeyboardKey.delete): () {
          if (controller.selectedOpening != null) {
            controller.deleteSelectedOpening();
          }
        },
        const SingleActivator(LogicalKeyboardKey.backspace): () {
          if (controller.selectedOpening != null) {
            controller.deleteSelectedOpening();
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
