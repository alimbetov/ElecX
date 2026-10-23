import 'package:elecx/src/domain/boundary_host_migration.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('one-to-three lineage selects unique middle child geometrically', () {
    final fixture = _Fixture();

    final point = fixture.remap(
      BoundaryHostedReference.point(
        objectKey: 'component:middle',
        objectKind: BoundaryHostedObjectKind.component,
        host: fixture.sourceHost,
        offsetMm: 2500,
      ),
    );
    expect(point.host.edgeId, fixture.middle);
    expect(point.startOffsetMm, 500);

    final interval = fixture.remap(
      BoundaryHostedReference.interval(
        objectKey: 'opening:middle',
        objectKind: BoundaryHostedObjectKind.opening,
        host: fixture.sourceHost,
        startOffsetMm: 2500,
        endOffsetMm: 3500,
      ),
    );
    expect(interval.host.edgeId, fixture.middle);
    expect(interval.startOffsetMm, 500);
    expect(interval.endOffsetMm, 1500);
  });

  test('one-to-three lineage fails closed on internal child boundary', () {
    final fixture = _Fixture();

    for (final offset in [2000, 4000]) {
      expect(
        () => fixture.remap(
          BoundaryHostedReference.point(
            objectKey: 'route:boundary:$offset',
            objectKind: BoundaryHostedObjectKind.routeAnchor,
            host: fixture.sourceHost,
            offsetMm: offset,
          ),
        ),
        throwsA(
          isA<BoundaryHostMigrationException>().having(
            (error) => error.code,
            'code',
            BoundaryHostMigrationIssueCode.ambiguousPointRemap,
          ),
        ),
      );
    }
  });
}

final class _Fixture {
  _Fixture() {
    before = _topology(
      bottomIds: [source],
      bottomEdges: {source: edge(source, 0, 6000)},
    );
    after = _topology(
      bottomIds: [first, middle, last],
      bottomEdges: {
        first: edge(first, 0, 2000),
        middle: edge(middle, 2000, 4000),
        last: edge(last, 4000, 6000),
      },
    );
    lineage = BoundaryTopologyChangeSet([
      BoundaryEdgeLineage.split(
        sourceEdgeId: source,
        resultEdgeIds: [first, middle, last],
      ),
      BoundaryEdgeLineage.preserved(east),
      BoundaryEdgeLineage.preserved(north),
      BoundaryEdgeLineage.preserved(west),
    ]);
  }

  final spaceId = SpaceId('multi-child-space');
  final source = BoundaryEdgeId('source');
  final first = BoundaryEdgeId('first');
  final middle = BoundaryEdgeId('middle');
  final last = BoundaryEdgeId('last');
  final east = BoundaryEdgeId('east');
  final north = BoundaryEdgeId('north');
  final west = BoundaryEdgeId('west');

  late final SpaceBoundaryTopology before;
  late final SpaceBoundaryTopology after;
  late final BoundaryTopologyChangeSet lineage;

  BoundaryEdgeHostRef get sourceHost =>
      BoundaryEdgeHostRef(spaceId: spaceId, edgeId: source);

  BoundaryHostedRemap remap(BoundaryHostedReference reference) =>
      BoundaryHostedObjectRemapper.remapAll(
        before: before,
        after: after,
        lineage: lineage,
        references: [reference],
      ).single;

  SpaceBoundaryTopology _topology({
    required List<BoundaryEdgeId> bottomIds,
    required Map<BoundaryEdgeId, ProjectBoundaryEdge> bottomEdges,
  }) =>
      SpaceBoundaryTopology(
        spaceId: spaceId,
        orderedEdgeIds: [...bottomIds, east, north, west],
        edges: {
          ...bottomEdges,
          east: ProjectBoundaryEdge(
            id: east,
            spaceId: spaceId,
            start: const BoundaryPointMm(xMm: 6000, yMm: 0),
            end: const BoundaryPointMm(xMm: 6000, yMm: 3000),
          ),
          north: ProjectBoundaryEdge(
            id: north,
            spaceId: spaceId,
            start: const BoundaryPointMm(xMm: 6000, yMm: 3000),
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

  ProjectBoundaryEdge edge(BoundaryEdgeId id, int start, int end) =>
      ProjectBoundaryEdge(
        id: id,
        spaceId: spaceId,
        start: BoundaryPointMm(xMm: start, yMm: 0),
        end: BoundaryPointMm(xMm: end, yMm: 0),
      );
}
