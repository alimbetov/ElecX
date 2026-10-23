import 'package:elecx/src/application/project/project_boundary_topology_migration.dart';
import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/domain/boundary_host_migration.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/boundary_wall_profile_registry.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_orientation.dart';
import 'package:elecx/src/domain/wall_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('replace topology cannot mutate wall profiles owned by another space',
      () {
    final fixture = _Fixture();
    final initial = fixture.project();
    final mutations = ProjectMutationSession(initial);
    final edit = ProjectBoundaryTopologyMigrationService(mutations).begin(
      spaceId: fixture.spaceA,
      expectedVersion: initial.version,
    );

    expect(
      () => edit.previewReplaceTopology(
        topology: fixture.boundaryA,
        lineage: BoundaryTopologyChangeSet([
          for (final edgeId in fixture.boundaryA.orderedEdgeIds)
            BoundaryEdgeLineage.preserved(edgeId),
        ]),
        wallProfiles: const BoundaryWallProfileRegistry.empty(),
      ),
      throwsA(
        isA<BoundaryTopologyMigrationException>().having(
          (error) => error.code,
          'code',
          BoundaryTopologyMigrationIssueCode.wallProfileScopeViolation,
        ),
      ),
    );

    expect(mutations.current, same(initial));
    expect(mutations.undoDepth, 0);
  });
}

final class _Fixture {
  final projectId = ProjectId('project-p7a5-space-isolation');
  final siteId = SiteId('site');
  final buildingId = BuildingId('building');
  final levelId = LevelId('level');
  final spaceA = SpaceId('space-a');
  final spaceB = SpaceId('space-b');

  late final SpaceBoundaryTopology boundaryA = _rectangle(
    spaceA,
    const ['a-bottom', 'a-right', 'a-top', 'a-left'],
  );
  late final SpaceBoundaryTopology boundaryB = _rectangle(
    spaceB,
    const ['b-bottom', 'b-right', 'b-top', 'b-left'],
  );

  ProjectAggregateRoot project() {
    final foreignHost = BoundaryEdgeHostRef(
      spaceId: spaceB,
      edgeId: boundaryB.orderedEdgeIds.first,
    );
    return ProjectAggregateRoot(
      id: projectId,
      siteId: siteId,
      version: LocalProjectVersion(0),
      engineeringMetadata: ProjectEngineeringMetadata(
        boundaryWallProfileRegistry: BoundaryWallProfileRegistry({
          foreignHost: WallProfile.rectangle(widthMm: 4000, heightMm: 3000),
        }),
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
            spaceIds: [spaceA, spaceB],
          ),
        },
        spaces: {
          spaceA: ProjectSpaceEntity(
            id: spaceA,
            levelId: levelId,
            name: 'Room A',
          ),
          spaceB: ProjectSpaceEntity(
            id: spaceB,
            levelId: levelId,
            name: 'Room B',
          ),
        },
        boundaries: {spaceA: boundaryA, spaceB: boundaryB},
      ),
    );
  }

  SpaceBoundaryTopology _rectangle(SpaceId spaceId, List<String> ids) {
    const points = [
      BoundaryPointMm(xMm: 0, yMm: 0),
      BoundaryPointMm(xMm: 4000, yMm: 0),
      BoundaryPointMm(xMm: 4000, yMm: 3000),
      BoundaryPointMm(xMm: 0, yMm: 3000),
    ];
    final edgeIds = [for (final id in ids) BoundaryEdgeId(id)];
    return SpaceBoundaryTopology(
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
  }
}
