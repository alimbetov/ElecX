import 'package:elecx/src/domain/boundary_penetration.dart';
import 'package:elecx/src/domain/building_composition.dart';
import 'package:elecx/src/domain/electrical_routing.dart';
import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_model.dart';
import 'package:elecx/src/domain/site_outdoor_model.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/domain/vertical_core_route_leg.dart';
import 'package:elecx/src/features/editor/editor_building_workspace.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:elecx/src/features/editor/editor_project_document.dart';
import 'package:elecx/src/features/editor/project_persistence_metadata.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Save Reopen preserves VerticalCore penetration and hidden leg evidence',
      () {
    final coreId = VerticalCoreId('VC-01');
    final slab12 = SlabId('SLAB-12');
    final slab23 = SlabId('SLAB-23');
    const point = SurfacePointMm(100, 0);
    final ceiling1 = RoomSurfaceRef.ceiling('room-l1');
    final floor2 = RoomSurfaceRef.floor('room-l2');
    final ceiling2 = RoomSurfaceRef.ceiling('room-l2');
    final floor3 = RoomSurfaceRef.floor('room-l3');
    final route = ElectricalCableRoute(
      id: 'R-1',
      source: const ElectricalEndpointRef(componentId: 'SRC', portId: 'OUT'),
      target: const ElectricalEndpointRef(componentId: 'DST', portId: 'IN'),
      reservePercent: 0,
      segments: [
        ElectricalRouteSegment(
          surface: ceiling1,
          points: const [SurfacePointMm(0, 0), point],
        ),
        ElectricalRouteSegment(surface: floor2, points: const [point]),
        ElectricalRouteSegment(surface: ceiling2, points: const [point]),
        ElectricalRouteSegment(
          surface: floor3,
          points: const [point, SurfacePointMm(200, 0)],
        ),
      ],
      penetrations: [
        BoundaryPenetration.slab(
          id: 'P-12',
          slabId: slab12,
          verticalCoreId: coreId,
          entrySurface: ceiling1,
          entryPoint: point,
          exitSurface: floor2,
          exitPoint: point,
          hostThicknessMm: 200,
          routeId: 'R-1',
          materialId: 'reinforced-concrete',
        ),
        BoundaryPenetration.slab(
          id: 'P-23',
          slabId: slab23,
          verticalCoreId: coreId,
          entrySurface: ceiling2,
          entryPoint: point,
          exitSurface: floor3,
          exitPoint: point,
          hostThicknessMm: 200,
          routeId: 'R-1',
          materialId: 'reinforced-concrete',
        ),
      ],
      verticalCoreLegs: [
        VerticalCoreRouteLeg(
          verticalCoreId: coreId,
          fromSlabId: slab12,
          toSlabId: slab23,
          lengthMm: 3000,
        ),
      ],
    );
    final building = _building();
    final site = ComposedProjectSite(
      site: ProjectSite(
        id: 'site-1',
        name: 'Site',
        buildings: [building.building],
      ),
    );
    final now = DateTime.utc(2026, 10, 23, 10);
    final document = EditorProjectDocument(
      schemaVersion: EditorProjectDocument.currentSchemaVersion,
      metadata: EditorProjectMetadata(
        projectId: 'project-1',
        projectName: 'Project',
        createdAt: now,
        updatedAt: now,
      ),
      building: building,
      site: site,
      workspaceContext: EditorWorkspaceContext.buildingLevel,
      activeLevelNumber: 1,
      selectedZoneId: null,
      activeOutdoorZoneId: null,
      openingsByLevel: const {},
      resume: const EditorProjectResumeState(
        selectedSpaceId: null,
        selectedOpeningId: null,
        activeSurface: null,
        viewMode: EditorViewMode.plan,
        snapEnabled: true,
        dimensionsVisible: true,
        floorGridMm: 100,
        zoom: 1,
        roomSequence: 1,
        openingSequence: 1,
      ),
      p2State: EditorP2State(routes: [route]),
    );

    final restored = EditorProjectDocument.fromJson(document.toJson());
    final restoredRoute = restored.p2State.routes.single;

    expect(restoredRoute.id, route.id);
    expect(restoredRoute.penetrations, hasLength(2));
    expect(
      restoredRoute.penetrations.map((value) => value.slabId),
      [slab12, slab23],
    );
    expect(
      restoredRoute.penetrations.map((value) => value.verticalCoreId).toSet(),
      {coreId},
    );
    expect(restoredRoute.verticalCoreLegs, route.verticalCoreLegs);
    expect(restoredRoute.hiddenVerticalCoreLengthMm, 3000);
    expect(restoredRoute.geometricLengthMm, 3600);
  });

  test('legacy route JSON without riser fields still decodes as empty evidence',
      () {
    final building = _building();
    final site = ComposedProjectSite(
      site: ProjectSite(
        id: 'site-1',
        name: 'Site',
        buildings: [building.building],
      ),
    );
    final now = DateTime.utc(2026, 10, 23, 10);
    final document = EditorProjectDocument(
      schemaVersion: EditorProjectDocument.currentSchemaVersion,
      metadata: EditorProjectMetadata(
        projectId: 'project-legacy',
        projectName: 'Legacy',
        createdAt: now,
        updatedAt: now,
      ),
      building: building,
      site: site,
      workspaceContext: EditorWorkspaceContext.buildingLevel,
      activeLevelNumber: 1,
      selectedZoneId: null,
      activeOutdoorZoneId: null,
      openingsByLevel: const {},
      resume: const EditorProjectResumeState(
        selectedSpaceId: null,
        selectedOpeningId: null,
        activeSurface: null,
        viewMode: EditorViewMode.plan,
        snapEnabled: true,
        dimensionsVisible: true,
        floorGridMm: 100,
        zoom: 1,
        roomSequence: 1,
        openingSequence: 1,
      ),
      p2State: EditorP2State(
        routes: [
          ElectricalCableRoute(
            id: 'R-legacy',
            source: const ElectricalEndpointRef(
              componentId: 'SRC',
              portId: 'OUT',
            ),
            target: const ElectricalEndpointRef(
              componentId: 'DST',
              portId: 'IN',
            ),
            segments: [
              ElectricalRouteSegment(
                surface: RoomSurfaceRef.floor('room-l1'),
                points: const [SurfacePointMm(0, 0), SurfacePointMm(100, 0)],
              ),
            ],
          ),
        ],
      ),
    );
    final json = document.toJson();
    final p2 = json['p2']! as Map<String, Object?>;
    final routes = p2['routes']! as List<Object?>;
    final routeJson = routes.single as Map<String, Object?>;
    routeJson.remove('verticalCoreLegs');

    final restored = EditorProjectDocument.fromJson(json);
    expect(restored.p2State.routes.single.verticalCoreLegs, isEmpty);
  });
}

ComposedBuilding _building() {
  final levels = <BuildingLevel>[
    _level('level-1', 'L1', 0, 'room-l1'),
    _level('level-2', 'L2', 3200, 'room-l2'),
    _level('level-3', 'L3', 6400, 'room-l3'),
  ];
  final building = Building(id: 'building-1', name: 'Building', levels: levels);
  return ComposedBuilding(
    building: building,
    levels: [
      ComposedBuildingLevel(
        level: levels[0],
        levelNumber: 1,
        kind: BuildingLevelKind.residential,
      ),
      ComposedBuildingLevel(
        level: levels[1],
        levelNumber: 2,
        kind: BuildingLevelKind.residential,
      ),
      ComposedBuildingLevel(
        level: levels[2],
        levelNumber: 3,
        kind: BuildingLevelKind.residential,
      ),
    ],
  );
}

BuildingLevel _level(
  String id,
  String name,
  int elevationMm,
  String spaceId,
) =>
    BuildingLevel(
      id: id,
      name: name,
      elevationMm: elevationMm,
      spaces: [
        EngineeringSpace(
          id: spaceId,
          name: spaceId,
          type: SpaceType.technicalRoom,
          boundary: MmPolygon(const [
            MmPoint(0, 0),
            MmPoint(4000, 0),
            MmPoint(4000, 3000),
            MmPoint(0, 3000),
          ]),
          referenceFrame: const RoomReferenceFrame(origin: MmPoint(0, 0)),
        ),
      ],
    );
