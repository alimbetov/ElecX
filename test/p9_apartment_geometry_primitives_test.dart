import 'package:elecx/src/domain/apartment_topology/apartment_geometry.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P9.6A rectilinear geometry primitives', () {
    test('P9.6-AT-001 rectangle normalization is stable under rotation', () {
      final first = RectilinearPolygonMm.normalized(const [
        BoundaryPointMm(xMm: 0, yMm: 0),
        BoundaryPointMm(xMm: 4000, yMm: 0),
        BoundaryPointMm(xMm: 4000, yMm: 3000),
        BoundaryPointMm(xMm: 0, yMm: 3000),
      ]);
      final rotated = RectilinearPolygonMm.normalized(const [
        BoundaryPointMm(xMm: 4000, yMm: 3000),
        BoundaryPointMm(xMm: 0, yMm: 3000),
        BoundaryPointMm(xMm: 0, yMm: 0),
        BoundaryPointMm(xMm: 4000, yMm: 0),
      ]);
      final reversed = RectilinearPolygonMm.normalized(const [
        BoundaryPointMm(xMm: 0, yMm: 0),
        BoundaryPointMm(xMm: 0, yMm: 3000),
        BoundaryPointMm(xMm: 4000, yMm: 3000),
        BoundaryPointMm(xMm: 4000, yMm: 0),
      ]);

      expect(rotated.stableSerialization, first.stableSerialization);
      expect(reversed.stableSerialization, first.stableSerialization);
      expect(first.areaMm2, 12000000);
    });

    test('P9.6-AT-002 collinear points collapse deterministically', () {
      final polygon = RectilinearPolygonMm.normalized(const [
        BoundaryPointMm(xMm: 0, yMm: 0),
        BoundaryPointMm(xMm: 2000, yMm: 0),
        BoundaryPointMm(xMm: 4000, yMm: 0),
        BoundaryPointMm(xMm: 4000, yMm: 3000),
        BoundaryPointMm(xMm: 0, yMm: 3000),
        BoundaryPointMm(xMm: 0, yMm: 0),
      ]);

      expect(polygon.vertices, hasLength(4));
      expect(
        polygon.stableSerialization,
        '0,0;4000,0;4000,3000;0,3000',
      );
    });

    test('P9.6-AT-004 self intersection fails closed', () {
      expect(
        () => RectilinearPolygonMm.normalized(const [
          BoundaryPointMm(xMm: 0, yMm: 0),
          BoundaryPointMm(xMm: 4000, yMm: 0),
          BoundaryPointMm(xMm: 4000, yMm: 3000),
          BoundaryPointMm(xMm: 2000, yMm: 3000),
          BoundaryPointMm(xMm: 2000, yMm: -1000),
          BoundaryPointMm(xMm: 0, yMm: -1000),
        ]),
        throwsArgumentError,
      );
    });

    test('P9.6-AT-009 coordinates must lie on 10mm grid', () {
      expect(
        () => RectilinearPolygonMm.normalized(const [
          BoundaryPointMm(xMm: 0, yMm: 0),
          BoundaryPointMm(xMm: 4001, yMm: 0),
          BoundaryPointMm(xMm: 4001, yMm: 3000),
          BoundaryPointMm(xMm: 0, yMm: 3000),
        ]),
        throwsArgumentError,
      );
    });

    test('exact collinear segment intersection derives shared boundary', () {
      final first = GeometrySegmentMm(
        start: const BoundaryPointMm(xMm: 4000, yMm: 0),
        end: const BoundaryPointMm(xMm: 4000, yMm: 3000),
      );
      final second = GeometrySegmentMm(
        start: const BoundaryPointMm(xMm: 4000, yMm: 1000),
        end: const BoundaryPointMm(xMm: 4000, yMm: 5000),
      );

      final overlap = intersectCollinearSegments(first, second);
      expect(overlap, isNotNull);
      expect(overlap!.lengthMm, 2000);
      expect(overlap.start, const BoundaryPointMm(xMm: 4000, yMm: 1000));
      expect(overlap.end, const BoundaryPointMm(xMm: 4000, yMm: 3000));
    });

    test('P9.6-AT-016 polygon segments are P7 BoundaryPointMm compatible', () {
      final polygon = RectilinearPolygonMm.rectangle(
        xMm: 100,
        yMm: 200,
        widthMm: 3200,
        heightMm: 2800,
      );

      expect(polygon.vertices, everyElement(isA<BoundaryPointMm>()));
      expect(polygon.segments, hasLength(4));
      expect(
        polygon.segments.every((segment) => segment.lengthMm > 0),
        isTrue,
      );
    });
  });
}
