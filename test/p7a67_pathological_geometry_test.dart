import 'package:elecx/src/domain/boundary_geometry_integrity.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P7A-6.7 pathological geometry qualification', () {
    test('large millimetre coordinates remain exact and valid', () {
      final topology = _polygon(
        SpaceId('large'),
        const [
          BoundaryPointMm(xMm: 1000000000, yMm: 1000000000),
          BoundaryPointMm(xMm: 1004000000, yMm: 1000000000),
          BoundaryPointMm(xMm: 1004000000, yMm: 1003000000),
          BoundaryPointMm(xMm: 1000000000, yMm: 1003000000),
        ],
      );

      expect(topology.validate(), isEmpty);
      expect(BoundaryGeometryIntegrity.validate(topology), isEmpty);
    });

    test('long thin room remains a valid non-degenerate polygon', () {
      final topology = _polygon(
        SpaceId('thin'),
        const [
          BoundaryPointMm(xMm: 0, yMm: 0),
          BoundaryPointMm(xMm: 10000000, yMm: 0),
          BoundaryPointMm(xMm: 10000000, yMm: 301),
          BoundaryPointMm(xMm: 0, yMm: 301),
        ],
      );

      expect(BoundaryGeometryIntegrity.validate(topology), isEmpty);
    });

    test('200-edge forward-collinear simple loop stays valid', () {
      final points = <BoundaryPointMm>[];
      const step = 100;
      for (var i = 0; i < 50; i++) {
        points.add(BoundaryPointMm(xMm: i * step, yMm: 0));
      }
      for (var i = 0; i < 50; i++) {
        points.add(BoundaryPointMm(xMm: 5000, yMm: i * step));
      }
      for (var i = 0; i < 50; i++) {
        points.add(BoundaryPointMm(xMm: 5000 - i * step, yMm: 5000));
      }
      for (var i = 0; i < 50; i++) {
        points.add(BoundaryPointMm(xMm: 0, yMm: 5000 - i * step));
      }
      final topology = _polygon(SpaceId('many-edges'), points);

      expect(topology.orderedEdgeIds, hasLength(200));
      expect(topology.validate(), isEmpty);
      expect(BoundaryGeometryIntegrity.validate(topology), isEmpty);
    });

    test('near-collinear concave geometry is not normalized into collinear', () {
      final topology = _polygon(
        SpaceId('near-collinear'),
        const [
          BoundaryPointMm(xMm: 0, yMm: 0),
          BoundaryPointMm(xMm: 5000, yMm: 0),
          BoundaryPointMm(xMm: 5000, yMm: 4000),
          BoundaryPointMm(xMm: 2501, yMm: 3999),
          BoundaryPointMm(xMm: 2500, yMm: 2000),
          BoundaryPointMm(xMm: 2499, yMm: 3999),
          BoundaryPointMm(xMm: 0, yMm: 4000),
        ],
      );

      expect(topology.validate(), isEmpty);
      expect(BoundaryGeometryIntegrity.validate(topology), isEmpty);
    });

    test('zero-area back-and-forth loop fails closed', () {
      final topology = _polygon(
        SpaceId('zero-area'),
        const [
          BoundaryPointMm(xMm: 0, yMm: 0),
          BoundaryPointMm(xMm: 3000, yMm: 0),
          BoundaryPointMm(xMm: 6000, yMm: 0),
          BoundaryPointMm(xMm: 3000, yMm: 0),
        ],
      );

      expect(
        BoundaryGeometryIntegrity.validate(topology)
            .map((issue) => issue.code),
        contains(BoundaryGeometryIssueCode.degenerateArea),
      );
    });

    test('large-coordinate bow-tie self intersection fails closed', () {
      final topology = _polygon(
        SpaceId('bow-tie'),
        const [
          BoundaryPointMm(xMm: 1000000000, yMm: 1000000000),
          BoundaryPointMm(xMm: 1005000000, yMm: 1005000000),
          BoundaryPointMm(xMm: 1000000000, yMm: 1005000000),
          BoundaryPointMm(xMm: 1005000000, yMm: 1000000000),
        ],
      );

      expect(
        BoundaryGeometryIntegrity.validate(topology)
            .map((issue) => issue.code),
        contains(BoundaryGeometryIssueCode.selfIntersection),
      );
    });
  });
}

SpaceBoundaryTopology _polygon(
  SpaceId spaceId,
  List<BoundaryPointMm> points,
) {
  final ids = [
    for (var index = 0; index < points.length; index++)
      BoundaryEdgeId('${spaceId.value}-edge-$index'),
  ];
  return SpaceBoundaryTopology(
    spaceId: spaceId,
    orderedEdgeIds: ids,
    edges: {
      for (var index = 0; index < points.length; index++)
        ids[index]: ProjectBoundaryEdge(
          id: ids[index],
          spaceId: spaceId,
          start: points[index],
          end: points[(index + 1) % points.length],
        ),
    },
  );
}
