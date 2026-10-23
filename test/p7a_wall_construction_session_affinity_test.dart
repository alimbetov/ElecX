import 'dart:math';

import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_structure_authoring.dart';
import 'package:elecx/src/domain/boundary_construction_registry.dart';
import 'package:elecx/src/domain/boundary_edge_identity_registry.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_model.dart';
import 'package:elecx/src/domain/project_orientation.dart';
import 'package:elecx/src/features/editor/canonical_editor_runtime_cutover.dart';
import 'package:elecx/src/features/editor/canonical_editor_screen_cutover_binding.dart';
import 'package:elecx/src/features/editor/canonical_editor_workspace_adapter.dart';
import 'package:elecx/src/features/editor/canonical_wall_construction_runtime.dart';
import 'package:elecx/src/features/editor/editor_building_workspace.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_document_history.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:elecx/src/features/editor/wall_construction_edit_contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P7A wall construction session affinity', () {
    test(
      'history listener replacing session at same numeric version fails closed',
      () {
        final fixture = _Fixture();
        addTearDown(fixture.dispose);
        final binding = fixture.bind();
        addTearDown(binding.dispose);

        fixture.controller.showWall(0);
        expect(
          CanonicalWallConstructionRuntime.activeWall(fixture.controller),
          isNotNull,
        );

        ProjectStructureAuthoringSession? replacement;
        var switched = false;
        void switchSessionAfterCanonicalRegistration() {
          if (switched || fixture.session.project.version.value != 1) return;
          switched = true;
          replacement = fixture.cloneCurrentSession(seed: 1202);
          fixture.controller.documentHistory.attachCanonicalSession(
            replacement!,
            onReplayed: (_) {},
          );
        }

        fixture.controller.documentHistory
            .addListener(switchSessionAfterCanonicalRegistration);
        addTearDown(
          () => fixture.controller.documentHistory
              .removeListener(switchSessionAfterCanonicalRegistration),
        );

        expect(
          () => CanonicalWallConstructionRuntime.setActiveWallConstruction(
            controller: fixture.controller,
            thicknessMm: 200,
            materialId: 'brick',
          ),
          throwsA(
            isA<CanonicalWallConstructionEditException>().having(
              (error) => error.message,
              'message',
              contains('session affinity'),
            ),
          ),
        );

        expect(switched, isTrue);
        expect(replacement, isNotNull);
        expect(fixture.session.project.version, LocalProjectVersion(1));
        expect(replacement!.project.version, LocalProjectVersion(1));
        expect(
          fixture.controller.documentHistory
              .hasCanonicalSessionAffinity(replacement!),
          isTrue,
        );
        expect(
          fixture.controller.documentHistory
              .hasCanonicalSessionAffinity(fixture.session),
          isFalse,
        );
        expect(fixture.controller.documentHistory.undoDepth, 0);
        expect(fixture.controller.documentHistory.redoDepth, 0);
      },
    );

    test('stale 180 mm baseline cannot overwrite external 200 mm edit', () {
      final fixture = _Fixture();
      addTearDown(fixture.dispose);
      final binding = fixture.bind();
      addTearDown(binding.dispose);
      fixture.controller.showWall(0);

      expect(
        CanonicalWallConstructionRuntime.setActiveWallConstruction(
          controller: fixture.controller,
          thicknessMm: 180,
          materialId: 'brick',
        ),
        isTrue,
      );
      final baseline =
          CanonicalWallConstructionEditContract.capture(fixture.controller)!;
      expect(baseline.profile!.thicknessMm, 180);
      expect(baseline.expectedVersion, LocalProjectVersion(1));

      expect(
        CanonicalWallConstructionRuntime.setActiveWallConstruction(
          controller: fixture.controller,
          thicknessMm: 200,
          materialId: 'brick',
        ),
        isTrue,
      );
      expect(fixture.session.project.version, LocalProjectVersion(2));

      expect(
        () => CanonicalWallConstructionEditContract.save(
          controller: fixture.controller,
          baseline: baseline,
          profile: BoundaryConstructionProfile(
            kind: BoundaryConstructionKind.wall,
            thicknessMm: 190,
            materialId: 'brick',
          ),
        ),
        throwsA(
          isA<CanonicalWallConstructionEditConflictException>().having(
            (error) => error.message,
            'message',
            contains('advanced from version 1 to 2'),
          ),
        ),
      );

      final current =
          CanonicalWallConstructionEditContract.capture(fixture.controller)!;
      expect(current.profile!.thicknessMm, 200);
      expect(current.expectedVersion, LocalProjectVersion(2));
    });

    test('same numeric version in replacement session does not own old draft',
        () {
      final fixture = _Fixture();
      addTearDown(fixture.dispose);
      final firstBinding = fixture.bind();
      fixture.controller.showWall(0);

      expect(
        CanonicalWallConstructionRuntime.setActiveWallConstruction(
          controller: fixture.controller,
          thicknessMm: 180,
          materialId: 'brick',
        ),
        isTrue,
      );
      final baseline =
          CanonicalWallConstructionEditContract.capture(fixture.controller)!;
      final replacement = fixture.cloneCurrentSession(seed: 1203);
      expect(replacement.project.version, baseline.expectedVersion);

      firstBinding.dispose();
      final replacementBinding = fixture.bindSession(replacement);
      addTearDown(replacementBinding.dispose);
      fixture.controller.showWall(0);

      expect(
        () => CanonicalWallConstructionEditContract.save(
          controller: fixture.controller,
          baseline: baseline,
          profile: BoundaryConstructionProfile(
            kind: BoundaryConstructionKind.wall,
            thicknessMm: 200,
            materialId: 'brick',
          ),
        ),
        throwsA(
          isA<CanonicalWallConstructionEditConflictException>().having(
            (error) => error.message,
            'message',
            contains('session changed'),
          ),
        ),
      );
      expect(replacement.project.version, LocalProjectVersion(1));
      expect(
        CanonicalWallConstructionEditContract.capture(fixture.controller)!
            .profile!
            .thicknessMm,
        180,
      );
    });
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
      projectName: 'P7A wall construction session affinity',
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
    session = _session(ProjectMutationSession(project), seed: 1201);
  }

  CanonicalEditorScreenCutoverBinding bind() => bindSession(session);

  CanonicalEditorScreenCutoverBinding bindSession(
    ProjectStructureAuthoringSession targetSession,
  ) {
    final coordinator = CanonicalEditorRuntimeCutoverCoordinator(
      session: targetSession,
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

  ProjectStructureAuthoringSession cloneCurrentSession({required int seed}) =>
      _session(ProjectMutationSession(session.project), seed: seed);

  ProjectStructureAuthoringSession _session(
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
  late final ProjectStructureAuthoringSession session;
}
