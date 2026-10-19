import 'cable_identity.dart';
import 'electrical_routing.dart';

final class ProtectiveDeviceRef {
  const ProtectiveDeviceRef({
    required this.id,
    required this.boardId,
    required this.designation,
    this.poleCount,
    this.ratedCurrentA,
  });

  final String id;
  final String boardId;
  final String designation;
  final int? poleCount;
  final double? ratedCurrentA;
}

final class CircuitCableBundle {
  const CircuitCableBundle({
    required this.circuit,
    required this.cable,
    this.protectiveDevice,
  });

  final CircuitRef circuit;
  final CableIdentity cable;
  final ProtectiveDeviceRef? protectiveDevice;
}

/// Referentially consistent engineering registry used by drawings, inspectors,
/// labels, cable schedules and future single-line/cabinet projections.
///
/// The registry deliberately never invents a board or protective device. An
/// unassigned circuit remains explicit until engineering data is provided.
final class CircuitCableRegistry {
  final Map<String, CircuitRef> _circuits = {};
  final Map<String, CableIdentity> _cables = {};
  final Map<String, ProtectiveDeviceRef> _protectiveDevices = {};
  final Map<String, String> _cableIdByRouteId = {};

  List<CircuitRef> get circuits => List.unmodifiable(_circuits.values);
  List<CableIdentity> get cables => List.unmodifiable(_cables.values);
  List<ProtectiveDeviceRef> get protectiveDevices =>
      List.unmodifiable(_protectiveDevices.values);

  CircuitRef? circuitById(String id) => _circuits[id];
  CableIdentity? cableById(String id) => _cables[id];
  ProtectiveDeviceRef? protectiveDeviceById(String id) =>
      _protectiveDevices[id];

  CableIdentity? cableByRouteId(String routeId) {
    final cableId = _cableIdByRouteId[routeId];
    return cableId == null ? null : _cables[cableId];
  }

  CircuitCableBundle? bundleByRouteId(String routeId) {
    final cable = cableByRouteId(routeId);
    if (cable == null) return null;
    final circuit = _circuits[cable.circuitId];
    if (circuit == null) return null;
    final deviceId = circuit.protectiveDeviceId;
    return CircuitCableBundle(
      circuit: circuit,
      cable: cable,
      protectiveDevice: deviceId == null ? null : _protectiveDevices[deviceId],
    );
  }

  void registerBundle({
    required ElectricalCableRoute route,
    required CircuitRef circuit,
    required CableIdentity cable,
    ProtectiveDeviceRef? protectiveDevice,
  }) {
    _validateBundle(
      route: route,
      circuit: circuit,
      cable: cable,
      protectiveDevice: protectiveDevice,
    );
    final existingCableId = _cableIdByRouteId[route.id];
    if (existingCableId != null && existingCableId != cable.id) {
      throw StateError(
        'Route ${route.id} is already assigned to cable $existingCableId.',
      );
    }
    final existingCable = _cables[cable.id];
    if (existingCable != null && existingCable.routeId != route.id) {
      throw StateError(
        'Cable ${cable.id} is already assigned to route ${existingCable.routeId}.',
      );
    }

    _circuits[circuit.id] = circuit;
    _cables[cable.id] = cable;
    _cableIdByRouteId[route.id] = cable.id;
    if (protectiveDevice != null) {
      _protectiveDevices[protectiveDevice.id] = protectiveDevice;
    }
  }

  void _validateBundle({
    required ElectricalCableRoute route,
    required CircuitRef circuit,
    required CableIdentity cable,
    required ProtectiveDeviceRef? protectiveDevice,
  }) {
    if (cable.routeId != route.id) {
      throw ArgumentError(
        'Cable routeId ${cable.routeId} does not match route ${route.id}.',
      );
    }
    if (cable.circuitId != circuit.id) {
      throw ArgumentError(
        'Cable circuitId ${cable.circuitId} does not match circuit ${circuit.id}.',
      );
    }
    _validateTermination(cable.endA, route.source, 'A');
    _validateTermination(cable.endB, route.target, 'B');

    final deviceId = circuit.protectiveDeviceId;
    if (deviceId != null) {
      if (protectiveDevice == null || protectiveDevice.id != deviceId) {
        throw ArgumentError(
          'Circuit ${circuit.id} references protective device $deviceId but matching evidence was not supplied.',
        );
      }
      if (circuit.boardId == null ||
          protectiveDevice.boardId != circuit.boardId) {
        throw ArgumentError(
          'Protective device ${protectiveDevice.id} must belong to circuit board ${circuit.boardId}.',
        );
      }
    } else if (protectiveDevice != null) {
      throw ArgumentError(
        'Protective device ${protectiveDevice.id} was supplied but circuit ${circuit.id} does not reference it.',
      );
    }
  }

  void _validateTermination(
    CableTerminationRef termination,
    ElectricalEndpointRef endpoint,
    String end,
  ) {
    if (termination.componentId != endpoint.componentId ||
        termination.portId != endpoint.portId) {
      throw ArgumentError(
        'Cable end $end does not match route endpoint '
        '${endpoint.componentId}:${endpoint.portId}.',
      );
    }
  }
}
