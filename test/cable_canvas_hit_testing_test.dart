import 'package:elecx/src/domain/electrical_routing.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/engine/port_snap_resolver.dart';
import 'package:elecx/src/features/editor/cable_canvas_hit_testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final surface = RoomSurfaceRef.wall('room-1', 0);

  ElectricalCableRoute route(List<SurfacePointMm> points) =>
      ElectricalCableRoute(
        id: 'route-1',
        source: const ElectricalEndpointRef(componentId: 'a', portId: 'out'),
        target: const ElectricalEndpointRef(componentId: 'b', portId: 'in'),
        segments: [ElectricalRouteSegment(surface: surface, points: points)],
      );

  test('endpoint handles outrank vertices and segments', () {
    final cable = route(const [
      SurfacePointMm(100, 100),
      SurfacePointMm(500, 100),
      SurfacePointMm(500, 500),
    ]);

    final hit = CableCanvasHitTesting.hitTest(
      route: cable,
      surface: surface,
      point: const SurfacePointMm(105, 100),
      radiusMm: 20,
    );

    expect(hit, isA<CableEndpointHit>());
    expect((hit! as CableEndpointHit).role, CableEndpointRole.source);
  });

  test('interior vertex can be selected', () {
    final cable = route(const [
      SurfacePointMm(100, 100),
      SurfacePointMm(500, 100),
      SurfacePointMm(500, 500),
    ]);

    final hit = CableCanvasHitTesting.hitTest(
      route: cable,
      surface: surface,
      point: const SurfacePointMm(500, 105),
      radiusMm: 20,
    );

    expect(hit, isA<CableVertexHit>());
    expect((hit! as CableVertexHit).pointIndex, 1);
  });

  test('vertex drag creates a movable orthogonal dogleg', () {
    final moved = CableCanvasHitTesting.moveVertex(
      points: const [
        SurfacePointMm(100, 100),
        SurfacePointMm(300, 100),
        SurfacePointMm(300, 400),
      ],
      pointIndex: 1,
      target: const SurfacePointMm(450, 250),
    );

    expect(moved, const [
      SurfacePointMm(100, 100),
      SurfacePointMm(450, 100),
      SurfacePointMm(450, 250),
      SurfacePointMm(300, 250),
      SurfacePointMm(300, 400),
    ]);
    for (var i = 1; i < moved.length; i++) {
      expect(
        moved[i - 1].xMm == moved[i].xMm || moved[i - 1].yMm == moved[i].yMm,
        isTrue,
      );
    }
  });

  test('three-point auto route exposes endpoint-adjacent segment handles', () {
    final cable = route(const [
      SurfacePointMm(100, 100),
      SurfacePointMm(500, 100),
      SurfacePointMm(500, 500),
    ]);

    final hit = CableCanvasHitTesting.hitTest(
      route: cable,
      surface: surface,
      point: const SurfacePointMm(300, 100),
      radiusMm: 20,
    );

    expect(hit, isA<CableSegmentHit>());
    expect((hit! as CableSegmentHit).edgeIndex, 0);
  });

  test('first segment drag inserts dogleg and keeps source endpoint fixed', () {
    final points = const [
      SurfacePointMm(100, 100),
      SurfacePointMm(500, 100),
      SurfacePointMm(500, 500),
    ];

    final moved = CableCanvasHitTesting.moveSegment(
      points: points,
      edgeIndex: 0,
      target: const SurfacePointMm(300, 220),
    );

    expect(moved, const [
      SurfacePointMm(100, 100),
      SurfacePointMm(100, 220),
      SurfacePointMm(500, 220),
      SurfacePointMm(500, 500),
    ]);
    expect(moved.first, points.first);
    expect(moved.last, points.last);
  });

  test('last segment drag inserts dogleg and keeps target endpoint fixed', () {
    final points = const [
      SurfacePointMm(100, 100),
      SurfacePointMm(500, 100),
      SurfacePointMm(500, 500),
    ];

    final moved = CableCanvasHitTesting.moveSegment(
      points: points,
      edgeIndex: 1,
      target: const SurfacePointMm(650, 300),
    );

    expect(moved, const [
      SurfacePointMm(100, 100),
      SurfacePointMm(650, 100),
      SurfacePointMm(650, 500),
      SurfacePointMm(500, 500),
    ]);
    expect(moved.first, points.first);
    expect(moved.last, points.last);
  });

  test('interior segment drag keeps orthogonal run parallel', () {
    final points = const [
      SurfacePointMm(100, 100),
      SurfacePointMm(300, 100),
      SurfacePointMm(300, 400),
      SurfacePointMm(700, 400),
      SurfacePointMm(700, 700),
    ];

    final moved = CableCanvasHitTesting.moveSegment(
      points: points,
      edgeIndex: 2,
      target: const SurfacePointMm(450, 520),
    );

    expect(moved[2], const SurfacePointMm(300, 520));
    expect(moved[3], const SurfacePointMm(700, 520));
    expect(moved.first, points.first);
    expect(moved.last, points.last);
  });
}
