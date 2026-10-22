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
import 'package:elecx/src/features/editor/canonical_boundary_topology_migration_runtime.dart';
import 'package:elecx/src/features/editor/canonical_editor_runtime_cutover.dart';
import 'package:elecx/src/features/editor/canonical_editor_screen_cutover_binding.dart';
import 'package:elecx/src/features/editor/canonical_editor_workspace_adapter.dart';
import 'package:elecx/src/features/editor/editor_building_workspace.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production split merge and history use one canonical ownership path', () {
    final fixture = _Fixture();
    addTearDown(fixture.dispose);
    final binding = fixture.bind();
    addTearDown(binding.dispose);

    final initialVersion = fixture.session.project.version;
    expect(
      CanonicalBoundaryTopologyMigrationRuntime.splitEdge(
        controller: fixture.controller,
        edgeId: fixture.edgeIds.first,
        splitPoint: const BoundaryPointMm(xMm: 2000, yMm: 0),
        idFactory: SecureRandomEntityIdFactory(random: Random(751)),
      ),
      isTrue,
    );

    expect(fixture.session.project.version, initialVersion.next());
    expect(
      fixture.session.project.index.boundary(fixture.spaceId)!.orderedEdgeIds,
      hasLength(5),
    );
    expect(fixture.controller.selectedSpace!.boundary.vertices, hasLength(5));
    expect(fixture.ownershipCount, 1);
    expect(fixture.controller.documentHistory.undoDepth, 1);

    expect(fixture.controller.documentHistory.undo(), isTrue);
    expect(
      fixture.session.project.index.boundary(fixture.spaceId)!.orderedEdgeIds,
      hasLength(4),
    );
    expect(fixture.controller.selectedSpace!.boundary.vertices, hasLength(4));
    expect(fixture.ownershipCount, 2);

    expect(fixture.controller.documentHistory.redo(), isTrue);
    final splitTopology = fixture.session.project.index.boundary(fixture.spaceId)!;
    expect(splitTopology.orderedEdgeIds, hasLength(5));
    expect(fixture.controller.selectedSpace!.boundary.vertices, hasLength(5));
    expect(fixture.ownershipCount, 3);

    final firstChild = splitTopology.orderedEdgeIds.first;
    expect(
      CanonicalBoundaryTopologyMigrationRuntime.mergeEdgeWithNext(
        controller: fixture.controller,
        edgeId: firstChild,
        idFactory: SecureRandomEntityIdFactory(random: Random(752)),
      ),
      isTrue,
    );
    expect(
      fixture.session.project.index.boundary(fixture.spaceId)!.orderedEdgeIds,
      hasLength(4),
    );
    expect(fixture.controller.selectedSpace!.boundary.vertices, hasLength(4));
    expect(fixture.ownershipCount, 4);
  });

  test('identity-changing edit is read-only without project-wide owner', () {
    final fixture = _Fixture();
    addTearDown(fixture.dispose);
    final binding = fixture.bind(withOwner: false);
    addTearDown(binding.dispose);

    final before = fixture.session.project;
    expect(
      CanonicalBoundaryTopologyMigrationRuntime.splitEdge(
        controller: fixture.controller,
        edgeId: fixture.edgeIds.first,
        splitPoint: const BoundaryPointMm(xMm: 2000, yMm: 0),
      ),
      isFalse,
    );
    expect(fixture.session.project, same(before));
  });
}

final class _Fixture {
  _Fixture() {
    final polygon = MmPolygon.rectangle(
      const MmPoint(0, 0),
      const MmPoint(4000, 3000),
    );
    final room = EngineeringSpace(
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
        spaces: [room],
      ),
      openings: const [],
    )..selectSpace(legacySpaceId);
    workspace = EditorBuildingWorkspace.blank(
      controller,
      projectId: 'project',
      projectName: 'P7A-5',
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
    mutations = ProjectMutationSession(project);
    session = ProjectStructureAuthoringSession(
      mutations: mutations,
      idFactory: SecureRandomEntityIdFactory(random: Random(750)),
      navigation: ProjectNavigationState.restore(
        project,
        activeBuildingId: buildingId,
        activeLevelId: levelId,
        selectedSpaceId: spaceId,
      ),
    );
  }

  CanonicalEditorScreenCutoverBinding bind({bool withOwner = true}) {
    final coordinator = CanonicalEditorRuntimeCutoverCoordinator(
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
    final binding = CanonicalEditorScreenCutoverBinding(
      coordinator: coordinator,
      onCanonicalMutationReplayed: withOwner
          ? (_) {
              ownershipCount++;
            }
          : null,
    );
    binding.start();
    return binding;
  }

  void dispose() {
    controller.disposeDocumentHistory();
    controller.disposeP2State();
    workspace.dispose();
    controller.dispose();
  }

  final SiteId siteId = SiteId('site');
  final BuildingId buildingId = BuildingId('building');
  final LevelId levelId = LevelId('level');
  final SpaceId spaceId = SpaceId('space');
  final String legacyLevelId = 'legacy-level';
  final String legacySpaceId = 'legacy-space';
  final List<BoundaryEdgeId> edgeIds = [
    BoundaryEdgeId('edge-a'),
    BoundaryEdgeId('edge-b'),
    BoundaryEdgeId('edge-c'),
    BoundaryEdgeId('edge-d'),
  ];

  int ownershipCount = 0;
  late final EditorController controller;
  late final EditorBuildingWorkspace workspace;
  late final ProjectMutationSession mutations;
  late final ProjectStructureAuthoringSession session;
}
