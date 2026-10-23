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
  test('canonical version gap rematerializes winner before clearing history',
      () {
    final controller = EditorController.demo();
    addTearDown(controller.disposeDocumentHistory);
    addTearDown(controller.disposeP2State);
    addTearDown(controller.dispose);

    final fixture = _Fixture();
    final initial = fixture.project();
    final mutations = ProjectMutationSession(initial);
    final session = ProjectStructureAuthoringSession(
      mutations: mutations,
      idFactory: SecureRandomEntityIdFactory(random: Random(964)),
      navigation: ProjectNavigationState.restore(
        initial,
        activeBuildingId: fixture.buildingId,
        activeLevelId: fixture.levelId,
        selectedSpaceId: fixture.spaceId,
      ),
    );
    final history = controller.documentHistory;
    history.attachCanonicalSession(session, onReplayed: (_) {});

    final first = mutations.commit(
      ProjectMutationRequest(
        expectedVersion: initial.version,
        command: _RenameSpaceCommand(
          spaceId: fixture.spaceId,
          name: 'Recorded mutation',
        ),
      ),
    );
    expect(first, isNotNull);

    var rematerializeCount = 0;
    LocalProjectVersion? projectedVersion;
    history.recordCanonicalCommit(
      session: session,
      label: 'Recorded mutation',
      rematerialize: () {
        rematerializeCount++;
        projectedVersion = session.project.version;
      },
    );
    expect(history.undoDepth, 1);

    final winner = mutations.commit(
      ProjectMutationRequest(
        expectedVersion: session.project.version,
        command: _RenameSpaceCommand(
          spaceId: fixture.spaceId,
          name: 'Out-of-band winner',
        ),
      ),
    );
    expect(winner, isNotNull);
    expect(session.project.version, LocalProjectVersion(2));

    expect(history.undo(), isFalse);

    expect(rematerializeCount, 1);
    expect(projectedVersion, LocalProjectVersion(2));
    expect(history.undoDepth, 0);
    expect(history.redoDepth, 0);
    expect(session.project.version, LocalProjectVersion(2));
    expect(
      session.project.stores.spaces[fixture.spaceId]!.name,
      'Out-of-band winner',
    );
  });
}

final class _RenameSpaceCommand implements ProjectCommand {
  const _RenameSpaceCommand({required this.spaceId, required this.name});

  final SpaceId spaceId;
  final String name;

  @override
  String get commandType => 'p7a6.historyGapRename';

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
  final projectId = ProjectId('project-p7a6-history-gap');
  final siteId = SiteId('site-p7a6-history-gap');
  final buildingId = BuildingId('building-p7a6-history-gap');
  final levelId = LevelId('level-p7a6-history-gap');
  final spaceId = SpaceId('space-p7a6-history-gap');

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
