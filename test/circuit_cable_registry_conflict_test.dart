import 'package:elecx/src/domain/cable_identity.dart';
import 'package:elecx/src/domain/circuit_cable_registry.dart';
import 'package:elecx/src/domain/electrical_routing.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ElectricalCableRoute route() => ElectricalCableRoute(
        id: 'route-1',
        source: const ElectricalEndpointRef(
          componentId: 'DB-01',
          portId: 'outgoing',
        ),
        target: const ElectricalEndpointRef(
          componentId: 'LOAD-01',
          portId: 'power-in',
        ),
        segments: [
          ElectricalRouteSegment(
            surface: RoomSurfaceRef.wall('room-1', 0),
            points: const [SurfacePointMm(0, 300), SurfacePointMm(1000, 300)],
          ),
        ],
      );

  const cable = CableIdentity(
    id: 'cable-1',
    routeId: 'route-1',
    circuitId: 'circuit-1',
    designation: 'W-001',
    endA: CableTerminationRef(componentId: 'DB-01', portId: 'outgoing'),
    endB: CableTerminationRef(componentId: 'LOAD-01', portId: 'power-in'),
  );

  test('same bundle can be registered idempotently', () {
    final registry = CircuitCableRegistry();
    const circuit = CircuitRef(id: 'circuit-1', name: 'LIGHT-01');

    registry.registerBundle(route: route(), circuit: circuit, cable: cable);
    registry.registerBundle(route: route(), circuit: circuit, cable: cable);

    expect(registry.circuits, hasLength(1));
    expect(registry.cables, hasLength(1));
  });

  test('same circuit id cannot silently change engineering identity', () {
    final registry = CircuitCableRegistry();
    const first = CircuitRef(id: 'circuit-1', name: 'LIGHT-01');
    const conflicting = CircuitRef(id: 'circuit-1', name: 'SOCKET-01');

    registry.registerBundle(route: route(), circuit: first, cable: cable);

    expect(
      () => registry.registerBundle(
        route: route(),
        circuit: conflicting,
        cable: cable,
      ),
      throwsStateError,
    );
  });
}
