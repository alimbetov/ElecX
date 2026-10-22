import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P7A-6.1 reentrant mutation and history races', () {
    test('outer commit fails closed when candidate build advances version', () {
      final fixture = _Fixture();
      final initial = fixture.project();
      final mutations = ProjectMutationSession(initial);
      var reentered = false;

      expect(
        () => mutations.commit(
          ProjectMutationRequest(
            expectedVersion: initial.version,
            command: _ReentrantRenameCommand(
              spaceId: fixture.spaceId,
              outerName: 'Outer stale rename',
              onBuild: () {
                if (reentered) return;
                reentered = true;
                final nested = mutations.commit(
                  ProjectMutationRequest(
                    expectedVersion: initial.version,
                    command: _RenameSpaceCommand(
                      spaceId: fixture.spaceId,
                      name: 'Nested winner',
                    ),
                  ),
                );
                expect(nested, isNotNull);
              },
            ),
          ),
        ),
        throwsA(
          isA<StaleProjectMutationException>()
              .having(
                (error) => error.expectedVersion,
                'expectedVersion',
                LocalProjectVersion(0),
              )
              .having(
                (error) => error.currentVersion,
                'currentVersion',
                LocalProjectVersion(1),
              ),
        ),
      );

      expect(reentered, isTrue);
      expect(mutations.current.version, LocalProjectVersion(1));
      expect(mutations.current.stores.spaces[fixture.spaceId]!.name,
          'Nested winner');
      expect(mutations.undoDepth, 1);
      expect(mutations.redoDepth, 0);
    });

    test('stale undo cannot revert a newer canonical version', () {
      final fixture = _Fixture();
      final initial = fixture.project();
      final mutations = ProjectMutationSession(initial);

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
      expect(mutations.current.version, LocalProjectVersion(1));

      expect(
        () => mutations.undo(initial.version),
        throwsA(
          isA<StaleProjectMutationException>()
              .having(
                (error) => error.expectedVersion,
                'expectedVersion',
                LocalProjectVersion(0),
              )
              .having(
                (error) => error.currentVersion,
                'currentVersion',
                LocalProjectVersion(1),
              ),
        ),
      );

      expect(mutations.current.version, LocalProjectVersion(1));
      expect(mutations.current.stores.spaces[fixture.spaceId]!.name,
          'Version one');
      expect(mutations.undoDepth, 1);
      expect(mutations.redoDepth, 0);
    });

    test('stale redo cannot replay after undo advanced the project version',
        () {
      final fixture = _Fixture();
      final initial = fixture.project();
      final mutations = ProjectMutationSession(initial);

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

      final undone = mutations.undo(mutations.current.version);
      expect(undone, isNotNull);
      expect(mutations.current.version, LocalProjectVersion(2));
      expect(mutations.redoDepth, 1);

      expect(
        () => mutations.redo(LocalProjectVersion(1)),
        throwsA(
          isA<StaleProjectMutationException>()
              .having(
                (error) => error.expectedVersion,
                'expectedVersion',
                LocalProjectVersion(1),
              )
              .having(
                (error) => error.currentVersion,
                'currentVersion',
                LocalProjectVersion(2),
              ),
        ),
      );

      expect(mutations.current.version, LocalProjectVersion(2));
      expect(mutations.current.stores.spaces[fixture.spaceId]!.name, 'Room');
      expect(mutations.undoDepth, 0);
      expect(mutations.redoDepth, 1);
    });
  });
}

final class _ReentrantRenameCommand implements ProjectCommand {
  const _ReentrantRenameCommand({
    required this.spaceId,
    required this.outerName,
    required this.onBuild,
  });

  final SpaceId spaceId;
  final String outerName;
  final void Function() onBuild;

  @override
  String get commandType => 'p7a6.reentrantRename';

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) {
    onBuild();
    // The candidate is deliberately built from the stale `current` captured by
    // the outer commit. The second version check in ProjectMutationSession must
    // reject it after the nested mutation advances the authoritative session.
    final source = current.stores.spaces[spaceId]!;
    return ProjectCommandCandidate.fromState(
      state: ProjectMutableState(
        engineeringMetadata: current.engineeringMetadata,
        stores: _replaceSpace(
          current,
          ProjectSpaceEntity(
            id: source.id,
            levelId: source.levelId,
            name: outerName,
            usage: source.usage,
          ),
        ),
      ),
      affectedEntityIds: <EntityId>{spaceId},
    );
  }
}

final class _RenameSpaceCommand implements ProjectCommand {
  const _RenameSpaceCommand({required this.spaceId, required this.name});

  final SpaceId spaceId;
  final String name;

  @override
  String get commandType => 'p7a6.renameSpace';

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) {
    final source = current.stores.spaces[spaceId]!;
    return ProjectCommandCandidate.fromState(
      state: ProjectMutableState(
        engineeringMetadata: current.engineeringMetadata,
        stores: _replaceSpace(
          current,
          ProjectSpaceEntity(
            id: source.id,
            levelId: source.levelId,
            name: name,
            usage: source.usage,
          ),
        ),
      ),
      affectedEntityIds: <EntityId>{spaceId},
    );
  }
}

ProjectEntityStores _replaceSpace(
  ProjectAggregateRoot current,
  ProjectSpaceEntity replacement,
) =>
    ProjectEntityStores(
      sites: current.stores.sites,
      buildings: current.stores.buildings,
      levels: current.stores.levels,
      zones: current.stores.zones,
      spaces: {
        ...current.stores.spaces,
        replacement.id: replacement,
      },
      openings: current.stores.openings,
      adjacencies: current.stores.adjacencies,
      overlays: current.stores.overlays,
      boundaries: current.stores.boundaries,
    );

final class _Fixture {
  final projectId = ProjectId('project-p7a6-reentrant');
  final siteId = SiteId('site-p7a6-reentrant');
  final buildingId = BuildingId('building-p7a6-reentrant');
  final levelId = LevelId('level-p7a6-reentrant');
  final spaceId = SpaceId('space-p7a6-reentrant');

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
