import 'dart:math';

import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_structure_authoring.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_document_history.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('switching canonical session invalidates foreign unified history', () {
    final controller = EditorController.demo();
    addTearDown(controller.disposeDocumentHistory);
    addTearDown(controller.disposeP2State);
    addTearDown(controller.dispose);

    final fixtureA = _Fixture('a');
    final sessionA = fixtureA.session(seed: 965);
    final history = controller.documentHistory;
    history.attachCanonicalSession(sessionA, onReplayed: (_) {});

    final committed = sessionA.mutations.commit(
      ProjectMutationRequest(
        expectedVersion: sessionA.project.version,
        command: _RenameSpaceCommand(
          spaceId: fixtureA.spaceId,
          name: 'Session A mutation',
        ),
      ),
    );
    expect(committed, isNotNull);
    history.recordCanonicalCommit(
      session: sessionA,
      label: 'Session A mutation',
      rematerialize: () {},
    );
    expect(history.undoDepth, 1);

    final fixtureB = _Fixture('b');
    final sessionB = fixtureB.session(seed: 966);
    history.attachCanonicalSession(sessionB, onReplayed: (_) {});

    expect(history.undoDepth, 0);
    expect(history.redoDepth, 0);
    expect(history.canUndo, isFalse);
    expect(history.undo(), isFalse);
    expect(sessionA.project.version, LocalProjectVersion(1));
    expect(sessionB.project.version, LocalProjectVersion(0));
    expect(
      sessionA.project.stores.spaces[fixtureA.spaceId]!.name,
      'Session A mutation',
    );
    expect(
      sessionB.project.stores.spaces[fixtureB.spaceId]!.name,
      'Room b',
    );
  });
}

final class _RenameSpaceCommand implements ProjectCommand {
  const _RenameSpaceCommand({required this.spaceId, required this.name});

  final SpaceId spaceId;
  final String name;

  @override
  String get commandType => 'p7a6.sessionAffinityRename';

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
  _Fixture(this.suffix)
      : projectId = ProjectId('project-p7a6-affinity-$suffix'),
        siteId = SiteId('site-p7a6-affinity-$suffix'),
        buildingId = BuildingId('building-p7a6-affinity-$suffix'),
        levelId = LevelId('level-p7a6-affinity-$suffix'),
        spaceId = SpaceId('space-p7a6-affinity-$suffix');

  final String suffix;
  final ProjectId projectId;
  final SiteId siteId;
  final BuildingId buildingId;
  final LevelId levelId;
  final SpaceId spaceId;

  ProjectAggregateRoot project() => ProjectAggregateRoot(
        id: projectId,
        siteId: siteId,
        version: LocalProjectVersion(0),
        stores: ProjectEntityStores(
          sites: {
            siteId: ProjectSiteEntity(
              id: siteId,
              name: 'Site $suffix',
              buildingIds: [buildingId],
            ),
          },
          buildings: {
            buildingId: ProjectBuildingEntity(
              id: buildingId,
              siteId: siteId,
              name: 'Building $suffix',
              levelIds: [levelId],
            ),
          },
          levels: {
            levelId: ProjectLevelEntity(
              id: levelId,
              buildingId: buildingId,
              name: 'Level $suffix',
              levelNumber: 1,
              elevationMm: 0,
              spaceIds: [spaceId],
            ),
          },
          spaces: {
            spaceId: ProjectSpaceEntity(
              id: spaceId,
              levelId: levelId,
              name: 'Room $suffix',
            ),
          },
        ),
      );

  ProjectStructureAuthoringSession session({required int seed}) {
    final aggregate = project();
    return ProjectStructureAuthoringSession(
      mutations: ProjectMutationSession(aggregate),
      idFactory: SecureRandomEntityIdFactory(random: Random(seed)),
      navigation: ProjectNavigationState.restore(
        aggregate,
        activeBuildingId: buildingId,
        activeLevelId: levelId,
        selectedSpaceId: spaceId,
      ),
    );
  }
}
