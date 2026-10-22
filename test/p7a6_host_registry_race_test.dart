import 'package:elecx/src/application/project/project_boundary_host_adoption.dart';
import 'package:elecx/src/application/project/project_boundary_topology_migration.dart';
import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/domain/boundary_host_migration.dart';
import 'package:elecx/src/domain/boundary_host_registry.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/boundary_wall_profile_registry.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stale merge cannot overwrite newer hosted registry adoption', () {
    final fixture = _Fixture();
    final initial = fixture.project();
    final mutations = ProjectMutationSession(initial);
    final migration = ProjectBoundaryTopologyMigrationService(mutations);

    final merge = migration.begin(
      spaceId: fixture.spaceId,
      expectedVersion: initial.version,
    );
    merge.previewMergeAdjacentEdges(
      firstSourceEdgeId: fixture.bottomA,
      secondSourceEdgeId: fixture.bottomB,
      resultEdgeId: fixture.bottomMerged,
    );

    final hostKey = 'component:race';
    final adopted = ProjectBoundaryHostAdoptionService(mutations).adopt(
      spaceId: fixture.spaceId,
      expectedVersion: initial.version,
      hostedObjects: BoundaryHostedObjectRegistry({
        hostKey: BoundaryHostedReference.point(
          objectKey: hostKey,
          objectKind: BoundaryHostedObjectKind.component,
          host: BoundaryEdgeHostRef(
            spaceId: fixture.spaceId,
            edgeId: fixture.bottomA,
          ),
          offsetMm: 1000,
        ),
      }),
      wallProfiles: const BoundaryWallProfileRegistry.empty(),
    );

    expect(adopted, isNotNull);
    expect(mutations.current.version, LocalProjectVersion(1));
    expect(mutations.undoDepth, 1);
    expect(
      mutations.current.engineeringMetadata
          .boundaryHostedObjectRegistry[hostKey]?.host.edgeId,
      fixture.bottomA,
    );

    expect(
      merge.commit,
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
      [
        fixture.bottomA,
        fixture.bottomB,
        fixture.east,
        fixture.north,
        fixture.west,
      ],
    );
    expect(
      mutations.current.engineeringMetadata
          .boundaryHostedObjectRegistry[hostKey]?.host.edgeId,
      fixture.bottomA,
      reason: 'the winning hosted-registry mutation must remain authoritative',
    );
  });
}

final class _Fixture {
  final projectId = ProjectId('project-p7a6-host-race');
  final siteId = SiteId('site-p7a6-host-race');
  final buildingId = BuildingId('building-p7a6-host-race');
  final levelId = LevelId('level-p7a6-host-race');
  final spaceId = SpaceId('space-p7a6-host-race');

  final bottomA = BoundaryEdgeId('bottom-a');
  final bottomB = BoundaryEdgeId('bottom-b');
  final bottomMerged = BoundaryEdgeId('bottom-merged');
  final east = BoundaryEdgeId('east');
  final north = BoundaryEdgeId('north');
  final west = BoundaryEdgeId('west');

  ProjectAggregateRoot project() {
    final topology = SpaceBoundaryTopology(
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
