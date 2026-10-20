import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/electrical_routing.dart';
import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/engine/normative_route_engine.dart';
import 'package:elecx/src/engine/port_snap_resolver.dart';
import 'package:elecx/src/features/editor/cable_endpoint_transform_session.dart';
import 'package:elecx/src/features/editor/cable_route_constraints.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'target endpoint snaps to compatible port and autoroutes before commit',
    () {
      final surface = RoomSurfaceRef.wall('room-101', 0);
      final board = _component(
        id: 'board-1',
        type: ElectricalComponentType.distributionBoard,
        surface: surface,
        position: const SurfacePointMm(200, 200),
      );
      final oldSocket = _component(
        id: 'socket-old',
        type: ElectricalComponentType.socketOutlet,
        surface: surface,
        position: const SurfacePointMm(1400, 900),
      );
      final newSocket = _component(
        id: 'socket-new',
        type: ElectricalComponentType.socketOutlet,
        surface: surface,
        position: const SurfacePointMm(1800, 1400),
      );
      final route = _route(
        surface: surface,
        points: const [
          SurfacePointMm(200, 200),
          SurfacePointMm(200, 900),
          SurfacePointMm(1400, 900),
        ],
      );

      ElectricalCableRoute? committed;
      final session = CableEndpointTransformSession(
        onCommit: (_, after) {
          committed = after;
          return true;
        },
      );
      addTearDown(session.dispose);

      expect(
        session.start(
          route: route,
          role: CableEndpointRole.target,
          components: [board, oldSocket, newSocket],
          context: _context(surface),
        ),
        isTrue,
      );
      expect(
        session.preview(
          rawPoint: const MmPoint(1780, 1390),
          acquisitionRadiusMm: 80,
          releaseRadiusMm: 130,
          gridStepMm: 100,
        ),
        isTrue,
      );
      expect(session.previewState!.snap.sourceId, 'socket-new:power-in');
      expect(session.previewState!.route.target.componentId, 'socket-new');
      expect(session.previewState!.route.segments.single.points.last.xMm, 1800);
      expect(session.previewState!.route.segments.single.points.last.yMm, 1400);
      expect(session.commit(), isTrue);
      expect(committed!.target.componentId, 'socket-new');
    },
  );

  test('endpoint cannot commit while no compatible port is captured', () {
    final surface = RoomSurfaceRef.wall('room-101', 0);
    final route = _route(
      surface: surface,
      points: const [SurfacePointMm(200, 200), SurfacePointMm(1800, 1400)],
    );
    final session = CableEndpointTransformSession(onCommit: (_, __) => true);
    addTearDown(session.dispose);

    expect(
      session.start(
        route: route,
        role: CableEndpointRole.target,
        components: const [],
        context: _context(surface),
      ),
      isTrue,
    );
    expect(
      session.preview(
        rawPoint: const MmPoint(1000, 1000),
        acquisitionRadiusMm: 80,
        releaseRadiusMm: 130,
        gridStepMm: 100,
      ),
      isFalse,
    );
    expect(session.commit(), isFalse);
  });

  test('endpoint reroute preserves mandatory waypoints in segment order', () {
    final surface = RoomSurfaceRef.wall('room-101', 0);
    final board = _component(
      id: 'board-1',
      type: ElectricalComponentType.distributionBoard,
      surface: surface,
      position: const SurfacePointMm(200, 200),
    );
    final oldSocket = _component(
      id: 'socket-old',
      type: ElectricalComponentType.socketOutlet,
      surface: surface,
      position: const SurfacePointMm(1400, 900),
    );
    final newSocket = _component(
      id: 'socket-new',
      type: ElectricalComponentType.socketOutlet,
      surface: surface,
      position: const SurfacePointMm(1800, 1400),
    );
    const waypoint = SurfacePointMm(1000, 900);
    final route = _route(
      surface: surface,
      points: const [
        SurfacePointMm(200, 200),
        SurfacePointMm(200, 900),
        waypoint,
        SurfacePointMm(1400, 900),
      ],
    );
    final constraints = CableRouteConstraints(
      mandatoryWaypoints: const [
        CableMandatoryWaypoint(
          segmentIndex: 0,
          pointIndex: 2,
          point: waypoint,
        ),
      ],
    );
    final session = CableEndpointTransformSession(onCommit: (_, __) => true);
    addTearDown(session.dispose);

    expect(
      session.start(
        route: route,
        role: CableEndpointRole.target,
        components: [board, oldSocket, newSocket],
        context: _context(surface),
        constraints: constraints,
      ),
      isTrue,
    );
    expect(
      session.preview(
        rawPoint: const MmPoint(1790, 1390),
        acquisitionRadiusMm: 80,
        releaseRadiusMm: 130,
        gridStepMm: 100,
      ),
      isTrue,
    );

    final preview = session.previewState!;
    expect(preview.validation.isValid, isTrue);
    expect(preview.route.target.componentId, 'socket-new');
    expect(preview.route.segments.single.points, contains(waypoint));
    expect(preview.route.segments.single.points.first, const SurfacePointMm(200, 200));
    expect(preview.route.segments.single.points.last, const SurfacePointMm(1800, 1400));
  });

  test('locked endpoint segment cannot start endpoint transform', () {
    final surface = RoomSurfaceRef.wall('room-101', 0);
    final route = _route(
      surface: surface,
      points: const [
        SurfacePointMm(200, 200),
        SurfacePointMm(1400, 200),
      ],
    );
    final session = CableEndpointTransformSession(onCommit: (_, __) => true);
    addTearDown(session.dispose);

    expect(
      session.start(
        route: route,
        role: CableEndpointRole.target,
        components: const [],
        context: _context(surface),
        constraints: CableRouteConstraints(lockedSegments: {0}),
      ),
      isFalse,
    );
    expect(session.active, isFalse);
  });

  test('stale mandatory waypoint prevents endpoint transform start', () {
    final surface = RoomSurfaceRef.wall('room-101', 0);
    final route = _route(
      surface: surface,
      points: const [
        SurfacePointMm(200, 200),
        SurfacePointMm(1400, 200),
      ],
    );
    final session = CableEndpointTransformSession(onCommit: (_, __) => true);
    addTearDown(session.dispose);

    expect(
      session.start(
        route: route,
        role: CableEndpointRole.target,
        components: const [],
        context: _context(surface),
        constraints: CableRouteConstraints(
          mandatoryWaypoints: const [
            CableMandatoryWaypoint(
              segmentIndex: 0,
              pointIndex: 1,
              point: SurfacePointMm(900, 900),
            ),
          ],
        ),
      ),
      isFalse,
    );
    expect(session.active, isFalse);
  });
}

ElectricalComponentPlacement _component({
  required String id,
  required ElectricalComponentType type,
  required RoomSurfaceRef surface,
  required SurfacePointMm position,
}) =>
    ElectricalComponentPlacement(
      id: id,
      type: type,
      surface: surface,
      position: position,
      label: id,
      ports: ElectricalComponentDefaults.portsFor(type),
    );

ElectricalCableRoute _route({
  required RoomSurfaceRef surface,
  required List<SurfacePointMm> points,
}) =>
    ElectricalCableRoute(
      id: 'route-1',
      source: const ElectricalEndpointRef(
        componentId: 'board-1',
        portId: 'power-out',
      ),
      target: const ElectricalEndpointRef(
        componentId: 'socket-old',
        portId: 'power-in',
      ),
      segments: [ElectricalRouteSegment(surface: surface, points: points)],
    );

RouteNormativeContext _context(RoomSurfaceRef surface) => RouteNormativeContext(
      surface: surface,
      widthMm: 2000,
      heightMm: 1600,
      edgeClearanceMm: 100,
    );
