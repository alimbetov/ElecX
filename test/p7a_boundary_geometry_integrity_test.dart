import 'package:elecx/src/domain/boundary_geometry_integrity.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P7A boundary geometry integrity', () {
    test('simple concave polygon remains valid', () {
      final topology = _topology(const [
        BoundaryPointMm(xMm: 0, yMm: 0),
        BoundaryPointMm(xMm: 3000, yMm: 0),
        BoundaryPointMm(xMm: 3000, yMm: 3000),
        BoundaryPointMm(xMm: 1500, yMm: 1500),
        BoundaryPointMm(xMm: 0, yMm: 3000),
      ]);

      expect(BoundaryGeometryIntegrity.validate(topology), isEmpty);
    });

    test('non-adjacent crossing is rejected', () {
      final topology = _topology(const [
        BoundaryPointMm(xMm: 0, yMm: 0),
        BoundaryPointMm(xMm: 3000, yMm: 3000),
        BoundaryPointMm(xMm: 0, yMm: 3000),
        BoundaryPointMm(xMm: 3000, yMm: 0),
      ]);

      expect(
        BoundaryGeometryIntegrity.validate(topology).map((issue) => issue.code),
        contains(BoundaryGeometryIssueCode.selfIntersection),
      );
    });

    test('adjacent edge backtracking overlap is rejected', () {
      final topology = _topology(const [
        BoundaryPointMm(xMm: 0, yMm: 0),
        BoundaryPointMm(xMm: 3000, yMm: 0),
        BoundaryPointMm(xMm: 1000, yMm: 0),
        BoundaryPointMm(xMm: 1000, yMm: 2000),
        BoundaryPointMm(xMm: 0, yMm: 2000),
      ]);

      expect(
        BoundaryGeometryIntegrity.validate(topology).map((issue) => issue.code),
        contains(BoundaryGeometryIssueCode.adjacentOverlap),
      );
    });

    test('forward collinear adjacent edges remain valid', () {
      final topology = _topology(const [
        BoundaryPointMm(xMm: 0, yMm: 0),
        BoundaryPointMm(xMm: 1000, yMm: 0),
        BoundaryPointMm(xMm: 3000, yMm: 0),
        BoundaryPointMm(xMm: 3000, yMm: 2000),
        BoundaryPointMm(xMm: 0, yMm: 2000),
      ]);

      expect(BoundaryGeometryIntegrity.validate(topology), isEmpty);
    });
  });
}

SpaceBoundaryTopology _topology(List<BoundaryPointMm> points) {
  final spaceId = SpaceId('space-geometry');
  final ids = <BoundaryEdgeId>[
    for (var index = 0; index < points.length; index++)
      BoundaryEdgeId('edge-$index'),
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
