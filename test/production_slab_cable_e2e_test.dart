import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_slab_route_handoff.dart';
import 'package:elecx/src/application/project/project_structure_authoring.dart';
import 'package:elecx/src/domain/boundary_penetration.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/canonical_slab_transition_resolver.dart';
import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_model.dart';
import 'package:elecx/src/domain/slab_topology.dart';
import 'package:elecx/src/domain/surface_routing.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:elecx/src/features/editor/physical_manual_cable_draft_persistence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'production ceiling to floor draft commits one route through stable SlabId and hands navigation upward',
      () {
    final fixture = _Fixture();
    addTearDown(fixture.dispose);

    final sourceSurface = RoomSurfaceRef.ceiling(fixture.legacyLowerSpaceId);
    final targetSurface = RoomSurfaceRef.floor(fixture.legacyUpperSpaceId);
    final source = fixture.editor.p2.placeComponent(
      type: ElectricalComponentType.powerSource,
      surface: sourceSurface,
      position: const SurfacePointMm(600, 1200),
    );
    final target = fixture.editor.p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: targetSurface,
      position: const SurfacePointMm(2400, 1200),
    );
    expect(source.id, isNot(target.id));

    fixture.editor.setTool(EditorTool.cableRoute);
    fixture.editor.routeSegments.addAll([
      SurfaceRouteSegmentDraft(
        surface: sourceSurface,
        points: const [
          SurfacePointMm(600, 1200),
          SurfacePointMm(1500, 1200),
        ],
      ),
      SurfaceRouteSegmentDraft(
        surface: targetSurface,
        points: const [
          SurfacePointMm(1500, 1200),
          SurfacePointMm(2400, 1200),
        ],
      ),
    ]);

    final committed = fixture.editor.finishPhysicalManualCableDraft(
      routeId: 'C-vertical-01',
      resolveTransition: (fromSurface, fromPoint, toSurface, toPoint) {
        if (fromSurface != sourceSurface ||
            fromPoint != const SurfacePointMm(1500, 1200) ||
            toSurface != targetSurface ||
            toPoint != const SurfacePointMm(1500, 1200)) {
          return null;
        }
        return CanonicalSlabTransitionResolver.resolve(
          project: fixture.structure.project,
          buildingLevels: fixture.legacyLevels,
          fromLevel: fixture.legacyLower,
          fromSpace: fixture.legacyLower.spaces.single,
          fromSurface: fromSurface,
          point: fromPoint,
          fromRoomHeightMm: 3000,
          toLevel: fixture.legacyUpper,
          toSpace: fixture.legacyUpper.spaces.single,
          toRoomHeightMm: 3000,
          canonicalSpaceIdResolver: fixture.canonicalSpaceId,
        );
      },
    );

    expect(committed, isTrue);
    expect(fixture.editor.p2.routes, hasLength(1));
    final route = fixture.editor.p2.routes.single;
    expect(route.id, 'C-vertical-01');
    expect(route.segments, hasLength(2));
    expect(route.penetrations, hasLength(1));
    final penetration = route.penetrations.single;
    expect(penetration.hostKind, BoundaryPenetrationHostKind.slab);
    expect(penetration.slabId, fixture.slabId);
    expect(penetration.routeId, route.id);
    expect(penetration.hostThicknessMm, 200);
    expect(penetration.materialId, 'reinforced-concrete');
    expect(penetration.exitAnchor.isContinuationStart, isTrue);

    final handoff = ProjectSlabRouteHandoffSession(fixture.structure);
    final intent = handoff.prepare(
      routeId: route.id,
      fromSpaceId: fixture.lowerSpaceId,
      toSpaceId: fixture.upperSpaceId,
    );
    expect(intent.routeId, route.id);
    expect(intent.slabId, fixture.slabId);

    final plan = handoff.commitNavigation();
    expect(plan.slabId, fixture.slabId);
    expect(fixture.structure.navigation.selectedSpaceId, fixture.upperSpaceId);
    expect(fixture.editor.p2.routes, hasLength(1));
    expect(fixture.editor.p2.routes.single.id, route.id);
    expect(
      fixture.editor.p2.routes.single.penetrations.single.slabId,
      fixture.slabId,
    );
  });
}

final class _Fixture {
  _Fixture() {
    legacyLower = _legacyLevel(
      id: 'legacy-level-1',
      elevationMm: 0,
      spaceId: legacyLowerSpaceId,
    );
    legacyUpper = _legacyLevel(
      id: 'legacy-level-2',
      elevationMm: 3200,
      spaceId: legacyUpperSpaceId,
    );
    legacyLevels = [legacyLower, legacyUpper];

    structure = ProjectStructureAuthoringSession(
      mutations: ProjectMutationSession(_project()),
      idFactory: SecureRandomEntityIdFactory(),
    );
    structure.selectRoom(lowerSpaceId);

    editor = EditorController.blank();
    editor.level = legacyLower;
    editor.selectedSpaceId = legacyLowerSpaceId;
  }

  final ProjectId projectId = ProjectId('project');
  final SiteId siteId = SiteId('site');
  final BuildingId buildingId = BuildingId('building');
  final LevelId lowerLevelId = LevelId('level-01');
  final LevelId upperLevelId = LevelId('level-02');
  final SpaceId lowerSpaceId = SpaceId('space-l1');
  final SpaceId upperSpaceId = SpaceId('space-l2');
  final SlabId slabId = SlabId('slab-01-02');
  final String legacyLowerSpaceId = 'legacy-l1-room';
  final String legacyUpperSpaceId = 'legacy-l2-room';

  late final BuildingLevel legacyLower;
  late final BuildingLevel legacyUpper;
  late final List<BuildingLevel> legacyLevels;
  late final ProjectStructureAuthoringSession structure;
  late final EditorController editor;

  SpaceId? canonicalSpaceId(String legacySpaceId) => switch (legacySpaceId) {
        'legacy-l1-room' => lowerSpaceId,
        'legacy-l2-room' => upperSpaceId,
        _ => null,
      };

  void dispose() {
    editor.disposeP2State();
    editor.dispose();
  }

  ProjectAggregateRoot _project() {
    final slab = ProjectSlab(
      id: slabId,
      buildingId: buildingId,
      kind: SlabKind.interLevel,
      belowLevelId: lowerLevelId,
      aboveLevelId: upperLevelId,
      bottomElevationMm: 3000,
      thicknessMm: 200,
      materialId: 'reinforced-concrete',
      footprint: const [
        BoundaryPointMm(xMm: 0, yMm: 0),
        BoundaryPointMm(xMm: 4000, yMm: 0),
        BoundaryPointMm(xMm: 4000, yMm: 3000),
        BoundaryPointMm(xMm: 0, yMm: 3000),
      ],
    );
    return ProjectAggregateRoot(
      id: projectId,
      siteId: siteId,
      version: LocalProjectVersion(0),
      stores: ProjectEntityStores(
        sites: {
          siteId: ProjectSiteEntity(
            id: siteId,
            name: 'Site',
            buildingIds: [buildingId],
          ),
        },
        buildings: {
          buildingId: ProjectBuildingEntity(
            id: buildingId,
            siteId: siteId,
            name: 'Building',
            levelIds: [lowerLevelId, upperLevelId],
          ),
        },
        levels: {
          lowerLevelId: ProjectLevelEntity(
            id: lowerLevelId,
            buildingId: buildingId,
            name: 'Level 1',
            levelNumber: 1,
            elevationMm: 0,
            spaceIds: [lowerSpaceId],
          ),
          upperLevelId: ProjectLevelEntity(
            id: upperLevelId,
            buildingId: buildingId,
            name: 'Level 2',
            levelNumber: 2,
            elevationMm: 3200,
            spaceIds: [upperSpaceId],
          ),
        },
        slabs: {slabId: slab},
        spaces: {
          lowerSpaceId: ProjectSpaceEntity(
            id: lowerSpaceId,
            levelId: lowerLevelId,
            name: 'Lower room',
          ),
          upperSpaceId: ProjectSpaceEntity(
            id: upperSpaceId,
            levelId: upperLevelId,
            name: 'Upper room',
          ),
        },
      ),
    );
  }
}

BuildingLevel _legacyLevel({
  required String id,
  required int elevationMm,
  required String spaceId,
}) {
  final polygon = MmPolygon.rectangle(
    const MmPoint(0, 0),
    const MmPoint(4000, 3000),
  );
  return BuildingLevel(
    id: id,
    name: id,
    elevationMm: elevationMm,
    spaces: [
      EngineeringSpace(
        id: spaceId,
        name: spaceId,
        type: SpaceType.room,
        boundary: polygon,
        referenceFrame: RoomReferenceFrame(origin: polygon.bounds.center),
      ),
    ],
  );
}
