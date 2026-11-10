import 'dart:io';

import 'package:elecx/src/domain/boundary_penetration.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/building_composition.dart';
import 'package:elecx/src/domain/engineering_route_qualification.dart';
import 'package:elecx/src/domain/electrical_routing.dart';
import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_model.dart';
import 'package:elecx/src/domain/slab_topology.dart';
import 'package:elecx/src/domain/site_outdoor_model.dart';
import 'package:elecx/src/domain/surface_transition_graph.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/domain/vertical_core_route_leg.dart';
import 'package:elecx/src/domain/vertical_core_route_leg_authoring.dart';
import 'package:elecx/src/features/editor/editor_building_workspace.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:elecx/src/features/editor/editor_project_document.dart';
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
        referenceFrame: const RoomReferenceFrame(origin: MmPoint(2000, 1500)),
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
    spaceIdByLevel: {
      1: space1.id,
      2: space2.id,
      3: space3.id,
    },
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

    final smallFootprint = ProjectSlab(
      id: slab12.id,
      buildingId: slab12.buildingId,
      kind: SlabKind.interLevel,
      belowLevelId: slab12.belowLevelId,
      aboveLevelId: slab12.aboveLevelId,
      bottomElevationMm: slab12.bottomElevationMm,
      thicknessMm: slab12.thicknessMm,
      materialId: slab12.materialId,
      footprint: const [
        BoundaryPointMm(xMm: 0, yMm: 0),
        BoundaryPointMm(xMm: 500, yMm: 0),
        BoundaryPointMm(xMm: 500, yMm: 500),
        BoundaryPointMm(xMm: 0, yMm: 500),
      ],
    );
    expect(
      crossing(
        fromLevel: level1,
        fromSpace: space1,
        fromSurface: RoomSurfaceRef.ceiling(space1.id),
        point: const SurfacePointMm(1000, 1000),
        toLevel: level2,
        toSpace: space2,
        slab: smallFootprint,
      ),
      isNull,
    );
  });

  test('L1 to L3 riser counts each slab exactly once and free Z once',
      () async {
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
      penetrationPlanPoint: const MmPoint(1500, 1000),
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
    void requalify(VerticalCoreRouteLeg leg) =>
        VerticalCoreRouteLegAuthoring.validatePersisted(
          leg: leg,
          core: core,
          penetrationPlanPoint: const MmPoint(1500, 1000),
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
    expect(() => requalify(hidden), returnsNormally);
    expect(
      () => requalify(VerticalCoreRouteLeg(
        verticalCoreId: hidden.verticalCoreId,
        fromSlabId: hidden.fromSlabId,
        toSlabId: hidden.toSlabId,
        lengthMm: 2800,
      )),
      throwsStateError,
    );
    expect(
      () => requalify(VerticalCoreRouteLeg(
        verticalCoreId: VerticalCoreId('unregistered-core'),
        fromSlabId: hidden.fromSlabId,
        toSlabId: hidden.toSlabId,
        lengthMm: 3000,
      )),
      throwsStateError,
    );

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
      List<VerticalCoreRouteLeg>? legs,
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
          verticalCoreLegs: legs ?? [hidden],
        );
    final physical = route();
    expect(physical.penetrations, hasLength(2));
    expect(physical.verticalCoreLegs, hasLength(1));
    expect(physical.visibleLengthMm, 1200);
    expect(physical.hiddenPenetrationLengthMm, 440);
    expect(physical.hiddenVerticalCoreLengthMm, 3000);
    expect(physical.geometricLengthMm, 4640);
    expect(physical.installationLengthMm, 4872);

    final composed = ComposedBuilding(
      building: Building(
        id: 'building',
        name: 'Multi-level',
        levels: [level1, level2, level3],
      ),
      levels: [
        ComposedBuildingLevel(
          level: level1,
          levelNumber: 1,
          kind: BuildingLevelKind.residential,
        ),
        ComposedBuildingLevel(
          level: level2,
          levelNumber: 2,
          kind: BuildingLevelKind.residential,
        ),
        ComposedBuildingLevel(
          level: level3,
          levelNumber: 3,
          kind: BuildingLevelKind.residential,
        ),
      ],
      verticalCores: [core],
    );
    EngineeringRouteQualificationResult qualify(
      ElectricalCableRoute candidate, {
      Map<SlabId, ProjectSlab>? slabs,
      ComposedBuilding? owner,
    }) =>
        EngineeringRouteQualificationService.qualifyVerticalCoreRoute(
          route: candidate,
          building: owner ?? composed,
          canonicalSlabs: slabs ?? {slab12.id: slab12, slab23.id: slab23},
          roomHeightsByLevelId: const {'L1': 3000, 'L2': 3000},
        );
    expect(
      qualify(physical).status,
      EngineeringRouteQualificationStatus.valid,
    );

    final editor = EditorController.restored(
      level: level1,
      openings: const [],
    );
    final site = ComposedProjectSite(
      site: ProjectSite(
        id: 'multi-level-site',
        name: 'Multi-level routing acceptance',
        buildings: [composed.building],
      ),
      outdoorZones: const [],
      connections: const [],
    );
    final workspace = EditorBuildingWorkspace(
      editor: editor,
      building: composed,
      site: site,
      initialLevelNumber: 1,
    );
    editor.restoreP2State(EditorP2State(
      components: [
        ElectricalComponentPlacement(
          id: 'main-board',
          type: ElectricalComponentType.distributionBoard,
          surface: below,
          position: segments.first.points.first,
          label: 'Level 1 board',
          ports: const [
            ElectricalPortDefinition(
              id: 'out',
              kind: ElectricalPortKind.powerOut,
            ),
          ],
        ),
        ElectricalComponentPlacement(
          id: 'third-floor-board',
          type: ElectricalComponentType.distributionBoard,
          surface: above,
          position: segments.last.points.last,
          label: 'Level 3 board',
          ports: const [
            ElectricalPortDefinition(
              id: 'in',
              kind: ElectricalPortKind.powerIn,
            ),
          ],
        ),
      ],
      routes: [physical],
    ));
    final directory =
        await Directory.systemTemp.createTemp('elecx-three-level-');
    addTearDown(() async {
      workspace.dispose();
      editor.dispose();
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    final document = EditorProjectDocument.capture(
      workspace,
      canonicalSlabs: {slab12.id: slab12, slab23.id: slab23},
    );
    expect(document.canonicalSlabs.keys, containsAll([slab12.id, slab23.id]));
    final store = JsonFileEditorProjectStore(directory);
    await store.save(document);
    final loaded = await store.load(document.projectId);
    expect(loaded, isNotNull);
    final reopened = loaded!.restore();
    addTearDown(() {
      reopened.workspace.dispose();
      reopened.editor.dispose();
    });
    expect(reopened.editor.p2.routes.single.verticalCoreLegs, [hidden]);
    expect(reopened.editor.p2.routes.single.penetrations, hasLength(2));
    expect(reopened.workspace.building.levels, hasLength(3));
    expect(loaded.canonicalSlabs, hasLength(2));
    expect(loaded.canonicalSlabs[slab12.id]!.bottomElevationMm, 3000);
    expect(loaded.canonicalSlabs[slab12.id]!.thicknessMm, 220);
    expect(loaded.canonicalSlabs[slab12.id]!.materialId, 'concrete');
    expect(loaded.canonicalSlabs[slab12.id]!.belowLevelId, LevelId('L1'));
    expect(loaded.canonicalSlabs[slab23.id]!.aboveLevelId, LevelId('L3'));
    expect(loaded.canonicalSlabs[slab23.id]!.footprint, hasLength(4));
    expect(
      reopened.qualifyVerticalCoreRoutes(
        roomHeightsByLevelId: const {'L1': 3000, 'L2': 3000},
      ).single.status,
      EngineeringRouteQualificationStatus.valid,
    );
    expect(
      reopened
          .qualifyVerticalCoreRoutes(
            canonicalSlabs: {slab12.id: slab12, slab23.id: slab23},
            roomHeightsByLevelId: const {'L1': 3000, 'L2': 3000},
          )
          .single
          .status,
      EngineeringRouteQualificationStatus.valid,
    );
    expect(
      reopened
          .qualifyVerticalCoreRoutes(
            canonicalSlabs: const {},
            roomHeightsByLevelId: const {'L1': 3000, 'L2': 3000},
          )
          .single
          .status,
      EngineeringRouteQualificationStatus.requiresReview,
    );
    expect(
      qualify(physical, slabs: const {}).status,
      EngineeringRouteQualificationStatus.requiresReview,
    );
    final displacedLower = BuildingLevel(
      id: level1.id,
      name: level1.name,
      elevationMm: level1.elevationMm,
      spaces: [
        EngineeringSpace(
          id: space1.id,
          name: space1.name,
          type: SpaceType.room,
          boundary: MmPolygon.rectangle(
            const MmPoint(250, 0),
            const MmPoint(4250, 3000),
          ),
          referenceFrame: const RoomReferenceFrame(origin: MmPoint(2250, 1500)),
        ),
      ],
    );
    final alteredBuilding = ComposedBuilding(
      building: Building(
        id: 'building',
        name: 'Altered project',
        levels: [displacedLower, level2, level3],
      ),
      levels: [
        ComposedBuildingLevel(
          level: displacedLower,
          levelNumber: 1,
          kind: BuildingLevelKind.residential,
        ),
        ...composed.levels.skip(1),
      ],
      verticalCores: [core],
    );
    expect(
      qualify(physical, owner: alteredBuilding).status,
      EngineeringRouteQualificationStatus.stale,
    );
    expect(
      qualify(physical,
          owner: ComposedBuilding(
            building: composed.building,
            levels: composed.levels,
            verticalCores: const [],
          )).status,
      EngineeringRouteQualificationStatus.blocked,
    );
    final forged = physical.copyWith(
      verticalCoreLegs: [
        VerticalCoreRouteLeg(
          verticalCoreId: hidden.verticalCoreId,
          fromSlabId: hidden.fromSlabId,
          toSlabId: hidden.toSlabId,
          lengthMm: 1,
        ),
      ],
    );
    expect(
      qualify(forged).status,
      EngineeringRouteQualificationStatus.stale,
    );
    final alteredPassage = BoundaryPenetration.slabTyped(
      id: penetrations.first.id,
      slabId: slab12.id,
      entrySurface: penetrations.first.entryAnchor.surface,
      entryPoint: penetrations.first.entryAnchor.point,
      exitSurface: penetrations.first.exitAnchor.surface,
      exitPoint: penetrations.first.exitAnchor.point,
      hostThicknessMm: 180,
      materialId: 'concrete',
      routeId: physical.id,
      verticalCoreId: hidden.verticalCoreId,
    );
    expect(
      qualify(
        physical.copyWith(
          penetrations: [alteredPassage, penetrations.last],
        ),
      ).status,
      EngineeringRouteQualificationStatus.stale,
    );

    // A reverse/unreferenced riser leg must not inflate cable length.
    final reverseLeg = VerticalCoreRouteLeg(
      verticalCoreId: hidden.verticalCoreId,
      fromSlabId: slab23.id,
      toSlabId: slab12.id,
      lengthMm: 3000,
    );
    expect(
      () => route(legs: [hidden, reverseLeg]),
      throwsArgumentError,
    );

    // Passing through two slabs at different XY cannot be represented as a
    // single straight-Z leg, even when all penetration IDs are valid.
    const displacedPoint = SurfacePointMm(1700, 1000);
    final displacedUpper = BoundaryPenetration.slabTyped(
      id: BoundaryPenetrationId('p23'),
      slabId: slab23.id,
      entrySurface: secondCrossing.fromSurface,
      entryPoint: displacedPoint,
      exitSurface: secondCrossing.toSurface,
      exitPoint: displacedPoint,
      hostThicknessMm: 220,
      materialId: 'concrete',
      routeId: 'multi-floor',
      verticalCoreId: hidden.verticalCoreId,
    );
    final displacedSegments = <ElectricalRouteSegment>[
      segments.first,
      segments[1],
      ElectricalRouteSegment(
        surface: middleCeiling,
        points: const [displacedPoint, displacedPoint],
      ),
      ElectricalRouteSegment(
        surface: above,
        points: const [
          displacedPoint,
          SurfacePointMm(2200, 1000),
        ],
      ),
    ];
    expect(
      () => route(
        openings: [penetrations.first, displacedUpper],
        spans: displacedSegments,
      ),
      throwsArgumentError,
    );

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
        penetrationPlanPoint: const MmPoint(1500, 1000),
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
    final missingLevelSpace = VerticalCore(
      id: 'unmapped-riser',
      name: 'Unmapped shaft',
      kind: VerticalCoreKind.cableRiser,
      servedLevelNumbers: [1, 2, 3],
      spaceIdByLevel: {
        1: space1.id,
        3: space3.id,
      },
    );
    expect(
      () => VerticalCoreRouteLegAuthoring.betweenAdjacentSlabs(
        core: missingLevelSpace,
        penetrationPlanPoint: const MmPoint(1500, 1000),
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
    expect(
      () => VerticalCoreRouteLegAuthoring.betweenAdjacentSlabs(
        core: core,
        penetrationPlanPoint: const MmPoint(4500, 1000),
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
    final stair = VerticalCore(
      id: 'stair-1',
      name: 'Stairwell',
      kind: VerticalCoreKind.stair,
      servedLevelNumbers: [1, 2, 3],
    );
    expect(
      () => VerticalCoreRouteLegAuthoring.betweenAdjacentSlabs(
        core: stair,
        penetrationPlanPoint: const MmPoint(1500, 1000),
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
