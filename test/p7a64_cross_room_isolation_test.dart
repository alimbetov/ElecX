import 'package:elecx/src/application/project/project_boundary_topology_migration.dart';
import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/domain/boundary_edge_identity_registry.dart';
import 'package:elecx/src/domain/boundary_host_migration.dart';
import 'package:elecx/src/domain/boundary_host_registry.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/boundary_wall_profile_registry.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_orientation.dart';
import 'package:elecx/src/domain/wall_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P7A-6.4 cross-room isolation', () {
    test('coincident room edges retain independent durable identities', () {
      final fixture = _Fixture();
      final project = fixture.project();
      final a = project.index.boundary(fixture.spaceA)!;
      final b = project.index.boundary(fixture.spaceB)!;

      expect(a.edges[fixture.aBottom]!.start, b.edges[fixture.bBottom]!.start);
      expect(a.edges[fixture.aBottom]!.end, b.edges[fixture.bBottom]!.end);
      expect(fixture.aBottom, isNot(fixture.bBottom));
      expect(
        project.engineeringMetadata.boundaryEdgeIdentityRegistry
            .ownerOf(fixture.aBottom),
        fixture.spaceA,
      );
      expect(
        project.engineeringMetadata.boundaryEdgeIdentityRegistry
            .ownerOf(fixture.bBottom),
        fixture.spaceB,
      );
    });

    test('split in room A cannot mutate room B topology hosts or profiles', () {
      final fixture = _Fixture();
      final initial = fixture.project();
      final mutations = ProjectMutationSession(initial);
      final beforeB = initial.index.boundary(fixture.spaceB)!;
      final beforeBHost = initial
          .engineeringMetadata.boundaryHostedObjectRegistry['component:b']!;
      final bProfileHost = BoundaryEdgeHostRef(
        spaceId: fixture.spaceB,
        edgeId: fixture.bBottom,
      );
      final beforeBProfile = initial
          .engineeringMetadata.boundaryWallProfileRegistry[bProfileHost]!;

      final edit = ProjectBoundaryTopologyMigrationService(mutations).begin(
        spaceId: fixture.spaceA,
        expectedVersion: initial.version,
      );
      edit.previewSplitEdge(
        sourceEdgeId: fixture.aBottom,
        splitPoint: const BoundaryPointMm(xMm: 2000, yMm: 0),
        firstResultEdgeId: fixture.aBottom1,
        secondResultEdgeId: fixture.aBottom2,
      );
      final committed = edit.commit();

      expect(committed, isNotNull);
      final result = mutations.current;
      final afterB = result.index.boundary(fixture.spaceB)!;
      expect(afterB.orderedEdgeIds, beforeB.orderedEdgeIds);
      for (final edgeId in beforeB.orderedEdgeIds) {
        final before = beforeB.edges[edgeId]!;
        final after = afterB.edges[edgeId]!;
        expect(after.id, before.id);
        expect(after.spaceId, before.spaceId);
        expect(after.start, before.start);
        expect(after.end, before.end);
      }

      final afterBHost = result
          .engineeringMetadata.boundaryHostedObjectRegistry['component:b']!;
      expect(afterBHost.objectKey, beforeBHost.objectKey);
      expect(afterBHost.objectKind, beforeBHost.objectKind);
      expect(afterBHost.host, beforeBHost.host);
      expect(afterBHost.startOffsetMm, beforeBHost.startOffsetMm);
      expect(afterBHost.endOffsetMm, beforeBHost.endOffsetMm);

      final afterBProfile =
          result.engineeringMetadata.boundaryWallProfileRegistry[bProfileHost]!;
      expect(afterBProfile.maxX, beforeBProfile.maxX);
      expect(afterBProfile.maxY, beforeBProfile.maxY);
      expect(afterBProfile.vertices.length, beforeBProfile.vertices.length);
      for (var i = 0; i < beforeBProfile.vertices.length; i++) {
        expect(afterBProfile.vertices[i].xMm, beforeBProfile.vertices[i].xMm);
        expect(afterBProfile.vertices[i].yMm, beforeBProfile.vertices[i].yMm);
      }

      expect(
        result.index.boundary(fixture.spaceA)!.orderedEdgeIds.take(2),
        [fixture.aBottom1, fixture.aBottom2],
      );
      expect(
        result.engineeringMetadata.boundaryHostedObjectRegistry['component:a']!
            .host.edgeId,
        fixture.aBottom1,
      );
    });
  });
}

final class _Fixture {
  final projectId = ProjectId('project-p7a64');
  final siteId = SiteId('site-p7a64');
  final buildingId = BuildingId('building-p7a64');
  final levelId = LevelId('level-p7a64');
  final spaceA = SpaceId('space-a');
  final spaceB = SpaceId('space-b');

  final aBottom = BoundaryEdgeId('a-bottom');
  final aBottom1 = BoundaryEdgeId('a-bottom-1');
  final aBottom2 = BoundaryEdgeId('a-bottom-2');
  final aEast = BoundaryEdgeId('a-east');
  final aNorth = BoundaryEdgeId('a-north');
  final aWest = BoundaryEdgeId('a-west');

  final bBottom = BoundaryEdgeId('b-bottom');
  final bEast = BoundaryEdgeId('b-east');
  final bNorth = BoundaryEdgeId('b-north');
  final bWest = BoundaryEdgeId('b-west');

  ProjectAggregateRoot project() {
    final hosts = BoundaryHostedObjectRegistry({
      'component:a': BoundaryHostedReference.point(
        objectKey: 'component:a',
        objectKind: BoundaryHostedObjectKind.component,
        host: BoundaryEdgeHostRef(spaceId: spaceA, edgeId: aBottom),
        offsetMm: 1000,
      ),
      'component:b': BoundaryHostedReference.point(
        objectKey: 'component:b',
        objectKind: BoundaryHostedObjectKind.component,
        host: BoundaryEdgeHostRef(spaceId: spaceB, edgeId: bBottom),
        offsetMm: 1200,
      ),
    });
    final profiles = BoundaryWallProfileRegistry({
      BoundaryEdgeHostRef(spaceId: spaceA, edgeId: aBottom):
          WallProfile.rectangle(widthMm: 4000, heightMm: 3000),
      BoundaryEdgeHostRef(spaceId: spaceB, edgeId: bBottom):
          WallProfile.rectangle(widthMm: 4000, heightMm: 2800),
    });
    final boundaries = <SpaceId, SpaceBoundaryTopology>{
      spaceA: _topology(spaceA, [aBottom, aEast, aNorth, aWest]),
      spaceB: _topology(spaceB, [bBottom, bEast, bNorth, bWest]),
    };
    final identities = const BoundaryEdgeIdentityRegistry.empty()
        .registerActiveBoundaries(boundaries);
    return ProjectAggregateRoot(
      id: projectId,
      siteId: siteId,
      version: LocalProjectVersion(0),
      engineeringMetadata: ProjectEngineeringMetadata(
        boundaryEdgeIdentityRegistry: identities,
        boundaryHostedObjectRegistry: hosts,
        boundaryWallProfileRegistry: profiles,
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
          spaceA: ProjectSpaceEntity(id: spaceA, levelId: levelId, name: 'A'),
          spaceB: ProjectSpaceEntity(id: spaceB, levelId: levelId, name: 'B'),
        },
        boundaries: boundaries,
      ),
    );
  }

  SpaceBoundaryTopology _topology(
    SpaceId spaceId,
    List<BoundaryEdgeId> ids,
  ) {
    const points = [
      BoundaryPointMm(xMm: 0, yMm: 0),
      BoundaryPointMm(xMm: 4000, yMm: 0),
      BoundaryPointMm(xMm: 4000, yMm: 3000),
      BoundaryPointMm(xMm: 0, yMm: 3000),
    ];
    return SpaceBoundaryTopology(
      spaceId: spaceId,
      orderedEdgeIds: ids,
      edges: {
        for (var index = 0; index < ids.length; index++)
          ids[index]: ProjectBoundaryEdge(
            id: ids[index],
            spaceId: spaceId,
            start: points[index],
            end: points[(index + 1) % points.length],
          ),
      },
    );
  }
}
