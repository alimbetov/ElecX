import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_viewport_commands.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('viewport command revision advances and stores latest command', () {
    final controller = EditorController.demo();
    addTearDown(controller.dispose);

    expect(controller.viewportCommandRevision, 0);
    expect(controller.viewportCommand, isNull);

    controller.requestViewportCommand(EditorViewportCommand.zoomIn);

    expect(controller.viewportCommandRevision, 1);
    expect(controller.viewportCommand, EditorViewportCommand.zoomIn);

    controller.requestViewportCommand(EditorViewportCommand.reset);

    expect(controller.viewportCommandRevision, 2);
    expect(controller.viewportCommand, EditorViewportCommand.reset);
  });
}
