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
import 'package:elecx/src/features/editor/editor_document_history.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P7A-6.1 production session races', () {
    test(
        'ordinal resolution rebuilds after split and never returns retired edge',
        () {
      final fixture = _Fixture();
      addTearDown(fixture.dispose);
      final binding = fixture.bind();
      addTearDown(binding.dispose);

      fixture.controller.showWall(0);
      final resolved =
          CanonicalBoundaryTopologyMigrationRuntime.edgeIdAtLegacyWallOrdinal(
        fixture.controller,
        0,
      );
      expect(resolved, fixture.edgeIds.first);
      final retiredEdge = resolved!;

      expect(
        CanonicalBoundaryTopologyMigrationRuntime.splitEdge(
          controller: fixture.controller,
          edgeId: retiredEdge,
          splitPoint: const BoundaryPointMm(xMm: 2000, yMm: 0),
          idFactory: SecureRandomEntityIdFactory(random: Random(961)),
        ),
        isTrue,
      );

      final topology = fixture.session.project.index.boundary(fixture.spaceId)!;
      expect(topology.orderedEdgeIds, hasLength(5));
      expect(topology.edges.containsKey(retiredEdge), isFalse);
      expect(fixture.controller.viewMode, EditorViewMode.plan);

      final freshlyResolved =
          CanonicalBoundaryTopologyMigrationRuntime.edgeIdAtLegacyWallOrdinal(
        fixture.controller,
        0,
      );
      expect(freshlyResolved, topology.orderedEdgeIds.first);
      expect(freshlyResolved, isNot(retiredEdge));

      expect(
        CanonicalBoundaryTopologyMigrationRuntime.splitEdge(
          controller: fixture.controller,
          edgeId: retiredEdge,
          splitPoint: const BoundaryPointMm(xMm: 1000, yMm: 0),
          idFactory: SecureRandomEntityIdFactory(random: Random(962)),
        ),
        isFalse,
      );
      expect(fixture.session.project.version, LocalProjectVersion(1));
      expect(fixture.controller.documentHistory.undoDepth, 1);
    });

    test('out-of-band canonical version gap invalidates unsafe unified undo',
        () {
      final fixture = _Fixture();
      addTearDown(fixture.dispose);
      final binding = fixture.bind();
      addTearDown(binding.dispose);

      expect(
        CanonicalBoundaryTopologyMigrationRuntime.splitEdge(
          controller: fixture.controller,
          edgeId: fixture.edgeIds.first,
          splitPoint: const BoundaryPointMm(xMm: 2000, yMm: 0),
          idFactory: SecureRandomEntityIdFactory(random: Random(963)),
        ),
        isTrue,
      );
      expect(fixture.controller.documentHistory.undoDepth, 1);
      expect(fixture.session.project.version, LocalProjectVersion(1));

      final outOfBand = fixture.mutations.commit(
        ProjectMutationRequest(
          expectedVersion: fixture.session.project.version,
          command: _RenameSpaceCommand(
            spaceId: fixture.spaceId,
            name: 'Out-of-band winner',
          ),
        ),
      );
      expect(outOfBand, isNotNull);
      expect(fixture.session.project.version, LocalProjectVersion(2));
      expect(
        fixture.session.project.stores.spaces[fixture.spaceId]!.name,
        'Out-of-band winner',
      );

      expect(fixture.controller.documentHistory.undo(), isFalse);
      expect(fixture.controller.documentHistory.undoDepth, 0);
      expect(fixture.controller.documentHistory.redoDepth, 0);
      expect(fixture.session.project.version, LocalProjectVersion(2));
      expect(
        fixture.session.project.index.boundary(fixture.spaceId)!.orderedEdgeIds,
        hasLength(5),
        reason: 'unsafe stale history must not undo the earlier split',
      );
      expect(
        fixture.session.project.stores.spaces[fixture.spaceId]!.name,
        'Out-of-band winner',
        reason: 'the newer canonical mutation must remain authoritative',
      );
    });
  });
}

final class _RenameSpaceCommand implements ProjectCommand {
  const _RenameSpaceCommand({required this.spaceId, required this.name});

  final SpaceId spaceId;
  final String name;

  @override
  String get commandType => 'p7a6.outOfBandRename';

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) {
    final source = current.stores.spaces[spaceId]!;
    return ProjectCommandCandidate.fromState(
      state: ProjectMutableState(
        engineeringMetadata: current.engineeringMetadata,
        stores: ProjectEntityStores(
          sites: current.stores.sites,
          buildings: current.stores.buildings,
          levels: current.stores.levels,
          zones: current.stores.zones,
          spaces: {
            ...current.stores.spaces,
            spaceId: ProjectSpaceEntity(
              id: source.id,
              levelId: source.levelId,
              name: name,
              usage: source.usage,
            ),
          },
          openings: current.stores.openings,
          adjacencies: current.stores.adjacencies,
          overlays: current.stores.overlays,
          boundaries: current.stores.boundaries,
        ),
      ),
      affectedEntityIds: <EntityId>{spaceId},
    );
  }
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
      projectId: 'project-p7a6-session-race',
      projectName: 'P7A-6.1 session race',
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
      id: ProjectId('project-p7a6-session-race'),
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
      idFactory: SecureRandomEntityIdFactory(random: Random(960)),
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
      onCanonicalMutationReplayed: (_) {},
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

  late final EditorController controller;
  late final EditorBuildingWorkspace workspace;
  late final ProjectMutationSession mutations;
  late final ProjectStructureAuthoringSession session;
}
