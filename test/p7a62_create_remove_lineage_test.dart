import 'package:elecx/src/domain/boundary_host_migration.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P7A-6.2 create/remove lineage', () {
    test('hosted removed source fails closed without domain removal policy',
        () {
      final fixture = _Fixture();
      final after = fixture.topology(
        bottomIds: [fixture.created],
        bottomEdges: {
          fixture.created: fixture.edge(fixture.created, 0, 0, 4000, 0),
        },
      );
      final lineage = BoundaryTopologyChangeSet([
        BoundaryEdgeLineage.removed([fixture.source]),
        BoundaryEdgeLineage.created([fixture.created]),
        BoundaryEdgeLineage.preserved(fixture.east),
        BoundaryEdgeLineage.preserved(fixture.north),
        BoundaryEdgeLineage.preserved(fixture.west),
      ]);

      expect(
        () => BoundaryHostedObjectRemapper.remapAll(
          before: fixture.before,
          after: after,
          lineage: lineage,
          references: [
            BoundaryHostedReference.point(
              objectKey: 'component:removed-source',
              objectKind: BoundaryHostedObjectKind.component,
              host: fixture.sourceHost,
              offsetMm: 1000,
            ),
          ],
        ),
        throwsA(
          isA<BoundaryHostMigrationException>().having(
            (error) => error.code,
            'code',
            BoundaryHostMigrationIssueCode.removedHost,
          ),
        ),
      );
    });

    test('created nearby edge never attracts host from preserved source', () {
      final fixture = _Fixture();
      final created = fixture.created;
      final after = SpaceBoundaryTopology(
        spaceId: fixture.spaceId,
        orderedEdgeIds: [
          fixture.source,
          created,
          fixture.east,
          fixture.north,
          fixture.west,
        ],
        edges: {
          fixture.source: fixture.edge(fixture.source, 0, 0, 4000, 0),
          created: fixture.edge(created, 4000, 0, 4000, 1000),
          fixture.east: fixture.edge(fixture.east, 4000, 1000, 4000, 3000),
          fixture.north: fixture.edge(fixture.north, 4000, 3000, 0, 3000),
          fixture.west: fixture.edge(fixture.west, 0, 3000, 0, 0),
        },
      );
      final lineage = BoundaryTopologyChangeSet([
        BoundaryEdgeLineage.preserved(fixture.source),
        BoundaryEdgeLineage.created([created]),
        BoundaryEdgeLineage.preserved(fixture.east),
        BoundaryEdgeLineage.preserved(fixture.north),
        BoundaryEdgeLineage.preserved(fixture.west),
      ]);

      final result = BoundaryHostedObjectRemapper.remapAll(
        before: fixture.before,
        after: after,
        lineage: lineage,
        references: [
          BoundaryHostedReference.point(
            objectKey: 'component:preserved',
            objectKind: BoundaryHostedObjectKind.component,
            host: fixture.sourceHost,
            offsetMm: 4000,
          ),
        ],
      ).single;

      expect(result.host.edgeId, fixture.source);
      expect(result.startOffsetMm, 4000);
    });

    test('whole-edge payload cannot be guessed across split lineage', () {
      final fixture = _Fixture();
      final first = BoundaryEdgeId('first');
      final second = BoundaryEdgeId('second');
      final after = fixture.topology(
        bottomIds: [first, second],
        bottomEdges: {
          first: fixture.edge(first, 0, 0, 2000, 0),
          second: fixture.edge(second, 2000, 0, 4000, 0),
        },
      );
      final lineage = BoundaryTopologyChangeSet([
        BoundaryEdgeLineage.split(
          sourceEdgeId: fixture.source,
          resultEdgeIds: [first, second],
        ),
        BoundaryEdgeLineage.preserved(fixture.east),
        BoundaryEdgeLineage.preserved(fixture.north),
        BoundaryEdgeLineage.preserved(fixture.west),
      ]);

      expect(
        () => BoundaryHostedObjectRemapper.remapAll(
          before: fixture.before,
          after: after,
          lineage: lineage,
          references: [
            BoundaryHostedReference.wholeEdge(
              objectKey: 'domain:whole-edge',
              objectKind: BoundaryHostedObjectKind.component,
              host: fixture.sourceHost,
            ),
          ],
        ),
        throwsA(
          isA<BoundaryHostMigrationException>().having(
            (error) => error.code,
            'code',
            BoundaryHostMigrationIssueCode.wholeEdgeRequiresDomainTransform,
          ),
        ),
      );
    });
  });
}

final class _Fixture {
  _Fixture() {
    before = topology(
      bottomIds: [source],
      bottomEdges: {source: edge(source, 0, 0, 4000, 0)},
    );
  }

  final spaceId = SpaceId('space');
  final source = BoundaryEdgeId('source');
  final created = BoundaryEdgeId('created');
  final east = BoundaryEdgeId('east');
  final north = BoundaryEdgeId('north');
  final west = BoundaryEdgeId('west');

  late final SpaceBoundaryTopology before;

  BoundaryEdgeHostRef get sourceHost =>
      BoundaryEdgeHostRef(spaceId: spaceId, edgeId: source);

  SpaceBoundaryTopology topology({
    required List<BoundaryEdgeId> bottomIds,
    required Map<BoundaryEdgeId, ProjectBoundaryEdge> bottomEdges,
  }) =>
      SpaceBoundaryTopology(
        spaceId: spaceId,
        orderedEdgeIds: [...bottomIds, east, north, west],
        edges: {
          ...bottomEdges,
          east: edge(east, 4000, 0, 4000, 3000),
          north: edge(north, 4000, 3000, 0, 3000),
          west: edge(west, 0, 3000, 0, 0),
        },
      );

  ProjectBoundaryEdge edge(
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
