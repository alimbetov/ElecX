import 'package:elecx/src/domain/adjacent_room.dart';
import 'package:elecx/src/domain/boundary_penetration.dart';
import 'package:elecx/src/domain/geometry.dart';
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

  test('shared wall creates paired continuation anchors with wall thickness', () {
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
      thicknessResolver: (_, __) => 180,
      materialResolver: (_, __) => 'brick',
    );

    final roomTransition = candidates.singleWhere(
      (candidate) =>
          candidate.kind == SurfaceTransitionKind.roomPenetration &&
          candidate.toSurface.spaceId == adjacent.id,
    );
    expect(roomTransition.requiresPenetration, isTrue);
    expect(roomTransition.toPoint.yMm, 1200);

    final penetration = roomTransition.createPenetration(
      penetrationId: 'penetration-1',
      routeId: 'cable-route-1',
    );
    expect(penetration.hostKind, BoundaryPenetrationHostKind.wall);
    expect(penetration.hostThicknessMm, 180);
    expect(penetration.routeLengthContributionMm, 180);
    expect(penetration.materialId, 'brick');
    expect(penetration.entryAnchor.routeId, 'cable-route-1');
    expect(penetration.exitAnchor.routeId, 'cable-route-1');
    expect(penetration.exitAnchor.isContinuationStart, isTrue);
    expect(
      penetration.oppositeAnchor(penetration.entryAnchor.surface),
      same(penetration.exitAnchor),
    );
  });

  test('ceiling to upper floor requires a slab penetration', () {
    final lowerSpace = EngineeringSpace(
      id: 'lower-room',
      name: 'Lower room',
      type: SpaceType.room,
      boundary: controllerRoomBoundary(),
      referenceFrame: const RoomReferenceFrame(origin: MmPoint(0, 0)),
    );
    final upperSpace = EngineeringSpace(
      id: 'upper-room',
      name: 'Upper room',
      type: SpaceType.room,
      boundary: controllerRoomBoundary(),
      referenceFrame: const RoomReferenceFrame(origin: MmPoint(0, 0)),
    );
    final lower = BuildingLevel(
      id: 'L1',
      name: 'Level 1',
      elevationMm: 0,
      spaces: [lowerSpace],
    );
    final upper = BuildingLevel(
      id: 'L2',
      name: 'Level 2',
      elevationMm: 3200,
      spaces: [upperSpace],
    );

    final candidate = SurfaceTransitionGraph.levelPenetration(
      fromLevel: lower,
      fromSpace: lowerSpace,
      fromSurface: RoomSurfaceRef.ceiling(lowerSpace.id),
      point: const SurfacePointMm(1500, 1000),
      toLevel: upper,
      toSpace: upperSpace,
      slabThicknessMm: 220,
      materialId: 'reinforced-concrete',
    );

    expect(candidate, isNotNull);
    expect(candidate!.kind, SurfaceTransitionKind.levelPenetration);
    expect(candidate.requiresPenetration, isTrue);
    expect(candidate.toSurface, RoomSurfaceRef.floor(upperSpace.id));

    final penetration = candidate.createPenetration(
      penetrationId: 'slab-penetration-1',
      routeId: 'route-up',
    );
    expect(penetration.hostKind, BoundaryPenetrationHostKind.slab);
    expect(penetration.hostThicknessMm, 220);
    expect(penetration.exitAnchor.isContinuationStart, isTrue);
    expect(penetration.exitAnchor.surface, RoomSurfaceRef.floor(upperSpace.id));
  });
}

MmPolygon controllerRoomBoundary() => MmPolygon.rectangle(
      const MmPoint(0, 0),
      const MmPoint(4000, 3000),
    );
