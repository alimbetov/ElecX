import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:elecx/src/features/editor/engineering_placement_cursor_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('placement cursor nudges and confirms a component on active wall', () {
    final controller = EditorController.demo();
    addTearDown(controller.dispose);
    controller.showWall(0);
    controller.p2.setPlacementType(ElectricalComponentType.socketOutlet);

    final initial = controller.placementCursor.ensure();
    expect(initial, isNotNull);
    expect(initial!.position.xMm, 2100);
    expect(initial.position.yMm, 1500);

    expect(
      controller.placementCursor.nudgeGrid(dxSteps: 1, dySteps: -1),
      isTrue,
    );
    final moved = controller.placementCursor.state!;
    expect(moved.position.xMm, 2200);
    expect(moved.position.yMm, 1400);

    expect(controller.placementCursor.confirm(), isTrue);
    expect(controller.p2.components, hasLength(1));
    expect(controller.p2.components.single.position.xMm, 2200);
    expect(controller.p2.components.single.position.yMm, 1400);
    expect(controller.p2.components.single.surface, controller.activeSurface);
    expect(controller.p2.placementType, isNull);
    expect(controller.placementCursor.state, isNull);
  });
}
