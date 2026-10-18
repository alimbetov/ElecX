import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'editor_controller.dart';

/// Desktop-first keyboard layer for the spatial editor.
///
/// Shortcuts invoke the same controller operations as toolbar actions so input
/// devices never create a second editing model.
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
        const SingleActivator(LogicalKeyboardKey.equal): controller.zoomIn,
        const SingleActivator(LogicalKeyboardKey.numpadAdd): controller.zoomIn,
        const SingleActivator(LogicalKeyboardKey.minus): controller.zoomOut,
        const SingleActivator(LogicalKeyboardKey.numpadSubtract):
            controller.zoomOut,
        const SingleActivator(LogicalKeyboardKey.digit0): controller.resetZoom,
        const SingleActivator(LogicalKeyboardKey.numpad0): controller.resetZoom,
      },
      child: Focus(autofocus: true, child: child),
    );
  }
}
