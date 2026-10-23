import 'package:elecx/src/domain/adjacent_room.dart';
import 'package:elecx/src/domain/boundary_penetration.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_model.dart';
import 'package:elecx/src/domain/slab_topology.dart';
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

  test('canonical boundary edge wall can continue without wallIndex', () {
    final controller = EditorController.demo();
    final room = controller.selectedSpace!;
    final edgeIds = List.generate(
      room.boundary.vertices.length,
      (index) => BoundaryEdgeId('edge-$index'),
    );

    final candidates = SurfaceTransitionGraph.candidates(
      level: controller.level,
      fromSpace: room,
      fromSurface: RoomSurfaceRef.wallByBoundaryEdge(room.id, edgeIds.first),
      point: const SurfacePointMm(1000, 0),
      boundaryEdgeOrderResolver: (spaceId) =>
          spaceId == room.id ? edgeIds : null,
    );

    expect(
      candidates.any(
        (candidate) => candidate.toSurface == RoomSurfaceRef.floor(room.id),
      ),
      isTrue,
    );
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

  test('shared wall creates paired continuation anchors with wall thickness',
      () {
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

    final penetrationId = BoundaryPenetrationId('penetration-1');
    final penetration = roomTransition.createPenetration(
      penetrationId: penetrationId,
      routeId: 'cable-route-1',
    );
    expect(penetration.id, penetrationId);
    expect(penetration.entryAnchor.penetrationId, penetrationId);
    expect(penetration.exitAnchor.penetrationId, penetrationId);
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

  test('level penetration fails closed without exact canonical slab evidence',
      () {
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
      elevationMm: 3220,
      spaces: [upperSpace],
    );

    final candidate = SurfaceTransitionGraph.levelPenetration(
      buildingLevels: [lower, upper],
      fromLevel: lower,
      fromSpace: lowerSpace,
      fromSurface: RoomSurfaceRef.ceiling(lowerSpace.id),
      point: const SurfacePointMm(1500, 1000),
      fromRoomHeightMm: 3000,
      toLevel: upper,
      toSpace: upperSpace,
      toRoomHeightMm: 3000,
      slabThicknessMm: 220,
      materialId: 'reinforced-concrete',
    );

    expect(candidate, isNull);
  });

  test('canonical inter-level slab proves typed penetration continuation', () {
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
      elevationMm: 3220,
      spaces: [upperSpace],
    );
    final slab = _interLevelSlab(
      id: 'slab-L1-L2',
      belowLevelId: 'L1',
      aboveLevelId: 'L2',
      bottomElevationMm: 3000,
      thicknessMm: 220,
    );

    final candidate = SurfaceTransitionGraph.levelPenetration(
      buildingLevels: [lower, upper],
      fromLevel: lower,
      fromSpace: lowerSpace,
      fromSurface: RoomSurfaceRef.ceiling(lowerSpace.id),
      point: const SurfacePointMm(1500, 1000),
      fromRoomHeightMm: 3000,
      toLevel: upper,
      toSpace: upperSpace,
      toRoomHeightMm: 3000,
      slabThicknessMm: 220,
      slab: slab,
      materialId: 'reinforced-concrete',
    );

    expect(candidate, isNotNull);
    expect(candidate!.kind, SurfaceTransitionKind.levelPenetration);
    expect(candidate.penetrationRequirement!.slabId, slab.id);
    final penetrationId = BoundaryPenetrationId('slab-penetration-1');
    final penetration = candidate.createPenetration(
      penetrationId: penetrationId,
      routeId: 'route-up',
    );
    expect(penetration.id, penetrationId);
    expect(penetration.slabId, slab.id);
    expect(penetration.entryAnchor.penetrationId, penetrationId);
    expect(penetration.exitAnchor.penetrationId, penetrationId);
  });

  test('wrong canonical slab adjacency is rejected fail closed', () {
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
      elevationMm: 3220,
      spaces: [upperSpace],
    );
    final foreignSlab = _interLevelSlab(
      id: 'slab-L1-L3',
      belowLevelId: 'L1',
      aboveLevelId: 'L3',
      bottomElevationMm: 3000,
      thicknessMm: 220,
    );

    final candidate = SurfaceTransitionGraph.levelPenetration(
      buildingLevels: [lower, upper],
      fromLevel: lower,
      fromSpace: lowerSpace,
      fromSurface: RoomSurfaceRef.ceiling(lowerSpace.id),
      point: const SurfacePointMm(1500, 1000),
      fromRoomHeightMm: 3000,
      toLevel: upper,
      toSpace: upperSpace,
      toRoomHeightMm: 3000,
      slabThicknessMm: 220,
      slab: foreignSlab,
    );

    expect(candidate, isNull);
  });

  test('slab penetration rejects a concave-room bounding-box false positive',
      () {
    final lowerSpace = EngineeringSpace(
      id: 'lower-room',
      name: 'Lower room',
      type: SpaceType.room,
      boundary: MmPolygon.rectangle(
        const MmPoint(0, 0),
        const MmPoint(4000, 4000),
      ),
      referenceFrame: const RoomReferenceFrame(origin: MmPoint(0, 0)),
    );
    final upperSpace = EngineeringSpace(
      id: 'upper-room',
      name: 'Upper L room',
      type: SpaceType.room,
      boundary: MmPolygon([
        const MmPoint(0, 0),
        const MmPoint(4000, 0),
        const MmPoint(4000, 1000),
        const MmPoint(1000, 1000),
        const MmPoint(1000, 4000),
        const MmPoint(0, 4000),
      ]),
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
    final slab = _interLevelSlab(
      id: 'slab-L1-L2',
      belowLevelId: 'L1',
      aboveLevelId: 'L2',
      bottomElevationMm: 3000,
      thicknessMm: 200,
    );

    final candidate = SurfaceTransitionGraph.levelPenetration(
      buildingLevels: [lower, upper],
      fromLevel: lower,
      fromSpace: lowerSpace,
      fromSurface: RoomSurfaceRef.ceiling(lowerSpace.id),
      point: const SurfacePointMm(3000, 3000),
      fromRoomHeightMm: 3000,
      toLevel: upper,
      toSpace: upperSpace,
      toRoomHeightMm: 3000,
      slabThicknessMm: 200,
      slab: slab,
    );

    expect(candidate, isNull);
  });
}

MmPolygon controllerRoomBoundary() => MmPolygon.rectangle(
      const MmPoint(0, 0),
      const MmPoint(4000, 3000),
    );

ProjectSlab _interLevelSlab({
  required String id,
  required String belowLevelId,
  required String aboveLevelId,
  required int bottomElevationMm,
  required int thicknessMm,
}) =>
    ProjectSlab(
      id: SlabId(id),
      buildingId: BuildingId('building-1'),
      kind: SlabKind.interLevel,
      belowLevelId: LevelId(belowLevelId),
      aboveLevelId: LevelId(aboveLevelId),
      bottomElevationMm: bottomElevationMm,
      thicknessMm: thicknessMm,
      materialId: 'reinforced-concrete',
      footprint: const [
        BoundaryPointMm(xMm: 0, yMm: 0),
        BoundaryPointMm(xMm: 4000, yMm: 0),
        BoundaryPointMm(xMm: 4000, yMm: 4000),
        BoundaryPointMm(xMm: 0, yMm: 4000),
      ],
    );
