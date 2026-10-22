import 'dart:math';

import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_structure_authoring.dart';
import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_document_history.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P7A-6.1 deep unified-history race hardening', () {
    test('hidden canonical gap blocks P2 undo sitting above stale P3 history',
        () {
      final controller = EditorController.demo();
      addTearDown(controller.disposeDocumentHistory);
      addTearDown(controller.disposeP2State);
      addTearDown(controller.dispose);

      final fixture = _Fixture();
      final initial = fixture.project();
      final mutations = ProjectMutationSession(initial);
      final session = fixture.session(mutations, seed: 971);
      final history = controller.documentHistory;
      history.attachCanonicalSession(session, onReplayed: (_) {});

      final recorded = mutations.commit(
        ProjectMutationRequest(
          expectedVersion: initial.version,
          command: _RenameSpaceCommand(
            spaceId: fixture.spaceId,
            name: 'Recorded canonical mutation',
          ),
        ),
      );
      expect(recorded, isNotNull);
      history.recordCanonicalCommit(
        session: session,
        label: 'Recorded canonical mutation',
        rematerialize: () {},
      );
      expect(history.undoDepth, 1);
      expect(history.canUndo, isTrue);

      final outOfBand = mutations.commit(
        ProjectMutationRequest(
          expectedVersion: session.project.version,
          command: _RenameSpaceCommand(
            spaceId: fixture.spaceId,
            name: 'Hidden canonical winner',
          ),
        ),
      );
      expect(outOfBand, isNotNull);
      expect(session.project.version, LocalProjectVersion(2));

      controller.showWall(0);
      final component = controller.p2.placeComponent(
        type: ElectricalComponentType.socketOutlet,
        surface: controller.activeSurface!,
        position: const SurfacePointMm(600, 300),
      );
      expect(history.undoDepth, 2,
          reason: 'the P2 listener has not yet reconciled the hidden P3 gap');
      expect(history.canUndo, isFalse,
          reason: 'UI must not advertise replay through a canonical gap');

      expect(history.undo(), isFalse);
      expect(history.undoDepth, 0);
      expect(history.redoDepth, 0);
      expect(controller.p2.components.single.id, component.id,
          reason: 'the newer P2 edit must not be replayed through hidden P3');
      expect(session.project.version, LocalProjectVersion(2));
      expect(
        session.project.stores.spaces[fixture.spaceId]!.name,
        'Hidden canonical winner',
      );
    });

    test('canonical replay owner runs even when rematerialization fails', () {
      final controller = EditorController.demo();
      addTearDown(controller.disposeDocumentHistory);
      addTearDown(controller.disposeP2State);
      addTearDown(controller.dispose);

      final fixture = _Fixture();
      final initial = fixture.project();
      final mutations = ProjectMutationSession(initial);
      final session = fixture.session(mutations, seed: 972);
      final history = controller.documentHistory;

      var ownerCalls = 0;
      LocalProjectVersion? ownerVersion;
      history.attachCanonicalSession(
        session,
        onReplayed: (result) {
          ownerCalls++;
          ownerVersion = result.project.version;
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
          throw StateError('synthetic projection failure');
        },
      );

      expect(history.undo(), isFalse,
          reason: 'projection failure invalidates the unsafe unified timeline');
      expect(ownerCalls, 1,
          reason: 'persistence owner must see the already-committed undo');
      expect(ownerVersion, LocalProjectVersion(2));
      expect(session.project.version, LocalProjectVersion(2));
      expect(session.project.stores.spaces[fixture.spaceId]!.name, 'Room');
      expect(history.undoDepth, 0);
      expect(history.redoDepth, 0);
    });
  });
}

final class _RenameSpaceCommand implements ProjectCommand {
  const _RenameSpaceCommand({required this.spaceId, required this.name});

  final SpaceId spaceId;
  final String name;

  @override
  String get commandType => 'p7a61.deepHistoryRename';

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
  final projectId = ProjectId('project-p7a61-deep-history');
  final siteId = SiteId('site-p7a61-deep-history');
  final buildingId = BuildingId('building-p7a61-deep-history');
  final levelId = LevelId('level-p7a61-deep-history');
  final spaceId = SpaceId('space-p7a61-deep-history');

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
