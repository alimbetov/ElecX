import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/engineering_placement_cursor.dart';
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
    expect(initial!.componentTypeId, 'power.socket.general');
    expect(initial.position.xMm, 2100);
    expect(initial.position.yMm, 300);
    expect(initial.snapKind, PlacementCursorSnapKind.installationGuide);
    expect(initial.snapLabel, 'SOCKET-GENERAL 300');

    expect(
      controller.placementCursor.nudgeGrid(dxSteps: 1, dySteps: -1),
      isTrue,
    );
    final moved = controller.placementCursor.state!;
    expect(moved.position.xMm, 2200);
    expect(moved.position.yMm, 200);

    expect(controller.placementCursor.confirm(), isTrue);
    expect(controller.p2.components, hasLength(1));
    expect(controller.p2.components.single.componentTypeId, 'power.socket.general');
    expect(controller.p2.components.single.position.xMm, 2200);
    expect(controller.p2.components.single.position.yMm, 200);
    expect(controller.p2.components.single.surface, controller.activeSurface);
    expect(controller.p2.placementType, isNull);
    expect(controller.placementCursor.state, isNull);
  });

  test('catalog rejects socket placement on ceiling', () {
    final controller = EditorController.demo();
    addTearDown(controller.dispose);
    controller.showCeiling();
    controller.p2.setPlacementType(ElectricalComponentType.socketOutlet);

    final cursor = controller.placementCursor.ensure();
    expect(cursor, isNotNull);
    expect(cursor!.isValid, isFalse);
    expect(controller.placementCursor.confirm(), isFalse);
    expect(controller.p2.components, isEmpty);
  });

  test('catalog allows lighting point on ceiling', () {
    final controller = EditorController.demo();
    addTearDown(controller.dispose);
    controller.showCeiling();
    controller.p2.setPlacementType(ElectricalComponentType.lightingPoint);

    final cursor = controller.placementCursor.ensure();
    expect(cursor, isNotNull);
    expect(cursor!.isValid, isTrue);
    expect(controller.placementCursor.confirm(), isTrue);
    expect(
      controller.p2.components.single.componentTypeId,
      'lighting.luminaire.general',
    );
  });

  test('CCTV placement keeps canonical catalog componentTypeId', () {
    final controller = EditorController.demo();
    addTearDown(controller.dispose);
    controller.showWall(0);

    controller.placementCursor.beginCatalogPlacement('cctv.camera.poe');
    final cursor = controller.placementCursor.ensure();
    expect(cursor, isNotNull);
    expect(cursor!.componentTypeId, 'cctv.camera.poe');
    expect(cursor.isValid, isTrue);

    expect(controller.placementCursor.confirm(), isTrue);
    final camera = controller.p2.components.single;
    expect(camera.componentTypeId, 'cctv.camera.poe');
    expect(camera.type, ElectricalComponentType.custom);
    expect(camera.label, contains('IP-камера PoE'));
  });

  test('repeat placement keeps the catalog placement session active', () {
    final controller = EditorController.demo();
    addTearDown(controller.dispose);
    controller.showWall(0);

    controller.placementCursor.beginCatalogPlacement(
      'power.socket.general',
      repeat: true,
    );
    expect(controller.placementCursor.repeatPlacement, isTrue);
    expect(controller.placementCursor.active, isTrue);

    expect(controller.placementCursor.confirm(), isTrue);
    expect(controller.p2.components, hasLength(1));
    expect(controller.placementCursor.active, isTrue);
    expect(controller.placementCursor.state, isNotNull);

    expect(controller.placementCursor.nudge(dxMm: 500, dyMm: 0), isTrue);
    expect(controller.placementCursor.confirm(), isTrue);
    expect(controller.p2.components, hasLength(2));
    expect(
      controller.p2.components.every(
        (component) => component.componentTypeId == 'power.socket.general',
      ),
      isTrue,
    );

    controller.placementCursor.cancel();
    expect(controller.placementCursor.active, isFalse);
    expect(controller.placementCursor.repeatPlacement, isFalse);
  });
}
