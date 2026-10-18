import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'editor_controller.dart';
import 'editor_viewport_commands.dart';

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
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            controller.setTool(EditorTool.select),
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
