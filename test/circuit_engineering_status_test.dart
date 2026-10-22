import 'package:elecx/src/domain/cable_identity.dart';
import 'package:elecx/src/domain/circuit_cable_registry.dart';
import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/electrical_routing.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/features/editor/circuit_engineering_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final surface = RoomSurfaceRef.wall('room-1', 0);
  final load = ElectricalComponentPlacement(
    id: 'load-1',
    type: ElectricalComponentType.socketOutlet,
    surface: surface,
    position: const SurfacePointMm(2000, 1000),
    label: 'Розетка',
    ratedPowerW: 2300,
    voltageV: 230,
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
      componentId: 'load-1',
      portId: 'power-in',
    ),
    segments: [
      ElectricalRouteSegment(
        surface: surface,
        points: const [SurfacePointMm(0, 1000), SurfacePointMm(2000, 1000)],
      ),
    ],
    cableType: 'VVGng-LS-3x2.5',
  );
  final circuit = CircuitRef(
    id: 'circuit-1',
    name: 'Розетки',
    boardId: 'board-1',
    protectiveDeviceId: 'qf-1',
  );
  final cable = CableIdentity(
    id: 'cable-1',
    routeId: route.id,
    circuitId: circuit.id,
    designation: 'CAB-1',
    cableSpecId: 'VVGng-LS-3x2.5',
    endA: const CableTerminationRef(
      componentId: 'board-1',
      portId: 'power-out',
    ),
    endB: const CableTerminationRef(componentId: 'load-1', portId: 'power-in'),
  );

  test('status exposes route length and preliminary P/U current', () {
    final status = CircuitEngineeringStatus.evaluate(
      load: load,
      route: route,
      bundle: CircuitCableBundle(
        circuit: circuit,
        cable: cable,
        protectiveDevice: const ProtectiveDeviceRef(
          id: 'qf-1',
          boardId: 'board-1',
          designation: 'QF-1',
          ratedCurrentA: 16,
          poleCount: 1,
        ),
      ),
    );

    expect(status.geometricLengthM, 2);
    expect(status.installationLengthM, 2.1);
    expect(status.estimatedCurrentA, closeTo(10, 0.0001));
    expect(
      status.readiness,
      CircuitEngineeringReadiness.sizingEvidenceRequired,
    );
    expect(status.detail, contains('ampacity'));
  });

  test('status never fabricates current when load power is missing', () {
    final noPower = ElectricalComponentPlacement(
      id: load.id,
      type: load.type,
      surface: load.surface,
      position: load.position,
      label: load.label,
      voltageV: load.voltageV,
      ports: load.ports,
    );
    final status = CircuitEngineeringStatus.evaluate(
      load: noPower,
      route: route,
      bundle: CircuitCableBundle(circuit: circuit, cable: cable),
    );
    expect(status.estimatedCurrentA, isNull);
    expect(status.readiness, CircuitEngineeringReadiness.missingLoadPower);
  });
}
