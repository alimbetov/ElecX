import 'package:elecx/src/application/project/project_boundary_host_adoption.dart';
import 'package:elecx/src/application/project/project_boundary_topology_migration.dart';
import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/domain/boundary_host_registry.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/boundary_wall_profile_registry.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P7A-6.1 stale-version and concurrent mutation races', () {
    test('stale split cannot commit after unrelated canonical mutation', () {
      final fixture = _Fixture();
      final initial = fixture.project();
      final mutations = ProjectMutationSession(initial);
      final edit = ProjectBoundaryTopologyMigrationService(mutations).begin(
        spaceId: fixture.spaceId,
        expectedVersion: initial.version,
      );

      edit.previewSplitEdge(
        sourceEdgeId: fixture.bottom,
        splitPoint: const BoundaryPointMm(xMm: 2000, yMm: 0),
        firstResultEdgeId: fixture.bottomA,
        secondResultEdgeId: fixture.bottomB,
      );

      final unrelated = mutations.commit(
        ProjectMutationRequest(
          expectedVersion: initial.version,
          command: _RenameSpaceCommand(
            spaceId: fixture.spaceId,
            name: 'Room renamed',
          ),
        ),
      );
      expect(unrelated, isNotNull);
      expect(mutations.current.version, LocalProjectVersion(1));
      expect(mutations.undoDepth, 1);

      expect(
        edit.commit,
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
      expect(mutations.undoDepth, 1);
      expect(
        mutations.current.index.boundary(fixture.spaceId)!.orderedEdgeIds,
        [fixture.bottom, fixture.east, fixture.north, fixture.west],
      );
      expect(mutations.current.stores.spaces[fixture.spaceId]!.name,
          'Room renamed');
    });

    test('only first of two same-version split sessions may commit', () {
      final fixture = _Fixture();
      final initial = fixture.project();
      final mutations = ProjectMutationSession(initial);
      final migration = ProjectBoundaryTopologyMigrationService(mutations);

      final first = migration.begin(
        spaceId: fixture.spaceId,
        expectedVersion: initial.version,
      );
      final second = migration.begin(
        spaceId: fixture.spaceId,
        expectedVersion: initial.version,
      );

      first.previewSplitEdge(
        sourceEdgeId: fixture.bottom,
        splitPoint: const BoundaryPointMm(xMm: 2000, yMm: 0),
        firstResultEdgeId: fixture.bottomA,
        secondResultEdgeId: fixture.bottomB,
      );
      second.previewSplitEdge(
        sourceEdgeId: fixture.bottom,
        splitPoint: const BoundaryPointMm(xMm: 1000, yMm: 0),
        firstResultEdgeId: BoundaryEdgeId('bottom-c'),
        secondResultEdgeId: BoundaryEdgeId('bottom-d'),
      );

      final committed = first.commit();
      expect(committed, isNotNull);
      expect(mutations.current.version, LocalProjectVersion(1));
      expect(mutations.undoDepth, 1);

      expect(second.commit, throwsA(isA<StaleProjectMutationException>()));
      expect(mutations.current.version, LocalProjectVersion(1));
      expect(mutations.undoDepth, 1);
      expect(
        mutations.current.index
            .boundary(fixture.spaceId)!
            .orderedEdgeIds
            .take(2),
        [fixture.bottomA, fixture.bottomB],
      );
    });

    test('stale merge cannot commit after unrelated canonical mutation', () {
      final fixture = _Fixture();
      final initial = fixture.project(boundary: fixture.splitBoundary());
      final mutations = ProjectMutationSession(initial);
      final edit = ProjectBoundaryTopologyMigrationService(mutations).begin(
        spaceId: fixture.spaceId,
        expectedVersion: initial.version,
      );

      edit.previewMergeAdjacentEdges(
        firstSourceEdgeId: fixture.bottomA,
        secondSourceEdgeId: fixture.bottomB,
        resultEdgeId: fixture.bottomMerged,
      );

      mutations.commit(
        ProjectMutationRequest(
          expectedVersion: initial.version,
          command: _RenameSpaceCommand(
            spaceId: fixture.spaceId,
            name: 'Room renamed',
          ),
        ),
      );

      expect(edit.commit, throwsA(isA<StaleProjectMutationException>()));
      expect(mutations.current.version, LocalProjectVersion(1));
      expect(mutations.undoDepth, 1);
      expect(
        mutations.current.index
            .boundary(fixture.spaceId)!
            .orderedEdgeIds
            .take(2),
        [fixture.bottomA, fixture.bottomB],
      );
    });

    test('stale host adoption cannot overwrite newer canonical project', () {
      final fixture = _Fixture();
      final initial = fixture.project();
      final mutations = ProjectMutationSession(initial);
      final adoption = ProjectBoundaryHostAdoptionService(mutations);

      mutations.commit(
        ProjectMutationRequest(
          expectedVersion: initial.version,
          command: _RenameSpaceCommand(
            spaceId: fixture.spaceId,
            name: 'Room renamed',
          ),
        ),
      );

      expect(
        () => adoption.adopt(
          spaceId: fixture.spaceId,
          expectedVersion: initial.version,
          hostedObjects: const BoundaryHostedObjectRegistry.empty(),
          wallProfiles: const BoundaryWallProfileRegistry.empty(),
        ),
        throwsA(isA<StaleProjectMutationException>()),
      );
      expect(mutations.current.version, LocalProjectVersion(1));
      expect(mutations.undoDepth, 1);
      expect(
        mutations.current.engineeringMetadata.boundaryHostedObjectRegistry
            .forSpace(fixture.spaceId),
        isEmpty,
      );
      expect(
        mutations.current.engineeringMetadata.boundaryWallProfileRegistry
            .forSpace(fixture.spaceId),
        isEmpty,
      );
    });
  });
}

final class _RenameSpaceCommand implements ProjectCommand {
  const _RenameSpaceCommand({required this.spaceId, required this.name});

  final SpaceId spaceId;
  final String name;

  @override
  String get commandType => 'p7a6.renameSpaceRaceAdvance';

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
  final projectId = ProjectId('project-p7a6-race');
  final siteId = SiteId('site-p7a6-race');
  final buildingId = BuildingId('building-p7a6-race');
  final levelId = LevelId('level-p7a6-race');
  final spaceId = SpaceId('space-p7a6-race');

  final bottom = BoundaryEdgeId('bottom');
  final bottomA = BoundaryEdgeId('bottom-a');
  final bottomB = BoundaryEdgeId('bottom-b');
  final bottomMerged = BoundaryEdgeId('bottom-merged');
  final east = BoundaryEdgeId('east');
  final north = BoundaryEdgeId('north');
  final west = BoundaryEdgeId('west');

  ProjectAggregateRoot project({SpaceBoundaryTopology? boundary}) =>
      ProjectAggregateRoot(
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
          boundaries: {spaceId: boundary ?? initialBoundary()},
        ),
      );

  SpaceBoundaryTopology initialBoundary() => SpaceBoundaryTopology(
        spaceId: spaceId,
        orderedEdgeIds: [bottom, east, north, west],
        edges: {
          bottom: ProjectBoundaryEdge(
            id: bottom,
            spaceId: spaceId,
            start: const BoundaryPointMm(xMm: 0, yMm: 0),
            end: const BoundaryPointMm(xMm: 4000, yMm: 0),
          ),
          east: ProjectBoundaryEdge(
            id: east,
            spaceId: spaceId,
            start: const BoundaryPointMm(xMm: 4000, yMm: 0),
            end: const BoundaryPointMm(xMm: 4000, yMm: 3000),
          ),
          north: ProjectBoundaryEdge(
            id: north,
            spaceId: spaceId,
            start: const BoundaryPointMm(xMm: 4000, yMm: 3000),
            end: const BoundaryPointMm(xMm: 0, yMm: 3000),
          ),
          west: ProjectBoundaryEdge(
            id: west,
            spaceId: spaceId,
            start: const BoundaryPointMm(xMm: 0, yMm: 3000),
            end: const BoundaryPointMm(xMm: 0, yMm: 0),
          ),
        },
      );

  SpaceBoundaryTopology splitBoundary() => SpaceBoundaryTopology(
        spaceId: spaceId,
        orderedEdgeIds: [bottomA, bottomB, east, north, west],
        edges: {
          bottomA: ProjectBoundaryEdge(
            id: bottomA,
            spaceId: spaceId,
            start: const BoundaryPointMm(xMm: 0, yMm: 0),
            end: const BoundaryPointMm(xMm: 2000, yMm: 0),
          ),
          bottomB: ProjectBoundaryEdge(
            id: bottomB,
            spaceId: spaceId,
            start: const BoundaryPointMm(xMm: 2000, yMm: 0),
            end: const BoundaryPointMm(xMm: 4000, yMm: 0),
          ),
          east: ProjectBoundaryEdge(
            id: east,
            spaceId: spaceId,
            start: const BoundaryPointMm(xMm: 4000, yMm: 0),
            end: const BoundaryPointMm(xMm: 4000, yMm: 3000),
          ),
          north: ProjectBoundaryEdge(
            id: north,
            spaceId: spaceId,
            start: const BoundaryPointMm(xMm: 4000, yMm: 3000),
            end: const BoundaryPointMm(xMm: 0, yMm: 3000),
          ),
          west: ProjectBoundaryEdge(
            id: west,
            spaceId: spaceId,
            start: const BoundaryPointMm(xMm: 0, yMm: 3000),
            end: const BoundaryPointMm(xMm: 0, yMm: 0),
          ),
        },
      );
}
