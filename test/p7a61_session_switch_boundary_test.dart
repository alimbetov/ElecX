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
  group('P7A-6.1 owner/session-switch boundary', () {
    test('postcommit owner session switch fails closed before old projection',
        () {
      final fixture = _RuntimeFixture();
      addTearDown(fixture.dispose);
      final binding = fixture.bindWithSessionSwitchingOwner();
      addTearDown(binding.dispose);

      fixture.controller.showWall(0);
      expect(
        () =>
            CanonicalBoundaryTopologyMigrationRuntime.splitLegacyWallAtMidpoint(
          controller: fixture.controller,
          wallOrdinal: 0,
          idFactory: SecureRandomEntityIdFactory(random: Random(991)),
        ),
        throwsA(
          isA<CanonicalBoundaryPostCommitException>().having(
            (error) => error.phase,
            'phase',
            'persistence ownership acknowledgement session-affinity check',
          ),
        ),
      );

      final replacement = fixture.replacementSession;
      expect(replacement, isNotNull);
      expect(fixture.ownerCalls, 1);
      expect(fixture.session.project.version, LocalProjectVersion(1));
      expect(
        fixture.session.project.index.boundary(fixture.spaceId)!.orderedEdgeIds,
        hasLength(5),
        reason:
            'the canonical split committed before the owner switched session',
      );
      expect(
        fixture.controller.documentHistory
            .hasCanonicalSessionAffinity(replacement!),
        isTrue,
        reason: 'the new session must remain attached after fail-closed abort',
      );
      expect(
        fixture.controller.documentHistory
            .hasCanonicalSessionAffinity(fixture.session),
        isFalse,
        reason:
            'history must never silently reattach the committed old session',
      );
      expect(fixture.controller.documentHistory.undoDepth, 0);
      expect(fixture.controller.documentHistory.redoDepth, 0);
      expect(
        fixture.controller.selectedSpaceId,
        fixture.legacySpaceId,
        reason: 'old-session best-effort projection must not run after switch',
      );
    });

    test('canonical undo owner session switch cannot manufacture redo', () {
      final controller = EditorController.demo();
      addTearDown(controller.disposeDocumentHistory);
      addTearDown(controller.disposeP2State);
      addTearDown(controller.dispose);

      final fixture = _HistoryFixture();
      final initial = fixture.project();
      final mutations = ProjectMutationSession(initial);
      final session = fixture.session(mutations, seed: 992);
      final history = controller.documentHistory;

      ProjectStructureAuthoringSession? replacement;
      history.attachCanonicalSession(
        session,
        onReplayed: (result) {
          replacement = fixture.session(
            ProjectMutationSession(result.project),
            seed: 993,
          );
          history.attachCanonicalSession(replacement!, onReplayed: (_) {});
        },
      );

      final committed = mutations.commit(
        ProjectMutationRequest(
          expectedVersion: initial.version,
          command: _RenameSpaceCommand(
            spaceId: fixture.spaceId,
            name: 'Version one',
          ),
        ),
      );
      expect(committed, isNotNull);
      history.recordCanonicalCommit(
        session: session,
        label: 'Version one',
        rematerialize: () {
          fail(
              'old-session rematerialization must not run after session switch');
        },
      );

      expect(history.undo(), isFalse);
      expect(replacement, isNotNull);
      expect(history.hasCanonicalSessionAffinity(replacement!), isTrue);
      expect(history.hasCanonicalSessionAffinity(session), isFalse);
      expect(session.project.version, LocalProjectVersion(2));
      expect(session.project.stores.spaces[fixture.spaceId]!.name, 'Room');
      expect(history.undoDepth, 0);
      expect(history.redoDepth, 0);
    });

    test('commit registration cannot hijack an already replaced session', () {
      final controller = EditorController.demo();
      addTearDown(controller.disposeDocumentHistory);
      addTearDown(controller.disposeP2State);
      addTearDown(controller.dispose);

      final fixture = _HistoryFixture();
      final initial = fixture.project();
      final mutations = ProjectMutationSession(initial);
      final oldSession = fixture.session(mutations, seed: 994);
      final history = controller.documentHistory;
      history.attachCanonicalSession(oldSession, onReplayed: (_) {});

      final committed = mutations.commit(
        ProjectMutationRequest(
          expectedVersion: initial.version,
          command: _RenameSpaceCommand(
            spaceId: fixture.spaceId,
            name: 'Committed old session',
          ),
        ),
      );
      expect(committed, isNotNull);

      final replacement = fixture.session(
        ProjectMutationSession(committed!.project),
        seed: 995,
      );
      history.attachCanonicalSession(replacement, onReplayed: (_) {});

      expect(
        () => history.recordCanonicalCommit(
          session: oldSession,
          label: 'Must not be registered',
          rematerialize: () {},
        ),
        throwsStateError,
      );
      expect(history.hasCanonicalSessionAffinity(replacement), isTrue);
      expect(history.hasCanonicalSessionAffinity(oldSession), isFalse);
      expect(history.undoDepth, 0);
      expect(history.redoDepth, 0);
    });
  });
}

final class _RuntimeFixture {
  _RuntimeFixture() {
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
      projectName: 'P7A-6.1 session-switch boundary',
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
    session = _session(mutations, 996);
  }

  CanonicalEditorScreenCutoverBinding bindWithSessionSwitchingOwner() =>
      _bind((result) {
        ownerCalls++;
        replacementSession = _session(
          ProjectMutationSession(result.project),
          997,
        );
        controller.documentHistory.attachCanonicalSession(
          replacementSession!,
          onReplayed: (_) {},
        );
      });

  CanonicalEditorScreenCutoverBinding _bind(
    void Function(ProjectMutationResult result) owner,
  ) {
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
      onCanonicalMutationReplayed: owner,
    );
    binding.start();
    return binding;
  }

  ProjectStructureAuthoringSession _session(
    ProjectMutationSession mutationSession,
    int seed,
  ) =>
      ProjectStructureAuthoringSession(
        mutations: mutationSession,
        idFactory: SecureRandomEntityIdFactory(random: Random(seed)),
        navigation: ProjectNavigationState.restore(
          mutationSession.current,
          activeBuildingId: buildingId,
          activeLevelId: levelId,
          selectedSpaceId: spaceId,
        ),
      );

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

  int ownerCalls = 0;
  ProjectStructureAuthoringSession? replacementSession;
  late final EditorController controller;
  late final EditorBuildingWorkspace workspace;
  late final ProjectMutationSession mutations;
  late final ProjectStructureAuthoringSession session;
}

final class _RenameSpaceCommand implements ProjectCommand {
  const _RenameSpaceCommand({required this.spaceId, required this.name});

  final SpaceId spaceId;
  final String name;

  @override
  String get commandType => 'p7a61.sessionSwitchRename';

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

final class _HistoryFixture {
  final projectId = ProjectId('project-p7a61-session-switch');
  final siteId = SiteId('site-p7a61-session-switch');
  final buildingId = BuildingId('building-p7a61-session-switch');
  final levelId = LevelId('level-p7a61-session-switch');
  final spaceId = SpaceId('space-p7a61-session-switch');

  ProjectStructureAuthoringSession session(
    ProjectMutationSession mutations, {
    required int seed,
  }) =>
      ProjectStructureAuthoringSession(
        mutations: mutations,
        idFactory: SecureRandomEntityIdFactory(random: Random(seed)),
        navigation: ProjectNavigationState.restore(
          mutations.current,
          activeBuildingId: buildingId,
          activeLevelId: levelId,
          selectedSpaceId: spaceId,
        ),
      );

  ProjectAggregateRoot project() => ProjectAggregateRoot(
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
        ),
      );
}
