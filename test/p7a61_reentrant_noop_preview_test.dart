import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P7A-6.1 mutation-core reentrant gaps', () {
    test('reentrant no-op commit cannot hide a newer canonical writer', () {
      final fixture = _Fixture();
      final initial = fixture.project();
      final mutations = ProjectMutationSession(initial);
      var reentered = false;

      expect(
        () => mutations.commit(
          ProjectMutationRequest(
            expectedVersion: initial.version,
            command: _ReentrantNoopCommand(
              onBuild: () {
                if (reentered) return;
                reentered = true;
                final winner = mutations.commit(
                  ProjectMutationRequest(
                    expectedVersion: initial.version,
                    command: _RenameSpaceCommand(
                      spaceId: fixture.spaceId,
                      name: 'Nested winner',
                    ),
                  ),
                );
                expect(winner, isNotNull);
              },
            ),
          ),
        ),
        throwsA(isA<StaleProjectMutationException>()),
      );

      expect(mutations.current.version, LocalProjectVersion(1));
      expect(
        mutations.current.stores.spaces[fixture.spaceId]!.name,
        'Nested winner',
      );
      expect(mutations.undoDepth, 1);
    });

    test('preview cannot return a candidate after reentrant version advance',
        () {
      final fixture = _Fixture();
      final initial = fixture.project();
      final mutations = ProjectMutationSession(initial);
      var reentered = false;

      expect(
        () => mutations.preview(
          ProjectMutationRequest(
            expectedVersion: initial.version,
            command: _ReentrantNoopCommand(
              onBuild: () {
                if (reentered) return;
                reentered = true;
                final winner = mutations.commit(
                  ProjectMutationRequest(
                    expectedVersion: initial.version,
                    command: _RenameSpaceCommand(
                      spaceId: fixture.spaceId,
                      name: 'Preview nested winner',
                    ),
                  ),
                );
                expect(winner, isNotNull);
              },
            ),
          ),
        ),
        throwsA(isA<StaleProjectMutationException>()),
      );

      expect(mutations.current.version, LocalProjectVersion(1));
      expect(
        mutations.current.stores.spaces[fixture.spaceId]!.name,
        'Preview nested winner',
      );
      expect(mutations.undoDepth, 1);
    });
  });
}

final class _ReentrantNoopCommand implements ProjectCommand {
  const _ReentrantNoopCommand({required this.onBuild});

  final void Function() onBuild;

  @override
  String get commandType => 'p7a61.reentrantNoop';

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) {
    onBuild();
    return ProjectCommandCandidate.fromState(
      state: ProjectMutableState.fromProject(current),
    );
  }
}

final class _RenameSpaceCommand implements ProjectCommand {
  const _RenameSpaceCommand({required this.spaceId, required this.name});

  final SpaceId spaceId;
  final String name;

  @override
  String get commandType => 'p7a61.reentrantWinner';

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
  final projectId = ProjectId('project-p7a61-reentrant-noop');
  final siteId = SiteId('site-p7a61-reentrant-noop');
  final buildingId = BuildingId('building-p7a61-reentrant-noop');
  final levelId = LevelId('level-p7a61-reentrant-noop');
  final spaceId = SpaceId('space-p7a61-reentrant-noop');

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
