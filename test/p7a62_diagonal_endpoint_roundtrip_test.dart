import 'package:elecx/src/domain/boundary_host_migration.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rounded diagonal endpoint survives split then merge without 1mm drift',
      () {
    final spaceId = SpaceId('space');
    final source = BoundaryEdgeId('source');
    final first = BoundaryEdgeId('first');
    final second = BoundaryEdgeId('second');
    final merged = BoundaryEdgeId('merged');
    final sideB = BoundaryEdgeId('side-b');
    final sideC = BoundaryEdgeId('side-c');

    final before = _triangle(
      spaceId: spaceId,
      firstIds: [source],
      firstEdges: {source: _edge(source, spaceId, 0, 0, 600, 600)},
      sideB: sideB,
      sideC: sideC,
    );
    final split = _triangle(
      spaceId: spaceId,
      firstIds: [first, second],
      firstEdges: {
        first: _edge(first, spaceId, 0, 0, 300, 300),
        second: _edge(second, spaceId, 300, 300, 600, 600),
      },
      sideB: sideB,
      sideC: sideC,
    );
    final mergedTopology = _triangle(
      spaceId: spaceId,
      firstIds: [merged],
      firstEdges: {merged: _edge(merged, spaceId, 0, 0, 600, 600)},
      sideB: sideB,
      sideC: sideC,
    );

    final splitResult = BoundaryHostedObjectRemapper.remapAll(
      before: before,
      after: split,
      lineage: BoundaryTopologyChangeSet([
        BoundaryEdgeLineage.split(
          sourceEdgeId: source,
          resultEdgeIds: [first, second],
        ),
        BoundaryEdgeLineage.preserved(sideB),
        BoundaryEdgeLineage.preserved(sideC),
      ]),
      references: [
        BoundaryHostedReference.point(
          objectKey: 'cable:endpoint',
          objectKind: BoundaryHostedObjectKind.cableEndpoint,
          host: BoundaryEdgeHostRef(spaceId: spaceId, edgeId: source),
          offsetMm: 849,
        ),
      ],
    ).single;

    expect(splitResult.host.edgeId, second);
    expect(splitResult.startOffsetMm, 424);

    final mergedResult = BoundaryHostedObjectRemapper.remapAll(
      before: split,
      after: mergedTopology,
      lineage: BoundaryTopologyChangeSet([
        BoundaryEdgeLineage.merged(
          sourceEdgeIds: [first, second],
          resultEdgeId: merged,
        ),
        BoundaryEdgeLineage.preserved(sideB),
        BoundaryEdgeLineage.preserved(sideC),
      ]),
      references: [
        BoundaryHostedReference.point(
          objectKey: 'cable:endpoint',
          objectKind: BoundaryHostedObjectKind.cableEndpoint,
          host: splitResult.host,
          offsetMm: splitResult.startOffsetMm!,
        ),
      ],
    ).single;

    expect(mergedResult.host.edgeId, merged);
    expect(mergedResult.startOffsetMm, 849);
  });
}

SpaceBoundaryTopology _triangle({
  required SpaceId spaceId,
  required List<BoundaryEdgeId> firstIds,
  required Map<BoundaryEdgeId, ProjectBoundaryEdge> firstEdges,
  required BoundaryEdgeId sideB,
  required BoundaryEdgeId sideC,
}) =>
    SpaceBoundaryTopology(
      spaceId: spaceId,
      orderedEdgeIds: [...firstIds, sideB, sideC],
      edges: {
        ...firstEdges,
        sideB: _edge(sideB, spaceId, 600, 600, 0, 1200),
        sideC: _edge(sideC, spaceId, 0, 1200, 0, 0),
      },
    );

ProjectBoundaryEdge _edge(
  BoundaryEdgeId id,
  SpaceId spaceId,
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
