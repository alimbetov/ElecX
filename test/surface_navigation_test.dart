import 'package:elecx/src/domain/surface_navigation.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('floor boundary resolves to the corresponding wall surface', () {
    final controller = EditorController.demo();
    final room = controller.selectedSpace!;

    final target = SurfaceNavigationResolver.targetForHorizontalBoundary(
      space: room,
      boundaryEdgeIndex: 2,
    );

    expect(target, RoomSurfaceRef.wall(room.id, 2));
  });

  test('cable route can continue from floor boundary onto wall', () {
    final controller = EditorController.demo();
    controller.setTool(EditorTool.cableRoute);
    controller.showFloor();

    controller.navigateHorizontalBoundary(
      0,
      const SurfacePointMm(1000, 0),
    );

    expect(controller.activeSurface, RoomSurfaceRef.wall('room-101', 0));
    expect(controller.routeSegments, hasLength(2));
    expect(controller.routeSegments.first.points.single.xMm, 1000);
    expect(controller.routeSegments.first.points.single.yMm, 0);
    expect(controller.routeSegments.last.points.single.xMm, 1000);
    expect(controller.routeSegments.last.points.single.yMm, 0);
  });
}
