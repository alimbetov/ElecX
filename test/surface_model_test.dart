import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/project_model.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rectangle room exposes four stable wall surfaces', () {
    final boundary = MmPolygon.rectangle(
      const MmPoint(1000, 2000),
      const MmPoint(5000, 5000),
    );
    final room = EngineeringSpace(
      id: 'room-a',
      name: 'Room A',
      type: SpaceType.room,
      boundary: boundary,
      referenceFrame: RoomReferenceFrame(origin: boundary.bounds.center),
    );

    final walls = RoomSurfaceResolver.walls(room);

    expect(walls, hasLength(4));
    expect(walls[0].ref.id, 'room-a:wall:0');
    expect(walls[0].lengthMm, 4000);
    expect(walls[1].lengthMm, 3000);
  });

  test('wall opening is validated against width and height', () {
    final controller = EditorController.demo();
    controller.showWall(0);
    final wall = controller.activeWall!;
    final door = controller.activeWallOpenings.single;

    expect(RoomSurfaceResolver.openingFitsWall(opening: door, wall: wall), isTrue);
  });

  test('surface navigator preserves selected room and switches wall', () {
    final controller = EditorController.demo();

    controller.showWall(0);
    expect(controller.viewMode, EditorViewMode.surface);
    expect(controller.activeSurface, RoomSurfaceRef.wall('room-101', 0));

    controller.nextWall();
    expect(controller.activeSurface, RoomSurfaceRef.wall('room-101', 1));

    controller.showFloor();
    expect(controller.activeSurface, RoomSurfaceRef.floor('room-101'));

    controller.showCeiling();
    expect(controller.activeSurface, RoomSurfaceRef.ceiling('room-101'));
  });

  test('wall-local coordinate maps back to plan edge', () {
    final controller = EditorController.demo();
    final wall = controller.selectedWalls.first;

    expect(
      RoomSurfaceResolver.wallLocalToPlan(wall, 1000),
      const MmPoint(2000, 1200),
    );
  });
}
