import 'package:elecx/src/domain/adjacent_room.dart';
import 'package:elecx/src/domain/project_model.dart';
import 'package:elecx/src/domain/surface_transition_graph.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('wall route point exposes floor continuation at wall/floor edge', () {
    final controller = EditorController.demo();
    final room = controller.selectedSpace!;
    final candidates = SurfaceTransitionGraph.candidates(
      level: controller.level,
      fromSpace: room,
      fromSurface: RoomSurfaceRef.wall(room.id, 0),
      point: const SurfacePointMm(1000, 0),
    );

    final floor = candidates.singleWhere(
      (candidate) => candidate.toSurface == RoomSurfaceRef.floor(room.id),
    );
    expect(floor.kind, SurfaceTransitionKind.wallToFloor);
    expect(floor.requiresPenetration, isFalse);
  });

  test('wall corner exposes adjacent wall continuation at same height', () {
    final controller = EditorController.demo();
    final room = controller.selectedSpace!;
    final candidates = SurfaceTransitionGraph.candidates(
      level: controller.level,
      fromSpace: room,
      fromSurface: RoomSurfaceRef.wall(room.id, 0),
      point: const SurfacePointMm(0, 1200),
    );

    expect(
      candidates.any(
        (candidate) =>
            candidate.kind == SurfaceTransitionKind.wallToWall &&
            candidate.toPoint.yMm == 1200,
      ),
      isTrue,
    );
  });

  test('shared wall exposes cross-room penetration continuation', () {
    final controller = EditorController.demo();
    final host = controller.selectedSpace!;
    final hostWall = RoomSurfaceResolver.wall(host, 0);
    final adjacent = AdjacentRoomBuilder.build(
      hostRoom: host,
      hostWall: hostWall,
      id: 'room-next',
      name: 'Room Next',
      depthMm: 2500,
      offsetFromWallStartMm: 0,
      sharedLengthMm: hostWall.lengthMm.round(),
    );
    final level = BuildingLevel(
      id: controller.level.id,
      name: controller.level.name,
      elevationMm: controller.level.elevationMm,
      spaces: [...controller.level.spaces, adjacent],
    );

    final candidates = SurfaceTransitionGraph.candidates(
      level: level,
      fromSpace: host,
      fromSurface: hostWall.ref,
      point: const SurfacePointMm(1000, 1200),
    );

    final roomTransition = candidates.singleWhere(
      (candidate) =>
          candidate.kind == SurfaceTransitionKind.roomPenetration &&
          candidate.toSurface.spaceId == adjacent.id,
    );
    expect(roomTransition.requiresPenetration, isTrue);
    expect(roomTransition.toPoint.yMm, 1200);
  });
}
