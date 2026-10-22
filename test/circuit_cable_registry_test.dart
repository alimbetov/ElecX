import 'package:elecx/src/domain/cable_identity.dart';
import 'package:elecx/src/domain/circuit_cable_registry.dart';
import 'package:elecx/src/domain/electrical_routing.dart';
import 'package:elecx/src/domain/route_medium.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ElectricalCableRoute route() => ElectricalCableRoute(
    id: 'route-0017',
    source: const ElectricalEndpointRef(
      componentId: 'DB-01',
      portId: 'outgoing',
    ),
    target: const ElectricalEndpointRef(
      componentId: 'LIGHT-03',
      portId: 'power-in',
    ),
    medium: RouteMediumProfile.acPower,
    cableType: 'VVGng-LS 3x1.5',
    segments: [
      ElectricalRouteSegment(
        surface: RoomSurfaceRef.wall('room-101', 0),
        points: const [SurfacePointMm(0, 300), SurfacePointMm(2000, 300)],
      ),
    ],
  );

  test(
    'registers board protection circuit cable and terminations as one bundle',
    () {
      final registry = CircuitCableRegistry();
      final electricalRoute = route();
      const circuit = CircuitRef(
        id: 'circuit-light-01',
        name: 'LIGHT-01',
        boardId: 'DB-01',
        protectiveDeviceId: 'qf-07',
      );
      const protection = ProtectiveDeviceRef(
        id: 'qf-07',
        boardId: 'DB-01',
        designation: 'QF-07',
        poleCount: 1,
        ratedCurrentA: 10,
      );
      const cable = CableIdentity(
        id: 'cable-0017',
        routeId: 'route-0017',
        circuitId: 'circuit-light-01',
        designation: 'W-017',
        cableSpecId: 'VVGng-LS 3x1.5',
        endA: CableTerminationRef(
          componentId: 'DB-01',
          portId: 'outgoing',
          terminalId: 'QF-07:L',
        ),
        endB: CableTerminationRef(
          componentId: 'LIGHT-03',
          portId: 'power-in',
          terminalId: 'L',
        ),
      );

      registry.registerBundle(
        route: electricalRoute,
        circuit: circuit,
        cable: cable,
        protectiveDevice: protection,
      );

      final bundle = registry.bundleByRouteId('route-0017');
      expect(bundle, isNotNull);
      expect(bundle!.circuit.boardId, 'DB-01');
      expect(bundle.protectiveDevice?.designation, 'QF-07');
      expect(bundle.cable.designation, 'W-017');
      expect(bundle.cable.endA.terminalId, 'QF-07:L');
      expect(bundle.cable.endB.terminalId, 'L');
    },
  );

  test(
    'rejects cable termination which does not match physical route endpoint',
    () {
      final registry = CircuitCableRegistry();
      final electricalRoute = route();
      const circuit = CircuitRef(id: 'circuit-light-01', name: 'LIGHT-01');
      const cable = CableIdentity(
        id: 'cable-0017',
        routeId: 'route-0017',
        circuitId: 'circuit-light-01',
        designation: 'W-017',
        endA: CableTerminationRef(componentId: 'DB-01', portId: 'wrong-port'),
        endB: CableTerminationRef(componentId: 'LIGHT-03', portId: 'power-in'),
      );

      expect(
        () => registry.registerBundle(
          route: electricalRoute,
          circuit: circuit,
          cable: cable,
        ),
        throwsArgumentError,
      );
    },
  );

  test('rejects protective device from another board', () {
    final registry = CircuitCableRegistry();
    final electricalRoute = route();
    const circuit = CircuitRef(
      id: 'circuit-light-01',
      name: 'LIGHT-01',
      boardId: 'DB-01',
      protectiveDeviceId: 'qf-07',
    );
    const cable = CableIdentity(
      id: 'cable-0017',
      routeId: 'route-0017',
      circuitId: 'circuit-light-01',
      designation: 'W-017',
      endA: CableTerminationRef(componentId: 'DB-01', portId: 'outgoing'),
      endB: CableTerminationRef(componentId: 'LIGHT-03', portId: 'power-in'),
    );
    const wrongBoardProtection = ProtectiveDeviceRef(
      id: 'qf-07',
      boardId: 'DB-02',
      designation: 'QF-07',
    );

    expect(
      () => registry.registerBundle(
        route: electricalRoute,
        circuit: circuit,
        cable: cable,
        protectiveDevice: wrongBoardProtection,
      ),
      throwsArgumentError,
    );
  });
}
