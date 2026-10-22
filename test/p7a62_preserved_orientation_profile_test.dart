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
  test('preserved edge cannot reverse shaped wall-profile orientation silently',
      () {
    final fixture = _Fixture();
    final initial = fixture.project();
    final mutations = ProjectMutationSession(initial);
    final edit = ProjectBoundaryTopologyMigrationService(mutations).begin(
      spaceId: fixture.spaceId,
      expectedVersion: initial.version,
    );

    expect(
      () => edit.previewReplaceTopology(
        topology: fixture.reversedBoundary(),
        lineage: BoundaryTopologyChangeSet([
          BoundaryEdgeLineage.preserved(fixture.bottom),
          BoundaryEdgeLineage.preserved(fixture.east),
          BoundaryEdgeLineage.preserved(fixture.north),
          BoundaryEdgeLineage.preserved(fixture.west),
        ]),
      ),
      throwsA(isA<BoundaryTopologyMigrationException>()),
      reason: 'WallProfile X runs from edge.start to edge.end. Reversing a '
          'preserved edge without an explicit profile transform would mirror '
          'the physical shaped profile while retaining the same payload.',
    );
    expect(mutations.current, same(initial));
    expect(mutations.undoDepth, 0);
  });
}

final class _Fixture {
  final projectId = ProjectId('p7a62-orientation');
  final siteId = SiteId('site');
  final buildingId = BuildingId('building');
  final levelId = LevelId('level');
  final spaceId = SpaceId('space');
  final bottom = BoundaryEdgeId('bottom');
  final east = BoundaryEdgeId('east');
  final north = BoundaryEdgeId('north');
  final west = BoundaryEdgeId('west');

  SpaceBoundaryTopology boundary() => SpaceBoundaryTopology(
        spaceId: spaceId,
        orderedEdgeIds: [bottom, east, north, west],
        edges: {
          bottom: _edge(bottom, 0, 0, 4000, 0),
          east: _edge(east, 4000, 0, 4000, 3000),
          north: _edge(north, 4000, 3000, 0, 3000),
          west: _edge(west, 0, 3000, 0, 0),
        },
      );

  SpaceBoundaryTopology reversedBoundary() => SpaceBoundaryTopology(
        spaceId: spaceId,
        orderedEdgeIds: [west, north, east, bottom],
        edges: {
          west: _edge(west, 0, 0, 0, 3000),
          north: _edge(north, 0, 3000, 4000, 3000),
          east: _edge(east, 4000, 3000, 4000, 0),
          bottom: _edge(bottom, 4000, 0, 0, 0),
        },
      );

  ProjectAggregateRoot project() {
    final topology = boundary();
    final shaped = WallProfile.rectangle(widthMm: 4000, heightMm: 3000)
        .withTopNotch(startMm: 500, widthMm: 700, depthMm: 400);
    return ProjectAggregateRoot(
      id: projectId,
      siteId: siteId,
      version: LocalProjectVersion(0),
      engineeringMetadata: ProjectEngineeringMetadata(
        boundaryWallProfileRegistry: BoundaryWallProfileRegistry({
          BoundaryEdgeHostRef(spaceId: spaceId, edgeId: bottom): shaped,
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

  ProjectBoundaryEdge _edge(
    BoundaryEdgeId id,
    int x1,
    int y1,
    int x2,
    int y2,
  ) =>
      ProjectBoundaryEdge(
        id: id,
        spaceId: spaceId,
        start: BoundaryPointMm(xMm: x1, yMm: y1),
        end: BoundaryPointMm(xMm: x2, yMm: y2),
      );
}
