import 'package:elecx/src/domain/boundary_host_migration.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P7A-6.2 diagonal hosted-object remap', () {
    test('integer-mm point before non-integer split arc length is not ambiguous',
        () {
      final fixture = _DiagonalSplitFixture();

      final result = BoundaryHostedObjectRemapper.remapAll(
        before: fixture.before,
        after: fixture.after,
        lineage: fixture.lineage,
        references: [
          BoundaryHostedReference.point(
            objectKey: 'component:before-split',
            objectKind: BoundaryHostedObjectKind.component,
            host: BoundaryEdgeHostRef(
              spaceId: fixture.spaceId,
              edgeId: fixture.source,
            ),
            offsetMm: 424,
          ),
        ],
      ).single;

      expect(result.host.edgeId, fixture.first);
      expect(result.startOffsetMm, 424);
    });

    test('integer-mm point after non-integer split arc length maps second child',
        () {
      final fixture = _DiagonalSplitFixture();

      final result = BoundaryHostedObjectRemapper.remapAll(
        before: fixture.before,
        after: fixture.after,
        lineage: fixture.lineage,
        references: [
          BoundaryHostedReference.point(
            objectKey: 'route:after-split',
            objectKind: BoundaryHostedObjectKind.routeAnchor,
            host: BoundaryEdgeHostRef(
              spaceId: fixture.spaceId,
              edgeId: fixture.source,
            ),
            offsetMm: 425,
          ),
        ],
      ).single;

      expect(result.host.edgeId, fixture.second);
      expect(result.startOffsetMm, 1);
    });

    test('rounded source endpoint maps to exact end of second child', () {
      final fixture = _DiagonalSplitFixture();

      final result = BoundaryHostedObjectRemapper.remapAll(
        before: fixture.before,
        after: fixture.after,
        lineage: fixture.lineage,
        references: [
          BoundaryHostedReference.point(
            objectKey: 'cable:rounded-endpoint',
            objectKind: BoundaryHostedObjectKind.cableEndpoint,
            host: BoundaryEdgeHostRef(
              spaceId: fixture.spaceId,
              edgeId: fixture.source,
            ),
            offsetMm: 849,
          ),
        ],
      ).single;

      expect(result.host.edgeId, fixture.second);
      expect(result.startOffsetMm, 424);
    });

    test('interval ending before non-integer split remains on first child', () {
      final fixture = _DiagonalSplitFixture();

      final result = BoundaryHostedObjectRemapper.remapAll(
        before: fixture.before,
        after: fixture.after,
        lineage: fixture.lineage,
        references: [
          BoundaryHostedReference.interval(
            objectKey: 'opening:before-split',
            objectKind: BoundaryHostedObjectKind.opening,
            host: BoundaryEdgeHostRef(
              spaceId: fixture.spaceId,
              edgeId: fixture.source,
            ),
            startOffsetMm: 300,
            endOffsetMm: 424,
          ),
        ],
      ).single;

      expect(result.host.edgeId, fixture.first);
      expect(result.startOffsetMm, 300);
      expect(result.endOffsetMm, 424);
    });
  });
}

final class _DiagonalSplitFixture {
  _DiagonalSplitFixture() {
    final secondEdge = BoundaryEdgeId('triangle-second');
    final thirdEdge = BoundaryEdgeId('triangle-third');

    before = SpaceBoundaryTopology(
      spaceId: spaceId,
      orderedEdgeIds: [source, secondEdge, thirdEdge],
      edges: {
        source: _edge(source, 0, 0, 600, 600),
        secondEdge: _edge(secondEdge, 600, 600, 0, 1200),
        thirdEdge: _edge(thirdEdge, 0, 1200, 0, 0),
      },
    );

    after = SpaceBoundaryTopology(
      spaceId: spaceId,
      orderedEdgeIds: [first, second, secondEdge, thirdEdge],
      edges: {
        first: _edge(first, 0, 0, 300, 300),
        second: _edge(second, 300, 300, 600, 600),
        secondEdge: _edge(secondEdge, 600, 600, 0, 1200),
        thirdEdge: _edge(thirdEdge, 0, 1200, 0, 0),
      },
    );

    lineage = BoundaryTopologyChangeSet([
      BoundaryEdgeLineage.split(
        sourceEdgeId: source,
        resultEdgeIds: [first, second],
      ),
      BoundaryEdgeLineage.preserved(secondEdge),
      BoundaryEdgeLineage.preserved(thirdEdge),
    ]);
  }

  final SpaceId spaceId = SpaceId('diagonal-room');
  final BoundaryEdgeId source = BoundaryEdgeId('diagonal-source');
  final BoundaryEdgeId first = BoundaryEdgeId('diagonal-first');
  final BoundaryEdgeId second = BoundaryEdgeId('diagonal-second');

  late final SpaceBoundaryTopology before;
  late final SpaceBoundaryTopology after;
  late final BoundaryTopologyChangeSet lineage;

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
