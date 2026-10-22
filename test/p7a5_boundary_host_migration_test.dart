import 'package:elecx/src/domain/boundary_host_migration.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final spaceId = SpaceId('room-a');
  final old = BoundaryEdgeId('old');
  final a = BoundaryEdgeId('a');
  final b = BoundaryEdgeId('b');

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

  SpaceBoundaryTopology rectangleWithBottom({
    required List<BoundaryEdgeId> orderedBottomIds,
    required Map<BoundaryEdgeId, ProjectBoundaryEdge> bottomEdges,
  }) {
    final east = edge(BoundaryEdgeId('east'), 4000, 0, 4000, 3000);
    final north = edge(BoundaryEdgeId('north'), 4000, 3000, 0, 3000);
    final west = edge(BoundaryEdgeId('west'), 0, 3000, 0, 0);
    return SpaceBoundaryTopology(
      spaceId: spaceId,
      orderedEdgeIds: [
        ...orderedBottomIds,
        east.id,
        north.id,
        west.id,
      ],
      edges: {
        ...bottomEdges,
        east.id: east,
        north.id: north,
        west.id: west,
      },
    );
  }

  group('P7A-5 hosted boundary migration', () {
    test('point hosted component follows one split child by geometry', () {
      final before = rectangleWithBottom(
        orderedBottomIds: [old],
        bottomEdges: {old: edge(old, 0, 0, 4000, 0)},
      );
      final after = rectangleWithBottom(
        orderedBottomIds: [a, b],
        bottomEdges: {
          a: edge(a, 0, 0, 2000, 0),
          b: edge(b, 2000, 0, 4000, 0),
        },
      );
      final lineage = BoundaryTopologyChangeSet([
        BoundaryEdgeLineage.split(sourceEdgeId: old, resultEdgeIds: [a, b]),
        BoundaryEdgeLineage.preserved(BoundaryEdgeId('east')),
        BoundaryEdgeLineage.preserved(BoundaryEdgeId('north')),
        BoundaryEdgeLineage.preserved(BoundaryEdgeId('west')),
      ]);

      final result = BoundaryHostedObjectRemapper.remapAll(
        before: before,
        after: after,
        lineage: lineage,
        references: [
          BoundaryHostedReference.point(
            objectKey: 'component:c1',
            objectKind: BoundaryHostedObjectKind.component,
            host: BoundaryEdgeHostRef(spaceId: spaceId, edgeId: old),
            offsetMm: 3000,
          ),
        ],
      ).single;

      expect(result.host.edgeId, b);
      expect(result.startOffsetMm, 1000);
    });

    test('opening interval stays on one split child and offset is rebased', () {
      final before = rectangleWithBottom(
        orderedBottomIds: [old],
        bottomEdges: {old: edge(old, 0, 0, 4000, 0)},
      );
      final after = rectangleWithBottom(
        orderedBottomIds: [a, b],
        bottomEdges: {
          a: edge(a, 0, 0, 2000, 0),
          b: edge(b, 2000, 0, 4000, 0),
        },
      );
      final lineage = BoundaryTopologyChangeSet([
        BoundaryEdgeLineage.split(sourceEdgeId: old, resultEdgeIds: [a, b]),
        BoundaryEdgeLineage.preserved(BoundaryEdgeId('east')),
        BoundaryEdgeLineage.preserved(BoundaryEdgeId('north')),
        BoundaryEdgeLineage.preserved(BoundaryEdgeId('west')),
      ]);

      final result = BoundaryHostedObjectRemapper.remapAll(
        before: before,
        after: after,
        lineage: lineage,
        references: [
          BoundaryHostedReference.interval(
            objectKey: 'opening:o1',
            objectKind: BoundaryHostedObjectKind.opening,
            host: BoundaryEdgeHostRef(spaceId: spaceId, edgeId: old),
            startOffsetMm: 2500,
            endOffsetMm: 3500,
          ),
        ],
      ).single;

      expect(result.host.edgeId, b);
      expect(result.startOffsetMm, 500);
      expect(result.endOffsetMm, 1500);
    });

    test('opening crossing split point fails closed atomically', () {
      final before = rectangleWithBottom(
        orderedBottomIds: [old],
        bottomEdges: {old: edge(old, 0, 0, 4000, 0)},
      );
      final after = rectangleWithBottom(
        orderedBottomIds: [a, b],
        bottomEdges: {
          a: edge(a, 0, 0, 2000, 0),
          b: edge(b, 2000, 0, 4000, 0),
        },
      );
      final lineage = BoundaryTopologyChangeSet([
        BoundaryEdgeLineage.split(sourceEdgeId: old, resultEdgeIds: [a, b]),
        BoundaryEdgeLineage.preserved(BoundaryEdgeId('east')),
        BoundaryEdgeLineage.preserved(BoundaryEdgeId('north')),
        BoundaryEdgeLineage.preserved(BoundaryEdgeId('west')),
      ]);

      expect(
        () => BoundaryHostedObjectRemapper.remapAll(
          before: before,
          after: after,
          lineage: lineage,
          references: [
            BoundaryHostedReference.interval(
              objectKey: 'opening:o-cross',
              objectKind: BoundaryHostedObjectKind.opening,
              host: BoundaryEdgeHostRef(spaceId: spaceId, edgeId: old),
              startOffsetMm: 1500,
              endOffsetMm: 2500,
            ),
          ],
        ),
        throwsA(
          isA<BoundaryHostMigrationException>().having(
            (error) => error.code,
            'code',
            BoundaryHostMigrationIssueCode.intervalCrossesResultEdges,
          ),
        ),
      );
    });

    test('split-point route anchor is ambiguous and fails closed', () {
      final before = rectangleWithBottom(
        orderedBottomIds: [old],
        bottomEdges: {old: edge(old, 0, 0, 4000, 0)},
      );
      final after = rectangleWithBottom(
        orderedBottomIds: [a, b],
        bottomEdges: {
          a: edge(a, 0, 0, 2000, 0),
          b: edge(b, 2000, 0, 4000, 0),
        },
      );
      final lineage = BoundaryTopologyChangeSet([
        BoundaryEdgeLineage.split(sourceEdgeId: old, resultEdgeIds: [a, b]),
        BoundaryEdgeLineage.preserved(BoundaryEdgeId('east')),
        BoundaryEdgeLineage.preserved(BoundaryEdgeId('north')),
        BoundaryEdgeLineage.preserved(BoundaryEdgeId('west')),
      ]);

      expect(
        () => BoundaryHostedObjectRemapper.remapAll(
          before: before,
          after: after,
          lineage: lineage,
          references: [
            BoundaryHostedReference.point(
              objectKey: 'route:r1:anchor:2',
              objectKind: BoundaryHostedObjectKind.routeAnchor,
              host: BoundaryEdgeHostRef(spaceId: spaceId, edgeId: old),
              offsetMm: 2000,
            ),
          ],
        ),
        throwsA(
          isA<BoundaryHostMigrationException>().having(
            (error) => error.code,
            'code',
            BoundaryHostMigrationIssueCode.ambiguousPointRemap,
          ),
        ),
      );
    });

    test('wall profile split requires explicit domain transform', () {
      final before = rectangleWithBottom(
        orderedBottomIds: [old],
        bottomEdges: {old: edge(old, 0, 0, 4000, 0)},
      );
      final after = rectangleWithBottom(
        orderedBottomIds: [a, b],
        bottomEdges: {
          a: edge(a, 0, 0, 2000, 0),
          b: edge(b, 2000, 0, 4000, 0),
        },
      );
      final lineage = BoundaryTopologyChangeSet([
        BoundaryEdgeLineage.split(sourceEdgeId: old, resultEdgeIds: [a, b]),
        BoundaryEdgeLineage.preserved(BoundaryEdgeId('east')),
        BoundaryEdgeLineage.preserved(BoundaryEdgeId('north')),
        BoundaryEdgeLineage.preserved(BoundaryEdgeId('west')),
      ]);

      expect(
        () => BoundaryHostedObjectRemapper.remapAll(
          before: before,
          after: after,
          lineage: lineage,
          references: [
            BoundaryHostedReference.wholeEdge(
              objectKey: 'wall-profile:$old',
              objectKind: BoundaryHostedObjectKind.wallProfile,
              host: BoundaryEdgeHostRef(spaceId: spaceId, edgeId: old),
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

    test('removed cable endpoint cannot silently reindex', () {
      final before = rectangleWithBottom(
        orderedBottomIds: [old],
        bottomEdges: {old: edge(old, 0, 0, 4000, 0)},
      );
      final afterEdge = BoundaryEdgeId('new-bottom');
      final after = rectangleWithBottom(
        orderedBottomIds: [afterEdge],
        bottomEdges: {afterEdge: edge(afterEdge, 0, 0, 4000, 0)},
      );
      final lineage = BoundaryTopologyChangeSet([
        BoundaryEdgeLineage.removed([old]),
        BoundaryEdgeLineage.created([afterEdge]),
        BoundaryEdgeLineage.preserved(BoundaryEdgeId('east')),
        BoundaryEdgeLineage.preserved(BoundaryEdgeId('north')),
        BoundaryEdgeLineage.preserved(BoundaryEdgeId('west')),
      ]);

      expect(
        () => BoundaryHostedObjectRemapper.remapAll(
          before: before,
          after: after,
          lineage: lineage,
          references: [
            BoundaryHostedReference.point(
              objectKey: 'cable:r1:source',
              objectKind: BoundaryHostedObjectKind.cableEndpoint,
              host: BoundaryEdgeHostRef(spaceId: spaceId, edgeId: old),
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
  });
}
