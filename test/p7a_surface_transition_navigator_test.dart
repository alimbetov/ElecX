import 'dart:math';

import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_structure_authoring.dart';
import 'package:elecx/src/domain/boundary_edge_identity_registry.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_model.dart';
import 'package:elecx/src/domain/project_orientation.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/features/editor/canonical_editor_runtime_cutover.dart';
import 'package:elecx/src/features/editor/canonical_editor_workspace_adapter.dart';
import 'package:elecx/src/features/editor/canonical_room_surface_runtime_registry.dart';
import 'package:elecx/src/features/editor/editor_building_workspace.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/surface_transition_navigator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P7A canonical surface transition navigation', () {
    test('BoundaryEdgeId resolves through current canonical projection', () {
      final fixture = _Fixture();
      addTearDown(fixture.dispose);

      expect(
        SurfaceTransitionNavigator.navigate(
          fixture.controller,
          RoomSurfaceRef.wallByBoundaryEdge(
            fixture.spaceId.value,
            fixture.edgeIds[2],
          ),
        ),
        isTrue,
      );
      expect(fixture.controller.selectedSpaceId, fixture.legacySpaceId);
      expect(fixture.controller.activeSurface?.wallIndex, 2);
    });

    test('retired or foreign BoundaryEdgeId fails closed to Plan', () {
      final fixture = _Fixture();
      addTearDown(fixture.dispose);
      fixture.controller.showWall(1);

      expect(
        SurfaceTransitionNavigator.navigate(
          fixture.controller,
          RoomSurfaceRef.wallByBoundaryEdge(
            fixture.spaceId.value,
            BoundaryEdgeId('retired-edge'),
          ),
        ),
        isFalse,
      );
      expect(fixture.controller.viewMode, EditorViewMode.plan);
      expect(fixture.controller.activeSurface, isNull);
    });

    test('legacy wallIndex remains a legacy-only fallback', () {
      final polygon = MmPolygon.rectangle(
        const MmPoint(0, 0),
        const MmPoint(4000, 3000),
      );
      final space = EngineeringSpace(
        id: 'legacy-only-space',
        name: 'Legacy room',
        type: SpaceType.room,
        boundary: polygon,
        referenceFrame: RoomReferenceFrame(origin: polygon.bounds.center),
      );
      final controller = EditorController.restored(
        level: BuildingLevel(
          id: 'legacy-level',
          name: 'Level',
          elevationMm: 0,
          spaces: [space],
        ),
        openings: const [],
      )..selectSpace(space.id);
      addTearDown(controller.dispose);

      expect(
        SurfaceTransitionNavigator.navigate(
          controller,
          RoomSurfaceRef.wall(space.id, 3),
        ),
        isTrue,
      );
      expect(controller.activeSurface?.wallIndex, 3);
    });
  });
}

final class _Fixture {
  _Fixture() {
    final polygon = MmPolygon.rectangle(
      const MmPoint(0, 0),
      const MmPoint(4000, 3000),
    );
    final legacySpace = EngineeringSpace(
      id: legacySpaceId,
      name: 'Room',
      type: SpaceType.room,
      boundary: polygon,
      referenceFrame: RoomReferenceFrame(origin: polygon.bounds.center),
    );
    controller = EditorController.restored(
      level: BuildingLevel(
        id: legacyLevelId,
        name: 'Level',
        elevationMm: 0,
        spaces: [legacySpace],
      ),
      openings: const [],
    )..selectSpace(legacySpaceId);
    workspace = EditorBuildingWorkspace.blank(
      controller,
      projectId: 'project',
      projectName: 'Surface transition navigation',
    );
    controller.selectSpace(legacySpaceId);

    const points = <BoundaryPointMm>[
      BoundaryPointMm(xMm: 0, yMm: 0),
      BoundaryPointMm(xMm: 4000, yMm: 0),
      BoundaryPointMm(xMm: 4000, yMm: 3000),
      BoundaryPointMm(xMm: 0, yMm: 3000),
    ];
    final topology = SpaceBoundaryTopology(
      spaceId: spaceId,
      orderedEdgeIds: edgeIds,
      edges: {
        for (var index = 0; index < edgeIds.length; index++)
          edgeIds[index]: ProjectBoundaryEdge(
            id: edgeIds[index],
            spaceId: spaceId,
            start: points[index],
            end: points[(index + 1) % points.length],
          ),
      },
    );
    final boundaries = <SpaceId, SpaceBoundaryTopology>{spaceId: topology};
    final identity = const BoundaryEdgeIdentityRegistry.empty()
        .registerActiveBoundaries(boundaries);
    final project = ProjectAggregateRoot(
      id: ProjectId('project'),
      siteId: siteId,
      version: LocalProjectVersion(0),
      engineeringMetadata: ProjectEngineeringMetadata(
        boundaryEdgeIdentityRegistry: identity,
      ),
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
            levelIds: [levelId],
          ),
        },
        levels: {
          levelId: ProjectLevelEntity(
            id: levelId,
            buildingId: buildingId,
            name: 'Level',
            levelNumber: 1,
            elevationMm: 0,
            spaceIds: [spaceId],
          ),
        },
        spaces: {
          spaceId: ProjectSpaceEntity(
            id: spaceId,
            levelId: levelId,
            name: 'Room',
          ),
        },
        boundaries: boundaries,
      ),
    );
    session = ProjectStructureAuthoringSession(
      mutations: ProjectMutationSession(project),
      idFactory: SecureRandomEntityIdFactory(random: Random(71)),
      navigation: ProjectNavigationState.restore(
        project,
        activeBuildingId: buildingId,
        activeLevelId: levelId,
        selectedSpaceId: spaceId,
      ),
    );
    coordinator = CanonicalEditorRuntimeCutoverCoordinator(
      session: session,
      adapter: CanonicalEditorWorkspaceAdapter(
        workspace: workspace,
        binding: CanonicalEditorWorkspaceBinding(
          buildingId: buildingId,
          legacyBuildingId: workspace.building.building.id,
          legacyLevelIds: {levelId: legacyLevelId},
          legacySpaceIds: {spaceId: legacySpaceId},
        ),
      ),
    );
    CanonicalRoomSurfaceRuntimeRegistry.attach(coordinator);
  }

  void dispose() {
    CanonicalRoomSurfaceRuntimeRegistry.detach(coordinator);
    workspace.dispose();
    controller.dispose();
  }

  final SiteId siteId = SiteId('site');
  final BuildingId buildingId = BuildingId('building');
  final LevelId levelId = LevelId('level');
  final SpaceId spaceId = SpaceId('canonical-space');
  final String legacyLevelId = 'legacy-level';
  final String legacySpaceId = 'legacy-space';
  final List<BoundaryEdgeId> edgeIds = [
    BoundaryEdgeId('edge-a'),
    BoundaryEdgeId('edge-b'),
    BoundaryEdgeId('edge-c'),
    BoundaryEdgeId('edge-d'),
  ];

  late final EditorController controller;
  late final EditorBuildingWorkspace workspace;
  late final ProjectStructureAuthoringSession session;
  late final CanonicalEditorRuntimeCutoverCoordinator coordinator;
}
