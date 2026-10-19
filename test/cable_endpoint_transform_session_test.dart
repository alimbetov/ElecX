import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/electrical_routing.dart';
import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/engine/normative_route_engine.dart';
import 'package:elecx/src/engine/port_snap_resolver.dart';
import 'package:elecx/src/features/editor/cable_endpoint_transform_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('target endpoint snaps to compatible port and autoroutes before commit', () {
    final surface = RoomSurfaceRef.wall('room-101', 0);
    final board = ElectricalComponentPlacement(
      id: 'board-1',
      type: ElectricalComponentType.distributionBoard,
      surface: surface,
      position: const SurfacePointMm(200, 200),
      label: 'Board',
      ports: ElectricalComponentDefaults.portsFor(
        ElectricalComponentType.distributionBoard,
      ),
    );
    final oldSocket = ElectricalComponentPlacement(
      id: 'socket-old',
      type: ElectricalComponentType.socketOutlet,
      surface: surface,
      position: const SurfacePointMm(1400, 900),
      label: 'Old socket',
      ports: ElectricalComponentDefaults.portsFor(
        ElectricalComponentType.socketOutlet,
      ),
    );
    final newSocket = ElectricalComponentPlacement(
      id: 'socket-new',
      type: ElectricalComponentType.socketOutlet,
      surface: surface,
      position: const SurfacePointMm(1800, 1400),
      label: 'New socket',
      ports: ElectricalComponentDefaults.portsFor(
        ElectricalComponentType.socketOutlet,
      ),
    );
    final route = ElectricalCableRoute(
      id: 'route-1',
      source: const ElectricalEndpointRef(
        componentId: 'board-1',
        portId: 'power-out',
      ),
      target: const ElectricalEndpointRef(
        componentId: 'socket-old',
        portId: 'power-in',
      ),
      segments: [
        ElectricalRouteSegment(
          surface: surface,
          points: const [
            SurfacePointMm(200, 200),
            SurfacePointMm(200, 900),
            SurfacePointMm(1400, 900),
          ],
        ),
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
        context: RouteNormativeContext(
          surface: surface,
          widthMm: 2000,
          heightMm: 1600,
          edgeClearanceMm: 100,
        ),
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
  });

  test('endpoint cannot commit while no compatible port is captured', () {
    final surface = RoomSurfaceRef.wall('room-101', 0);
    final route = ElectricalCableRoute(
      id: 'route-1',
      source: const ElectricalEndpointRef(
        componentId: 'board-1',
        portId: 'power-out',
      ),
      target: const ElectricalEndpointRef(
        componentId: 'socket-1',
        portId: 'power-in',
      ),
      segments: [
        ElectricalRouteSegment(
          surface: surface,
          points: const [
            SurfacePointMm(200, 200),
            SurfacePointMm(1800, 1400),
          ],
        ),
      ],
    );
    final session = CableEndpointTransformSession(onCommit: (_, __) => true);
    addTearDown(session.dispose);

    expect(
      session.start(
        route: route,
        role: CableEndpointRole.target,
        components: const [],
        context: RouteNormativeContext(
          surface: surface,
          widthMm: 2000,
          heightMm: 1600,
          edgeClearanceMm: 100,
        ),
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
}
