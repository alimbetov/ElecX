import 'package:elecx/src/application/project/project_boundary_host_adoption.dart';
import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/domain/boundary_host_migration.dart';
import 'package:elecx/src/domain/boundary_host_registry.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/boundary_wall_profile_registry.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stale adoption cannot overwrite already adopted canonical hosts', () {
    final fixture = _Fixture();
    final initial = fixture.project();
    final mutations = ProjectMutationSession(initial);
    final adoption = ProjectBoundaryHostAdoptionService(mutations);

    final winnerKey = 'component:winner';
    final winner = adoption.adopt(
      spaceId: fixture.spaceId,
      expectedVersion: initial.version,
      hostedObjects: BoundaryHostedObjectRegistry({
        winnerKey: BoundaryHostedReference.point(
          objectKey: winnerKey,
          objectKind: BoundaryHostedObjectKind.component,
          host: BoundaryEdgeHostRef(
            spaceId: fixture.spaceId,
            edgeId: fixture.bottom,
          ),
          offsetMm: 1000,
        ),
      }),
      wallProfiles: const BoundaryWallProfileRegistry.empty(),
    );

    expect(winner, isNotNull);
    expect(mutations.current.version, LocalProjectVersion(1));
    expect(mutations.undoDepth, 1);

    final loserKey = 'component:loser';
    expect(
      () => adoption.adopt(
        spaceId: fixture.spaceId,
        expectedVersion: initial.version,
        hostedObjects: BoundaryHostedObjectRegistry({
          loserKey: BoundaryHostedReference.point(
            objectKey: loserKey,
            objectKind: BoundaryHostedObjectKind.component,
            host: BoundaryEdgeHostRef(
              spaceId: fixture.spaceId,
              edgeId: fixture.bottom,
            ),
            offsetMm: 2000,
          ),
        }),
        wallProfiles: const BoundaryWallProfileRegistry.empty(),
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

    expect(mutations.current.version, LocalProjectVersion(1));
    expect(mutations.undoDepth, 1);
    expect(
      mutations.current.engineeringMetadata.boundaryHostedObjectRegistry[
          winnerKey],
      isNotNull,
    );
    expect(
      mutations.current.engineeringMetadata.boundaryHostedObjectRegistry[
          loserKey],
      isNull,
    );
  });
}

final class _Fixture {
  final projectId = ProjectId('project-p7a6-adoption-race');
  final siteId = SiteId('site-p7a6-adoption-race');
  final buildingId = BuildingId('building-p7a6-adoption-race');
  final levelId = LevelId('level-p7a6-adoption-race');
  final spaceId = SpaceId('space-p7a6-adoption-race');
  final bottom = BoundaryEdgeId('bottom');
  final east = BoundaryEdgeId('east');
  final north = BoundaryEdgeId('north');
  final west = BoundaryEdgeId('west');

  ProjectAggregateRoot project() {
    final topology = SpaceBoundaryTopology(
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

    return ProjectAggregateRoot(
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
        boundaries: {spaceId: topology},
      ),
    );
  }
}
