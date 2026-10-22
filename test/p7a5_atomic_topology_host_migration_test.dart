import 'package:elecx/src/application/project/project_boundary_topology_migration.dart';
import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/domain/boundary_host_migration.dart';
import 'package:elecx/src/domain/boundary_host_registry.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_orientation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P7A-5 atomic topology + hosted object migration', () {
    test('split commits topology and all hosted references as one undo record',
        () {
      final fixture = _Fixture();
      final initial = fixture.project(
        hostedObjects: fixture.hostedObjectsOnBottom(),
      );
      final mutations = ProjectMutationSession(initial);
      final migration = ProjectBoundaryTopologyMigrationService(mutations);

      final edit = migration.begin(
        spaceId: fixture.spaceId,
        expectedVersion: initial.version,
      );
      final preview = edit.previewSplitEdge(
        sourceEdgeId: fixture.bottom,
        splitPoint: const BoundaryPointMm(xMm: 2000, yMm: 0),
        firstResultEdgeId: fixture.bottomA,
        secondResultEdgeId: fixture.bottomB,
      );

      expect(preview.topology.orderedEdgeIds.take(2), [
        fixture.bottomA,
        fixture.bottomB,
      ]);
      expect(
        preview.hostedObjects['opening:o1']!.host.edgeId,
        fixture.bottomB,
      );
      expect(preview.hostedObjects['opening:o1']!.startOffsetMm, 400);
      expect(preview.hostedObjects['opening:o1']!.endOffsetMm, 1200);
      expect(
        preview.hostedObjects['component:c1']!.host.edgeId,
        fixture.bottomA,
      );
      expect(preview.hostedObjects['component:c1']!.startOffsetMm, 1000);
      expect(
        preview.hostedObjects['cable:r1:source']!.host.edgeId,
        fixture.bottomB,
      );
      expect(
        preview.hostedObjects['route:r1:anchor:1']!.host.edgeId,
        fixture.bottomB,
      );

      final committed = edit.commit();
      expect(committed, isNotNull);
      expect(committed!.mutation.project.version, LocalProjectVersion(1));
      expect(mutations.undoDepth, 1);
      expect(
        mutations.current.index.boundary(fixture.spaceId)!.orderedEdgeIds,
        [
          fixture.bottomA,
          fixture.bottomB,
          fixture.east,
          fixture.north,
          fixture.west
        ],
      );
      expect(
        mutations.current.engineeringMetadata
            .boundaryHostedObjectRegistry['opening:o1']!.host.edgeId,
        fixture.bottomB,
      );

      final undone = mutations.undo(mutations.current.version);
      expect(undone, isNotNull);
      expect(undone!.project.version, LocalProjectVersion(2));
      expect(
        undone.project.index.boundary(fixture.spaceId)!.orderedEdgeIds,
        [fixture.bottom, fixture.east, fixture.north, fixture.west],
      );
      expect(
        undone.project.engineeringMetadata
            .boundaryHostedObjectRegistry['opening:o1']!.host.edgeId,
        fixture.bottom,
      );
      expect(
        undone.project.engineeringMetadata.boundaryEdgeIdentityRegistry.ownerOf(
          fixture.bottomA,
        ),
        fixture.spaceId,
      );
      expect(
        undone.project.engineeringMetadata.boundaryEdgeIdentityRegistry.ownerOf(
          fixture.bottomB,
        ),
        fixture.spaceId,
      );

      final redone = mutations.redo(mutations.current.version);
      expect(redone, isNotNull);
      expect(redone!.project.version, LocalProjectVersion(3));
      expect(
        redone.project.engineeringMetadata
            .boundaryHostedObjectRegistry['opening:o1']!.host.edgeId,
        fixture.bottomB,
      );
    });

    test('opening crossing split blocks before canonical mutation', () {
      final fixture = _Fixture();
      final registry = BoundaryHostedObjectRegistry({
        'opening:cross': BoundaryHostedReference.interval(
          objectKey: 'opening:cross',
          objectKind: BoundaryHostedObjectKind.opening,
          host: BoundaryEdgeHostRef(
            spaceId: fixture.spaceId,
            edgeId: fixture.bottom,
          ),
          startOffsetMm: 1500,
          endOffsetMm: 2500,
        ),
      });
      final initial = fixture.project(hostedObjects: registry);
      final mutations = ProjectMutationSession(initial);
      final edit = ProjectBoundaryTopologyMigrationService(mutations).begin(
        spaceId: fixture.spaceId,
        expectedVersion: initial.version,
      );

      expect(
        () => edit.previewSplitEdge(
          sourceEdgeId: fixture.bottom,
          splitPoint: const BoundaryPointMm(xMm: 2000, yMm: 0),
          firstResultEdgeId: fixture.bottomA,
          secondResultEdgeId: fixture.bottomB,
        ),
        throwsA(
          isA<BoundaryHostMigrationException>().having(
            (error) => error.code,
            'code',
            BoundaryHostMigrationIssueCode.intervalCrossesResultEdges,
          ),
        ),
      );
      expect(mutations.current.version, LocalProjectVersion(0));
      expect(mutations.undoDepth, 0);
      expect(
        mutations.current.index.boundary(fixture.spaceId)!.orderedEdgeIds,
        [fixture.bottom, fixture.east, fixture.north, fixture.west],
      );
    });

    test('whole-edge wall profile blocks identity-changing split', () {
      final fixture = _Fixture();
      final registry = BoundaryHostedObjectRegistry({
        'wall-profile:bottom': BoundaryHostedReference.wholeEdge(
          objectKey: 'wall-profile:bottom',
          objectKind: BoundaryHostedObjectKind.wallProfile,
          host: BoundaryEdgeHostRef(
            spaceId: fixture.spaceId,
            edgeId: fixture.bottom,
          ),
        ),
      });
      final initial = fixture.project(hostedObjects: registry);
      final mutations = ProjectMutationSession(initial);
      final edit = ProjectBoundaryTopologyMigrationService(mutations).begin(
        spaceId: fixture.spaceId,
        expectedVersion: initial.version,
      );

      expect(
        () => edit.previewSplitEdge(
          sourceEdgeId: fixture.bottom,
          splitPoint: const BoundaryPointMm(xMm: 2000, yMm: 0),
          firstResultEdgeId: fixture.bottomA,
          secondResultEdgeId: fixture.bottomB,
        ),
        throwsA(
          isA<BoundaryHostMigrationException>().having(
            (error) => error.code,
            'code',
            BoundaryHostMigrationIssueCode.wholeEdgeRequiresDomainTransform,
          ),
        ),
      );
      expect(mutations.current.version, LocalProjectVersion(0));
      expect(mutations.undoDepth, 0);
    });

    test('merge rebases point and interval hosts onto one new edge', () {
      final fixture = _Fixture();
      final initial = fixture.project(
        boundary: fixture.splitBoundary(),
        hostedObjects: BoundaryHostedObjectRegistry({
          'component:c1': BoundaryHostedReference.point(
            objectKey: 'component:c1',
            objectKind: BoundaryHostedObjectKind.component,
            host: BoundaryEdgeHostRef(
              spaceId: fixture.spaceId,
              edgeId: fixture.bottomA,
            ),
            offsetMm: 1000,
          ),
          'opening:o1': BoundaryHostedReference.interval(
            objectKey: 'opening:o1',
            objectKind: BoundaryHostedObjectKind.opening,
            host: BoundaryEdgeHostRef(
              spaceId: fixture.spaceId,
              edgeId: fixture.bottomB,
            ),
            startOffsetMm: 400,
            endOffsetMm: 1200,
          ),
        }),
      );
      final mutations = ProjectMutationSession(initial);
      final edit = ProjectBoundaryTopologyMigrationService(mutations).begin(
        spaceId: fixture.spaceId,
        expectedVersion: initial.version,
      );

      final preview = edit.previewMergeAdjacentEdges(
        firstSourceEdgeId: fixture.bottomA,
        secondSourceEdgeId: fixture.bottomB,
        resultEdgeId: fixture.bottomMerged,
      );

      expect(
        preview.hostedObjects['component:c1']!.host.edgeId,
        fixture.bottomMerged,
      );
      expect(preview.hostedObjects['component:c1']!.startOffsetMm, 1000);
      expect(
        preview.hostedObjects['opening:o1']!.host.edgeId,
        fixture.bottomMerged,
      );
      expect(preview.hostedObjects['opening:o1']!.startOffsetMm, 2400);
      expect(preview.hostedObjects['opening:o1']!.endOffsetMm, 3200);

      final committed = edit.commit();
      expect(committed, isNotNull);
      expect(mutations.current.version, LocalProjectVersion(1));
      expect(mutations.undoDepth, 1);
    });
  });
}

final class _Fixture {
  final projectId = ProjectId('project-p7a5');
  final siteId = SiteId('site-p7a5');
  final buildingId = BuildingId('building-p7a5');
  final levelId = LevelId('level-p7a5');
  final spaceId = SpaceId('space-p7a5');

  final bottom = BoundaryEdgeId('bottom');
  final bottomA = BoundaryEdgeId('bottom-a');
  final bottomB = BoundaryEdgeId('bottom-b');
  final bottomMerged = BoundaryEdgeId('bottom-merged');
  final east = BoundaryEdgeId('east');
  final north = BoundaryEdgeId('north');
  final west = BoundaryEdgeId('west');

  ProjectAggregateRoot project({
    SpaceBoundaryTopology? boundary,
    BoundaryHostedObjectRegistry hostedObjects =
        const BoundaryHostedObjectRegistry.empty(),
  }) {
    final topology = boundary ?? initialBoundary();
    return ProjectAggregateRoot(
      id: projectId,
      siteId: siteId,
      version: LocalProjectVersion(0),
      engineeringMetadata: ProjectEngineeringMetadata(
        boundaryHostedObjectRegistry: hostedObjects,
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

  BoundaryHostedObjectRegistry hostedObjectsOnBottom() =>
      BoundaryHostedObjectRegistry({
        'opening:o1': BoundaryHostedReference.interval(
          objectKey: 'opening:o1',
          objectKind: BoundaryHostedObjectKind.opening,
          host: BoundaryEdgeHostRef(spaceId: spaceId, edgeId: bottom),
          startOffsetMm: 2400,
          endOffsetMm: 3200,
        ),
        'component:c1': BoundaryHostedReference.point(
          objectKey: 'component:c1',
          objectKind: BoundaryHostedObjectKind.component,
          host: BoundaryEdgeHostRef(spaceId: spaceId, edgeId: bottom),
          offsetMm: 1000,
        ),
        'cable:r1:source': BoundaryHostedReference.point(
          objectKey: 'cable:r1:source',
          objectKind: BoundaryHostedObjectKind.cableEndpoint,
          host: BoundaryEdgeHostRef(spaceId: spaceId, edgeId: bottom),
          offsetMm: 3000,
        ),
        'route:r1:anchor:1': BoundaryHostedReference.point(
          objectKey: 'route:r1:anchor:1',
          objectKind: BoundaryHostedObjectKind.routeAnchor,
          host: BoundaryEdgeHostRef(spaceId: spaceId, edgeId: bottom),
          offsetMm: 3500,
        ),
      });

  SpaceBoundaryTopology initialBoundary() => _topology(
        [bottom, east, north, west],
        [
          const BoundaryPointMm(xMm: 0, yMm: 0),
          const BoundaryPointMm(xMm: 4000, yMm: 0),
          const BoundaryPointMm(xMm: 4000, yMm: 3000),
          const BoundaryPointMm(xMm: 0, yMm: 3000),
        ],
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

  SpaceBoundaryTopology _topology(
    List<BoundaryEdgeId> ids,
    List<BoundaryPointMm> points,
  ) {
    final edges = <BoundaryEdgeId, ProjectBoundaryEdge>{};
    for (var index = 0; index < ids.length; index++) {
      edges[ids[index]] = ProjectBoundaryEdge(
        id: ids[index],
        spaceId: spaceId,
        start: points[index],
        end: points[(index + 1) % points.length],
      );
    }
    return SpaceBoundaryTopology(
      spaceId: spaceId,
      orderedEdgeIds: ids,
      edges: edges,
    );
  }
}
