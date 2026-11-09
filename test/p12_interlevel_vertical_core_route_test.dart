import 'package:elecx/src/domain/boundary_penetration.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/building_composition.dart';
import 'package:elecx/src/domain/electrical_routing.dart';
import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_model.dart';
import 'package:elecx/src/domain/slab_topology.dart';
import 'package:elecx/src/domain/surface_transition_graph.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/domain/vertical_core_route_leg_authoring.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  EngineeringSpace room(String id) => EngineeringSpace(
        id: id,
        name: id,
        type: SpaceType.room,
        boundary: MmPolygon.rectangle(
          const MmPoint(0, 0),
          const MmPoint(4000, 3000),
        ),
        referenceFrame:
            const RoomReferenceFrame(origin: MmPoint(2000, 1500)),
      );
  final space1 = room('room-l1');
  final space2 = room('room-l2');
  final space3 = room('room-l3');
  final level1 = BuildingLevel(
    id: 'L1',
    name: 'Level 1',
    elevationMm: 0,
    spaces: [space1],
  );
  final level2 = BuildingLevel(
    id: 'L2',
    name: 'Level 2',
    elevationMm: 3220,
    spaces: [space2],
  );
  final level3 = BuildingLevel(
    id: 'L3',
    name: 'Level 3',
    elevationMm: 6440,
    spaces: [space3],
  );
  ProjectSlab slab(
    String id,
    String below,
    String above,
    int bottom, {
    int thickness = 220,
  }) =>
      ProjectSlab(
        id: SlabId(id),
        buildingId: BuildingId('building'),
        kind: SlabKind.interLevel,
        belowLevelId: LevelId(below),
        aboveLevelId: LevelId(above),
        bottomElevationMm: bottom,
        thicknessMm: thickness,
        materialId: 'concrete',
        footprint: const [
          BoundaryPointMm(xMm: 0, yMm: 0),
          BoundaryPointMm(xMm: 4000, yMm: 0),
          BoundaryPointMm(xMm: 4000, yMm: 3000),
          BoundaryPointMm(xMm: 0, yMm: 3000),
        ],
      );
  final slab12 = slab('slab-12', 'L1', 'L2', 3000);
  final slab23 = slab('slab-23', 'L2', 'L3', 6220);
  final core = VerticalCore(
    id: 'cable-riser-1',
    name: 'Electrical shaft',
    kind: VerticalCoreKind.cableRiser,
    servedLevelNumbers: [1, 2, 3],
  );

  SurfaceTransitionCandidate? crossing({
    required BuildingLevel fromLevel,
    required EngineeringSpace fromSpace,
    required RoomSurfaceRef fromSurface,
    required SurfacePointMm point,
    required BuildingLevel toLevel,
    required EngineeringSpace toSpace,
    required ProjectSlab slab,
  }) =>
      SurfaceTransitionGraph.levelPenetration(
        buildingLevels: [level1, level2, level3],
        fromLevel: fromLevel,
        fromSpace: fromSpace,
        fromSurface: fromSurface,
        point: point,
        fromRoomHeightMm: 3000,
        toLevel: toLevel,
        toSpace: toSpace,
        toRoomHeightMm: 3000,
        slabThicknessMm: slab.thicknessMm,
        slab: slab,
        materialId: slab.materialId,
      );

  test('direct L1 to L2 penetration uses canonical slab and its Z', () {
    final physical = crossing(
      fromLevel: level1,
      fromSpace: space1,
      fromSurface: RoomSurfaceRef.ceiling(space1.id),
      point: const SurfacePointMm(1000, 1000),
      toLevel: level2,
      toSpace: space2,
      slab: slab12,
    );
    expect(physical, isNotNull);
    expect(physical!.penetrationRequirement!.slabId, slab12.id);
    expect(physical.penetrationRequirement!.hostThicknessMm, 220);
    expect(physical.toSurface, RoomSurfaceRef.floor(space2.id));
  });

  test('L1 to L3 riser counts each slab exactly once and free Z once', () {
    final below = RoomSurfaceRef.ceiling(space1.id);
    final middleFloor = RoomSurfaceRef.floor(space2.id);
    final middleCeiling = RoomSurfaceRef.ceiling(space2.id);
    final above = RoomSurfaceRef.floor(space3.id);
    const bottomPoint = SurfacePointMm(1500, 1000);
    const topPoint = bottomPoint;
    final firstCrossing = crossing(
      fromLevel: level1,
      fromSpace: space1,
      fromSurface: below,
      point: bottomPoint,
      toLevel: level2,
      toSpace: space2,
      slab: slab12,
    );
    final secondCrossing = crossing(
      fromLevel: level2,
      fromSpace: space2,
      fromSurface: middleCeiling,
      point: topPoint,
      toLevel: level3,
      toSpace: space3,
      slab: slab23,
    );
    expect(firstCrossing, isNotNull);
    expect(secondCrossing, isNotNull);
    final hidden = VerticalCoreRouteLegAuthoring.betweenAdjacentSlabs(
      core: core,
      lowerSlab: slab12,
      upperSlab: slab23,
      lowerLevel: level1,
      intermediateLevel: level2,
      upperLevel: level3,
      lowerRoomHeightMm: 3000,
      lowerLevelNumber: 1,
      intermediateLevelNumber: 2,
      upperLevelNumber: 3,
      intermediateRoomHeightMm: 3000,
    );
    expect(hidden.lengthMm, 3000);

    final segments = <ElectricalRouteSegment>[
      ElectricalRouteSegment(
        surface: below,
        points: const [
          SurfacePointMm(1000, 1000),
          bottomPoint,
        ],
      ),
      ElectricalRouteSegment(
        surface: middleFloor,
        points: const [bottomPoint, bottomPoint],
      ),
      ElectricalRouteSegment(
        surface: middleCeiling,
        points: const [bottomPoint, bottomPoint],
      ),
      ElectricalRouteSegment(
        surface: above,
        points: const [
          topPoint,
          SurfacePointMm(2200, 1000),
        ],
      ),
    ];

    BoundaryPenetration fromEvidence(
      String id,
      SurfaceTransitionCandidate evidence,
    ) =>
        BoundaryPenetration.slabTyped(
          id: BoundaryPenetrationId(id),
          slabId: evidence.penetrationRequirement!.slabId!,
          entrySurface: evidence.fromSurface,
          entryPoint: evidence.fromPoint,
          exitSurface: evidence.toSurface,
          exitPoint: evidence.toPoint,
          hostThicknessMm: evidence.penetrationRequirement!.hostThicknessMm!,
          materialId: evidence.penetrationRequirement!.materialId,
          routeId: 'multi-floor',
          verticalCoreId: hidden.verticalCoreId,
        );
    final penetrations = [
      fromEvidence('p12', firstCrossing!),
      fromEvidence('p23', secondCrossing!),
    ];
    ElectricalCableRoute route({
      List<BoundaryPenetration>? openings,
      List<ElectricalRouteSegment>? spans,
    }) =>
        ElectricalCableRoute(
          id: 'multi-floor',
          source: const ElectricalEndpointRef(
            componentId: 'main-board',
            portId: 'out',
          ),
          target: const ElectricalEndpointRef(
            componentId: 'third-floor-board',
            portId: 'in',
          ),
          segments: spans ?? segments,
          penetrations: openings ?? penetrations,
          verticalCoreLegs: [hidden],
        );
    final physical = route();
    expect(physical.penetrations, hasLength(2));
    expect(physical.verticalCoreLegs, hasLength(1));
    expect(physical.visibleLengthMm, 1200);
    expect(physical.hiddenPenetrationLengthMm, 440);
    expect(physical.hiddenVerticalCoreLengthMm, 3000);
    expect(physical.geometricLengthMm, 4640);
    expect(physical.installationLengthMm, 4872);

    final lowerWall = RoomSurfaceRef.wall(space1.id, 0);
    final upperWall = RoomSurfaceRef.wall(space3.id, 0);
    final wallToCeiling = SurfaceTransitionGraph.candidates(
      level: level1,
      fromSpace: space1,
      fromSurface: lowerWall,
      point: const SurfacePointMm(1500, 3000),
    ).singleWhere(
      (candidate) => candidate.toSurface == below,
    );
    expect(wallToCeiling.toPoint, const SurfacePointMm(1500, 0));
    expect(wallToCeiling.requiresPenetration, isFalse);

    final floorToWall = SurfaceTransitionGraph.candidates(
      level: level3,
      fromSpace: space3,
      fromSurface: above,
      point: const SurfacePointMm(1500, 0),
    ).singleWhere(
      (candidate) => candidate.toSurface == upperWall,
    );
    expect(floorToWall.toPoint, const SurfacePointMm(1500, 0));
    expect(floorToWall.requiresPenetration, isFalse);

    final combined = route(spans: [
      ElectricalRouteSegment(
        surface: lowerWall,
        points: const [
          SurfacePointMm(1500, 1200),
          SurfacePointMm(1500, 3000),
        ],
      ),
      ElectricalRouteSegment(
        surface: below,
        points: const [
          SurfacePointMm(1500, 0),
          bottomPoint,
        ],
      ),
      ...segments.sublist(1, 3),
      ElectricalRouteSegment(
        surface: above,
        points: const [
          topPoint,
          SurfacePointMm(1500, 0),
        ],
      ),
      ElectricalRouteSegment(
        surface: upperWall,
        points: const [
          SurfacePointMm(1500, 0),
          SurfacePointMm(1500, 1200),
        ],
      ),
    ]);
    expect(combined.segments, hasLength(6));
    expect(combined.penetrations, hasLength(2));
    expect(combined.verticalCoreLegs, hasLength(1));
    expect(combined.visibleLengthMm, 5000);
    expect(combined.hiddenPenetrationLengthMm, 440);
    expect(combined.hiddenVerticalCoreLengthMm, 3000);
    expect(combined.geometricLengthMm, 8440);
    expect(combined.installationLengthMm, 8862);

    expect(() => route(openings: penetrations.take(1).toList()),
        throwsArgumentError);
    final invalidOwner = BoundaryPenetration.slabTyped(
      id: BoundaryPenetrationId('p23'),
      slabId: slab23.id,
      entrySurface: secondCrossing.fromSurface,
      entryPoint: secondCrossing.fromPoint,
      exitSurface: secondCrossing.toSurface,
      exitPoint: secondCrossing.toPoint,
      hostThicknessMm: 220,
      routeId: 'multi-floor',
      verticalCoreId: VerticalCoreId('other-core'),
    );
    expect(
      () => route(openings: [penetrations.first, invalidOwner]),
      throwsArgumentError,
    );
  });

  test('riser rejects wrong intermediate Z and non-cable core', () {
    final invalidSlab = slab('bad-slab', 'L2', 'L3', 6100);
    expect(
      () => VerticalCoreRouteLegAuthoring.betweenAdjacentSlabs(
        core: core,
        lowerSlab: slab12,
        upperSlab: invalidSlab,
        lowerLevel: level1,
      intermediateLevel: level2,
      upperLevel: level3,
      lowerRoomHeightMm: 3000,
        lowerLevelNumber: 1,
        intermediateLevelNumber: 2,
        upperLevelNumber: 3,
        intermediateRoomHeightMm: 3000,
      ),
      throwsArgumentError,
    );
    final stair = VerticalCore(
      id: 'stair-1',
      name: 'Stairwell',
      kind: VerticalCoreKind.stair,
      servedLevelNumbers: [1, 2, 3],
    );
    expect(
      () => VerticalCoreRouteLegAuthoring.betweenAdjacentSlabs(
        core: stair,
        lowerSlab: slab12,
        upperSlab: slab23,
        lowerLevel: level1,
      intermediateLevel: level2,
      upperLevel: level3,
      lowerRoomHeightMm: 3000,
        lowerLevelNumber: 1,
        intermediateLevelNumber: 2,
        upperLevelNumber: 3,
        intermediateRoomHeightMm: 3000,
      ),
      throwsArgumentError,
    );
  });
}
