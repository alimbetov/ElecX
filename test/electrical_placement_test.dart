import 'package:flutter_test/flutter_test.dart';

import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/electrical_routing.dart';
import 'package:elecx/src/domain/surfaces.dart';

void main() {
  test('component stays bound to concrete room surface and millimetre point',
      () {
    final socket = ElectricalComponentPlacement(
      id: 'socket-1',
      type: ElectricalComponentType.socketOutlet,
      surface: RoomSurfaceRef.wall('room-101', 0),
      position: const SurfacePointMm(1200, 300),
      label: 'Розетка 1',
      ports: ElectricalComponentDefaults.portsFor(
        ElectricalComponentType.socketOutlet,
      ),
    );

    expect(socket.surface, RoomSurfaceRef.wall('room-101', 0));
    expect(socket.position.xMm, 1200);
    expect(socket.position.yMm, 300);
    expect(socket.ports.any((port) => port.id == 'power-in'), isTrue);
  });

  test('connected cable route uses real source and target component ports', () {
    final board = ElectricalComponentPlacement(
      id: 'db-1',
      type: ElectricalComponentType.distributionBoard,
      surface: RoomSurfaceRef.wall('room-101', 0),
      position: const SurfacePointMm(300, 1200),
      label: 'Щит 1',
      ports: ElectricalComponentDefaults.portsFor(
        ElectricalComponentType.distributionBoard,
      ),
    );
    final light = ElectricalComponentPlacement(
      id: 'light-1',
      type: ElectricalComponentType.lightingPoint,
      surface: RoomSurfaceRef.ceiling('room-101'),
      position: const SurfacePointMm(2100, 1600),
      label: 'Свет 1',
      ports: ElectricalComponentDefaults.portsFor(
        ElectricalComponentType.lightingPoint,
      ),
    );

    final route = ElectricalCableRoute(
      id: 'route-1',
      source: const ElectricalEndpointRef(
        componentId: 'db-1',
        portId: 'power-out',
      ),
      target: const ElectricalEndpointRef(
        componentId: 'light-1',
        portId: 'power-in',
      ),
      segments: [
        ElectricalRouteSegment(
          surface: board.surface,
          points: const [
            SurfacePointMm(300, 1200),
            SurfacePointMm(300, 3000),
          ],
        ),
        ElectricalRouteSegment(
          surface: light.surface,
          points: const [
            SurfacePointMm(300, 300),
            SurfacePointMm(2100, 1600),
          ],
        ),
      ],
    );

    expect(
      ElectricalConnectivityValidator.routeIsConnected(
        route: route,
        components: [board, light],
      ),
      isTrue,
    );
    expect(route.geometricLengthMm, greaterThan(0));
    expect(route.installationLengthMm, greaterThan(route.geometricLengthMm));
  });

  test('route with unknown target port is rejected', () {
    final source = ElectricalComponentPlacement(
      id: 'source-1',
      type: ElectricalComponentType.powerSource,
      surface: RoomSurfaceRef.wall('room-101', 0),
      position: const SurfacePointMm(0, 1000),
      label: 'Источник',
      ports: ElectricalComponentDefaults.portsFor(
        ElectricalComponentType.powerSource,
      ),
    );

    final route = ElectricalCableRoute(
      id: 'route-invalid',
      source: const ElectricalEndpointRef(
        componentId: 'source-1',
        portId: 'power-out',
      ),
      target: const ElectricalEndpointRef(
        componentId: 'missing',
        portId: 'power-in',
      ),
      segments: [
        ElectricalRouteSegment(
          surface: source.surface,
          points: const [
            SurfacePointMm(0, 1000),
            SurfacePointMm(1000, 1000),
          ],
        ),
      ],
    );

    expect(
      ElectricalConnectivityValidator.routeIsConnected(
        route: route,
        components: [source],
      ),
      isFalse,
    );
  });
}
