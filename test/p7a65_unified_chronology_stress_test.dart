import 'dart:math';

import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_north_editing.dart';
import 'package:elecx/src/application/project/project_structure_authoring.dart';
import 'package:elecx/src/domain/boundary_edge_identity_registry.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_model.dart';
import 'package:elecx/src/domain/project_orientation.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/features/editor/canonical_boundary_topology_migration_runtime.dart';
import 'package:elecx/src/features/editor/canonical_editor_runtime_cutover.dart';
import 'package:elecx/src/features/editor/canonical_editor_screen_cutover_binding.dart';
import 'package:elecx/src/features/editor/canonical_editor_workspace_adapter.dart';
import 'package:elecx/src/features/editor/editor_building_workspace.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_document_history.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('P7A-6.5 mixed P2 P3 chronology survives undo x7 redo x7', () {
    final fixture = _Fixture();
    addTearDown(fixture.dispose);
    final binding = fixture.bind();
    addTearDown(binding.dispose);
    final history = fixture.controller.documentHistory;

    // 1. P3 topology split.
    expect(
      CanonicalBoundaryTopologyMigrationRuntime.splitEdge(
        controller: fixture.controller,
        edgeId: fixture.edgeIds.first,
        splitPoint: const BoundaryPointMm(xMm: 2000, yMm: 0),
        idFactory: SecureRandomEntityIdFactory(random: Random(6501)),
      ),
      isTrue,
    );
    expect(history.undoDepth, 1);

    // 2. P2 component placement on Floor so it is intentionally unrelated to
    // wall-host adoption while still participating in the same document journal.
    final floor = RoomSurfaceRef.floor(fixture.legacySpaceId);
    final first = fixture.controller.p2.placeComponent(
      type: ElectricalComponentType.junctionBox,
      surface: floor,
      position: const SurfacePointMm(800, 700),
    );
    expect(history.undoDepth, 2);

    // 3. P3 merge returns topology to four edges.
    final splitTopology =
        fixture.session.project.index.boundary(fixture.spaceId)!;
    expect(
      CanonicalBoundaryTopologyMigrationRuntime.mergeEdgeWithNext(
        controller: fixture.controller,
        edgeId: splitTopology.orderedEdgeIds.first,
        idFactory: SecureRandomEntityIdFactory(random: Random(6502)),
      ),
      isTrue,
    );
    expect(history.undoDepth, 3);

    // 4. P2 transform.
    fixture.controller.p2.select(first.id);
    expect(fixture.controller.p2.beginMoveSelectedComponent(), isTrue);
    expect(
      fixture.controller.p2.previewMoveSelectedComponent(
        const SurfacePointMm(1100, 900),
      ),
      isTrue,
    );
    expect(fixture.controller.p2.commitMoveSelectedComponent(), isTrue);
    expect(history.undoDepth, 4);

    // 5. P3 metadata mutation. Register it on the same production journal using
    // the exact shared canonical session and persistence owner contract.
    final northResult = ProjectNorthEditingSession(fixture.mutations)
        .setProjectNorth(
      ProjectEngineeringNorth.fromDegrees(37.5),
      expectedVersion: fixture.session.project.version,
    );
    expect(northResult, isNotNull);
    fixture.ownershipCount++;
    history.recordCanonicalCommit(
      session: fixture.session,
      label: 'Set Project North',
      rematerialize: () {},
    );
    expect(history.undoDepth, 5);

    // 6. Another P2 edit.
    final second = fixture.controller.p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: floor,
      position: const SurfacePointMm(1500, 1000),
    );
    expect(history.undoDepth, 6);

    // 7. P3 topology split again.
    final mergedTopology =
        fixture.session.project.index.boundary(fixture.spaceId)!;
    expect(
      CanonicalBoundaryTopologyMigrationRuntime.splitEdge(
        controller: fixture.controller,
        edgeId: mergedTopology.orderedEdgeIds.first,
        splitPoint: const BoundaryPointMm(xMm: 2000, yMm: 0),
        idFactory: SecureRandomEntityIdFactory(random: Random(6503)),
      ),
      isTrue,
    );

    expect(history.undoDepth, 7);
    expect(history.redoDepth, 0);
    expect(fixture.session.project.version, LocalProjectVersion(4));
    expect(
      fixture.session.project.index.boundary(fixture.spaceId)!.orderedEdgeIds,
      hasLength(5),
    );
    expect(fixture.controller.p2.components, hasLength(2));
    expect(
      fixture.controller.p2.components
          .singleWhere((item) => item.id == first.id)
          .position,
      const SurfacePointMm(1100, 900),
    );
    expect(
      fixture.session.project.engineeringMetadata.projectNorth?.degrees,
      37.5,
    );
    expect(fixture.ownershipCount, 4);

    for (var index = 0; index < 7; index++) {
      expect(history.undo(), isTrue, reason: 'undo index $index');
    }

    expect(history.undoDepth, 0);
    expect(history.redoDepth, 7);
    expect(fixture.session.project.version, LocalProjectVersion(8));
    expect(
      fixture.session.project.index.boundary(fixture.spaceId)!.orderedEdgeIds,
      hasLength(4),
    );
    expect(fixture.controller.p2.components, isEmpty);
    expect(fixture.session.project.engineeringMetadata.projectNorth, isNull);
    expect(fixture.ownershipCount, 8);

    for (var index = 0; index < 7; index++) {
      expect(history.redo(), isTrue, reason: 'redo index $index');
    }

    expect(history.undoDepth, 7);
    expect(history.redoDepth, 0);
    expect(fixture.session.project.version, LocalProjectVersion(12));
    expect(
      fixture.session.project.index.boundary(fixture.spaceId)!.orderedEdgeIds,
      hasLength(5),
    );
    expect(fixture.controller.p2.components, hasLength(2));
    expect(
      fixture.controller.p2.components
          .singleWhere((item) => item.id == first.id)
          .position,
      const SurfacePointMm(1100, 900),
    );
    expect(
      fixture.controller.p2.components.any((item) => item.id == second.id),
      isTrue,
    );
    expect(
      fixture.session.project.engineeringMetadata.projectNorth?.degrees,
      37.5,
    );
    expect(fixture.ownershipCount, 12);
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
      projectId: 'project-p7a65',
      projectName: 'P7A-6.5',
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
      id: ProjectId('project-p7a65'),
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
      idFactory: SecureRandomEntityIdFactory(random: Random(6500)),
      navigation: ProjectNavigationState.restore(
        project,
        activeBuildingId: buildingId,
        activeLevelId: levelId,
        selectedSpaceId: spaceId,
      ),
    );
  }

  CanonicalEditorScreenCutoverBinding bind() {
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
      onCanonicalMutationReplayed: (_) {
        ownershipCount++;
      },
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

  final SiteId siteId = SiteId('site-p7a65');
  final BuildingId buildingId = BuildingId('building-p7a65');
  final LevelId levelId = LevelId('level-p7a65');
  final SpaceId spaceId = SpaceId('space-p7a65');
  final String legacyLevelId = 'legacy-level-p7a65';
  final String legacySpaceId = 'legacy-space-p7a65';
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
