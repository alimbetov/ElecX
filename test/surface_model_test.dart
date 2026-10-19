import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/project_model.dart';
import 'package:elecx/src/domain/surface_navigation.dart';
import 'package:elecx/src/domain/surface_routing.dart';
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

    expect(
      RoomSurfaceResolver.openingFitsWall(opening: door, wall: wall),
      isTrue,
    );
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

  test('route point transfers from wall base to the same floor point', () {
    final controller = EditorController.demo();
    final room = controller.selectedSpace!;

    final mapped = SurfaceTransitionResolver.mapPoint(
      space: room,
      from: RoomSurfaceRef.wall(room.id, 0),
      point: const SurfacePointMm(1000, 0),
      to: RoomSurfaceRef.floor(room.id),
    );

    expect(mapped?.xMm, 1000);
    expect(mapped?.yMm, 0);
  });

  test('route point transfers between adjacent walls only at shared edge', () {
    final controller = EditorController.demo();
    final room = controller.selectedSpace!;
    final firstWall = controller.selectedWalls.first;

    final mapped = SurfaceTransitionResolver.mapPoint(
      space: room,
      from: firstWall.ref,
      point: SurfacePointMm(firstWall.lengthMm.round(), 1200),
      to: RoomSurfaceRef.wall(room.id, 1),
    );

    expect(mapped, isNotNull);
    expect(mapped?.xMm, 0);
    expect(mapped?.yMm, 1200);

    final invalid = SurfaceTransitionResolver.mapPoint(
      space: room,
      from: firstWall.ref,
      point: const SurfacePointMm(1000, 1200),
      to: RoomSurfaceRef.wall(room.id, 1),
    );
    expect(invalid, isNull);
  });

  test(
      'controller creates a new route segment when surface transition is valid',
      () {
    final controller = EditorController.demo();
    controller.setTool(EditorTool.cableRoute);
    controller.showWall(0);
    final wall = controller.activeWall!;
    controller.surfaceTap(SurfacePointMm(wall.lengthMm.round(), 1200));

    controller.nextWall();

    expect(controller.routeSegments, hasLength(2));
    expect(
      controller.routeSegments.last.surface,
      RoomSurfaceRef.wall('room-101', 1),
    );
    expect(controller.routeSegments.last.points.single.xMm, 0);
    expect(controller.routeSegments.last.points.single.yMm, 1200);
  });

  test('wall edges resolve to floor ceiling and adjacent walls', () {
    final controller = EditorController.demo();
    final room = controller.selectedSpace!;

    expect(
      SurfaceNavigationResolver.targetForWallEdge(
        space: room,
        wallIndex: 0,
        edge: WallNavigationEdge.floor,
      ),
      RoomSurfaceRef.floor(room.id),
    );
    expect(
      SurfaceNavigationResolver.targetForWallEdge(
        space: room,
        wallIndex: 0,
        edge: WallNavigationEdge.ceiling,
      ),
      RoomSurfaceRef.ceiling(room.id),
    );
    expect(
      SurfaceNavigationResolver.targetForWallEdge(
        space: room,
        wallIndex: 0,
        edge: WallNavigationEdge.start,
      ),
      RoomSurfaceRef.wall(room.id, 3),
    );
    expect(
      SurfaceNavigationResolver.targetForWallEdge(
        space: room,
        wallIndex: 0,
        edge: WallNavigationEdge.end,
      ),
      RoomSurfaceRef.wall(room.id, 1),
    );
  });

  test('edge navigation carries active cable route to adjacent wall', () {
    final controller = EditorController.demo();
    controller.setTool(EditorTool.cableRoute);
    controller.showWall(0);
    final wall = controller.activeWall!;

    controller.navigateWallEdge(
      WallNavigationEdge.end,
      SurfacePointMm(wall.lengthMm.round(), 1200),
    );

    expect(controller.activeSurface, RoomSurfaceRef.wall('room-101', 1));
    expect(controller.routeSegments, hasLength(2));
    expect(controller.routeSegments.first.points.single.yMm, 1200);
    expect(controller.routeSegments.last.points.single.xMm, 0);
    expect(controller.routeSegments.last.points.single.yMm, 1200);
  });

  test('edge navigation carries cable route from wall to floor', () {
    final controller = EditorController.demo();
    controller.setTool(EditorTool.cableRoute);
    controller.showWall(0);

    controller.navigateWallEdge(
      WallNavigationEdge.floor,
      const SurfacePointMm(1000, 0),
    );

    expect(controller.activeSurface, RoomSurfaceRef.floor('room-101'));
    expect(controller.routeSegments, hasLength(2));
    expect(controller.routeSegments.last.points.single.xMm, 1000);
    expect(controller.routeSegments.last.points.single.yMm, 0);
  });
}
