import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/electrical_routing.dart';
import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/engine/normative_route_engine.dart';
import 'package:elecx/src/engine/port_snap_resolver.dart';
import 'package:elecx/src/features/editor/cable_canvas_hit_testing.dart';
import 'package:elecx/src/features/editor/cable_endpoint_transform_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('multi-surface route exposes source and target endpoint handles', () {
    final wallA = RoomSurfaceRef.wall('room', 0);
    final ceiling = RoomSurfaceRef.ceiling('room');
    final wallB = RoomSurfaceRef.wall('room', 2);
    final route = ElectricalCableRoute(
      id: 'r',
      source: const ElectricalEndpointRef(componentId: 'a', portId: 'out'),
      target: const ElectricalEndpointRef(componentId: 'b', portId: 'in'),
      segments: [
        ElectricalRouteSegment(
            surface: wallA,
            points: const [SurfacePointMm(10, 10), SurfacePointMm(10, 100)]),
        ElectricalRouteSegment(
            surface: ceiling,
            points: const [SurfacePointMm(10, 100), SurfacePointMm(900, 100)]),
        ElectricalRouteSegment(
            surface: wallB,
            points: const [SurfacePointMm(900, 100), SurfacePointMm(900, 10)]),
      ],
    );
    expect(
        CableCanvasHitTesting.hitTest(
            route: route,
            surface: wallA,
            point: const SurfacePointMm(10, 10),
            radiusMm: 5),
        isA<CableEndpointHit>());
    final target = CableCanvasHitTesting.hitTest(
        route: route,
        surface: wallB,
        point: const SurfacePointMm(900, 10),
        radiusMm: 5);
    expect(target, isA<CableEndpointHit>());
    expect((target! as CableEndpointHit).segmentIndex, 2);
  });

  test('multi-surface endpoint transform preserves unrelated segments', () {
    final wallA = RoomSurfaceRef.wall('room', 0);
    final ceiling = RoomSurfaceRef.ceiling('room');
    final route = ElectricalCableRoute(
      id: 'r',
      source:
          const ElectricalEndpointRef(componentId: 'a', portId: 'power-out'),
      target:
          const ElectricalEndpointRef(componentId: 'old', portId: 'power-in'),
      segments: [
        ElectricalRouteSegment(
            surface: wallA,
            points: const [SurfacePointMm(10, 10), SurfacePointMm(10, 100)]),
        ElectricalRouteSegment(
            surface: ceiling,
            points: const [SurfacePointMm(10, 100), SurfacePointMm(900, 100)]),
      ],
    );
    final components = [
      ElectricalComponentPlacement(
          id: 'a',
          type: ElectricalComponentType.powerSource,
          surface: wallA,
          position: const SurfacePointMm(10, 10),
          label: 'A',
          ports: ElectricalComponentDefaults.portsFor(
              ElectricalComponentType.powerSource)),
      ElectricalComponentPlacement(
          id: 'old',
          type: ElectricalComponentType.socketOutlet,
          surface: ceiling,
          position: const SurfacePointMm(900, 100),
          label: 'Old',
          ports: ElectricalComponentDefaults.portsFor(
              ElectricalComponentType.socketOutlet)),
      ElectricalComponentPlacement(
          id: 'new',
          type: ElectricalComponentType.socketOutlet,
          surface: ceiling,
          position: const SurfacePointMm(700, 300),
          label: 'New',
          ports: ElectricalComponentDefaults.portsFor(
              ElectricalComponentType.socketOutlet)),
    ];
    ElectricalCableRoute? committed;
    final session = CableEndpointTransformSession(onCommit: (_, after) {
      committed = after;
      return true;
    });
    expect(
        session.start(
            route: route,
            role: CableEndpointRole.target,
            components: components,
            context: RouteNormativeContext(
                surface: ceiling,
                widthMm: 1000,
                heightMm: 1000,
                edgeClearanceMm: 0)),
        isTrue);
    expect(
        session.preview(
            rawPoint: const MmPoint(700, 300),
            acquisitionRadiusMm: 50,
            releaseRadiusMm: 80,
            gridStepMm: 100),
        isTrue);
    expect(session.commit(), isTrue);
    expect(committed!.segments.first.points, route.segments.first.points);
    expect(committed!.segments.length, 2);
    expect(committed!.target.componentId, 'new');
  });
}
