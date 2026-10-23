import 'package:elecx/src/domain/boundary_host_migration.dart';
import 'package:elecx/src/domain/boundary_host_registry.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('remapping one space preserves foreign hosted references exactly', () {
    final spaceA = SpaceId('space-a');
    final spaceB = SpaceId('space-b');
    final aSource = BoundaryEdgeId('a-source');
    final aFirst = BoundaryEdgeId('a-first');
    final aSecond = BoundaryEdgeId('a-second');
    final aEast = BoundaryEdgeId('a-east');
    final aNorth = BoundaryEdgeId('a-north');
    final aWest = BoundaryEdgeId('a-west');
    final bBottom = BoundaryEdgeId('b-bottom');

    final beforeA = _rectangle(
      spaceId: spaceA,
      bottomIds: [aSource],
      bottomEdges: {aSource: _edge(aSource, spaceA, 0, 0, 4000, 0)},
      east: aEast,
      north: aNorth,
      west: aWest,
    );
    final afterA = _rectangle(
      spaceId: spaceA,
      bottomIds: [aFirst, aSecond],
      bottomEdges: {
        aFirst: _edge(aFirst, spaceA, 0, 0, 2000, 0),
        aSecond: _edge(aSecond, spaceA, 2000, 0, 4000, 0),
      },
      east: aEast,
      north: aNorth,
      west: aWest,
    );
    final foreign = BoundaryHostedReference.point(
      objectKey: 'component:foreign',
      objectKind: BoundaryHostedObjectKind.component,
      host: BoundaryEdgeHostRef(spaceId: spaceB, edgeId: bBottom),
      offsetMm: 777,
    );
    final registry = BoundaryHostedObjectRegistry({
      'component:edited': BoundaryHostedReference.point(
        objectKey: 'component:edited',
        objectKind: BoundaryHostedObjectKind.component,
        host: BoundaryEdgeHostRef(spaceId: spaceA, edgeId: aSource),
        offsetMm: 3000,
      ),
      foreign.objectKey: foreign,
    });
    final lineage = BoundaryTopologyChangeSet([
      BoundaryEdgeLineage.split(
        sourceEdgeId: aSource,
        resultEdgeIds: [aFirst, aSecond],
      ),
      BoundaryEdgeLineage.preserved(aEast),
      BoundaryEdgeLineage.preserved(aNorth),
      BoundaryEdgeLineage.preserved(aWest),
    ]);

    final result = registry.remapSpace(
      before: beforeA,
      after: afterA,
      lineage: lineage,
    );

    final edited = result['component:edited']!;
    expect(edited.host.edgeId, aSecond);
    expect(edited.startOffsetMm, 1000);

    final preserved = result[foreign.objectKey]!;
    expect(preserved, same(foreign));
    expect(preserved.objectKey, foreign.objectKey);
    expect(preserved.objectKind, foreign.objectKind);
    expect(preserved.host, foreign.host);
    expect(preserved.geometryKind, foreign.geometryKind);
    expect(preserved.startOffsetMm, foreign.startOffsetMm);
    expect(preserved.endOffsetMm, foreign.endOffsetMm);
  });
}

SpaceBoundaryTopology _rectangle({
  required SpaceId spaceId,
  required List<BoundaryEdgeId> bottomIds,
  required Map<BoundaryEdgeId, ProjectBoundaryEdge> bottomEdges,
  required BoundaryEdgeId east,
  required BoundaryEdgeId north,
  required BoundaryEdgeId west,
}) =>
    SpaceBoundaryTopology(
      spaceId: spaceId,
      orderedEdgeIds: [...bottomIds, east, north, west],
      edges: {
        ...bottomEdges,
        east: _edge(east, spaceId, 4000, 0, 4000, 3000),
        north: _edge(north, spaceId, 4000, 3000, 0, 3000),
        west: _edge(west, spaceId, 0, 3000, 0, 0),
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
