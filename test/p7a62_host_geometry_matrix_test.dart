import 'package:elecx/src/domain/boundary_host_migration.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P7A-6.2 hosted geometry ambiguity matrix', () {
    for (final kind in const [
      BoundaryHostedObjectKind.component,
      BoundaryHostedObjectKind.cableEndpoint,
      BoundaryHostedObjectKind.routeAnchor,
    ]) {
      test('${kind.name} point before/exact/after split obeys one rule', () {
        final fixture = _AxisSplitFixture();

        final before = fixture.remapPoint(kind: kind, offsetMm: 1999);
        expect(before.host.edgeId, fixture.first);
        expect(before.startOffsetMm, 1999);

        expect(
          () => fixture.remapPoint(kind: kind, offsetMm: 2000),
          throwsA(
            isA<BoundaryHostMigrationException>().having(
              (error) => error.code,
              'code',
              BoundaryHostMigrationIssueCode.ambiguousPointRemap,
            ),
          ),
        );

        final after = fixture.remapPoint(kind: kind, offsetMm: 2001);
        expect(after.host.edgeId, fixture.second);
        expect(after.startOffsetMm, 1);
      });
    }

    test('opening ending exactly at split remains on first child', () {
      final fixture = _AxisSplitFixture();
      final result = fixture.remapInterval(start: 1200, end: 2000);

      expect(result.host.edgeId, fixture.first);
      expect(result.startOffsetMm, 1200);
      expect(result.endOffsetMm, 2000);
    });

    test('opening starting exactly at split remains on second child', () {
      final fixture = _AxisSplitFixture();
      final result = fixture.remapInterval(start: 2000, end: 2800);

      expect(result.host.edgeId, fixture.second);
      expect(result.startOffsetMm, 0);
      expect(result.endOffsetMm, 800);
    });

    test('opening crossing split by one millimetre fails closed', () {
      final fixture = _AxisSplitFixture();

      expect(
        () => fixture.remapInterval(start: 1999, end: 2001),
        throwsA(
          isA<BoundaryHostMigrationException>().having(
            (error) => error.code,
            'code',
            BoundaryHostMigrationIssueCode.intervalCrossesResultEdges,
          ),
        ),
      );
    });

    test('split then merge preserves physical point offsets', () {
      final fixture = _AxisSplitFixture();
      final merged = BoundaryEdgeId('merged');
      final mergedTopology = SpaceBoundaryTopology(
        spaceId: fixture.spaceId,
        orderedEdgeIds: [merged, fixture.east, fixture.north, fixture.west],
        edges: {
          merged: fixture.edge(merged, 0, 0, 4000, 0),
          fixture.east: fixture.edge(fixture.east, 4000, 0, 4000, 3000),
          fixture.north: fixture.edge(fixture.north, 4000, 3000, 0, 3000),
          fixture.west: fixture.edge(fixture.west, 0, 3000, 0, 0),
        },
      );
      final mergeLineage = BoundaryTopologyChangeSet([
        BoundaryEdgeLineage.merged(
          sourceEdgeIds: [fixture.first, fixture.second],
          resultEdgeId: merged,
        ),
        BoundaryEdgeLineage.preserved(fixture.east),
        BoundaryEdgeLineage.preserved(fixture.north),
        BoundaryEdgeLineage.preserved(fixture.west),
      ]);

      final firstSplit = fixture.remapPoint(
        kind: BoundaryHostedObjectKind.component,
        offsetMm: 1500,
      );
      final secondSplit = fixture.remapPoint(
        kind: BoundaryHostedObjectKind.routeAnchor,
        offsetMm: 2500,
      );

      final mergedResults = BoundaryHostedObjectRemapper.remapAll(
        before: fixture.after,
        after: mergedTopology,
        lineage: mergeLineage,
        references: [
          BoundaryHostedReference.point(
            objectKey: 'component:first',
            objectKind: BoundaryHostedObjectKind.component,
            host: firstSplit.host,
            offsetMm: firstSplit.startOffsetMm!,
          ),
          BoundaryHostedReference.point(
            objectKey: 'route:second',
            objectKind: BoundaryHostedObjectKind.routeAnchor,
            host: secondSplit.host,
            offsetMm: secondSplit.startOffsetMm!,
          ),
        ],
      );

      expect(mergedResults[0].host.edgeId, merged);
      expect(mergedResults[0].startOffsetMm, 1500);
      expect(mergedResults[1].host.edgeId, merged);
      expect(mergedResults[1].startOffsetMm, 2500);
    });
  });
}

final class _AxisSplitFixture {
  _AxisSplitFixture() {
    before = SpaceBoundaryTopology(
      spaceId: spaceId,
      orderedEdgeIds: [source, east, north, west],
      edges: {
        source: edge(source, 0, 0, 4000, 0),
        east: edge(east, 4000, 0, 4000, 3000),
        north: edge(north, 4000, 3000, 0, 3000),
        west: edge(west, 0, 3000, 0, 0),
      },
    );
    after = SpaceBoundaryTopology(
      spaceId: spaceId,
      orderedEdgeIds: [first, second, east, north, west],
      edges: {
        first: edge(first, 0, 0, 2000, 0),
        second: edge(second, 2000, 0, 4000, 0),
        east: edge(east, 4000, 0, 4000, 3000),
        north: edge(north, 4000, 3000, 0, 3000),
        west: edge(west, 0, 3000, 0, 0),
      },
    );
    lineage = BoundaryTopologyChangeSet([
      BoundaryEdgeLineage.split(
        sourceEdgeId: source,
        resultEdgeIds: [first, second],
      ),
      BoundaryEdgeLineage.preserved(east),
      BoundaryEdgeLineage.preserved(north),
      BoundaryEdgeLineage.preserved(west),
    ]);
  }

  final spaceId = SpaceId('matrix-space');
  final source = BoundaryEdgeId('source');
  final first = BoundaryEdgeId('first');
  final second = BoundaryEdgeId('second');
  final east = BoundaryEdgeId('east');
  final north = BoundaryEdgeId('north');
  final west = BoundaryEdgeId('west');

  late final SpaceBoundaryTopology before;
  late final SpaceBoundaryTopology after;
  late final BoundaryTopologyChangeSet lineage;

  BoundaryHostedRemap remapPoint({
    required BoundaryHostedObjectKind kind,
    required int offsetMm,
  }) =>
      BoundaryHostedObjectRemapper.remapAll(
        before: before,
        after: after,
        lineage: lineage,
        references: [
          BoundaryHostedReference.point(
            objectKey: '${kind.name}:$offsetMm',
            objectKind: kind,
            host: BoundaryEdgeHostRef(spaceId: spaceId, edgeId: source),
            offsetMm: offsetMm,
          ),
        ],
      ).single;

  BoundaryHostedRemap remapInterval({required int start, required int end}) =>
      BoundaryHostedObjectRemapper.remapAll(
        before: before,
        after: after,
        lineage: lineage,
        references: [
          BoundaryHostedReference.interval(
            objectKey: 'opening:$start:$end',
            objectKind: BoundaryHostedObjectKind.opening,
            host: BoundaryEdgeHostRef(spaceId: spaceId, edgeId: source),
            startOffsetMm: start,
            endOffsetMm: end,
          ),
        ],
      ).single;

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
