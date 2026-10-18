import 'surfaces.dart';

enum EngineeringDiscipline {
  power,
  lighting,
  lowVoltage,
  data,
  cctv,
  accessControl,
  fireAlarm,
  automation,
}

enum EngineeringPortDirection { input, output, bidirectional }

enum EngineeringConnectionType {
  acSinglePhase,
  acThreePhase,
  dcPower,
  dryContact,
  ethernetCopper,
  poe,
  fiber,
  rs485,
  fireLoop,
  analogSignal,
  custom,
}

final class EngineeringPortSpec {
  EngineeringPortSpec({
    required this.id,
    required this.direction,
    required this.allowedConnections,
  }) {
    if (id.isEmpty) throw ArgumentError('Port id must be non-empty.');
    if (allowedConnections.isEmpty) {
      throw ArgumentError('A port must allow at least one connection type.');
    }
  }

  final String id;
  final EngineeringPortDirection direction;
  final Set<EngineeringConnectionType> allowedConnections;

  bool accepts(EngineeringConnectionType type) =>
      allowedConnections.contains(type);
}

/// One placed engineering object. Position is always surface-local mm.
final class EngineeringNode {
  EngineeringNode({
    required this.id,
    required this.componentTypeId,
    required this.discipline,
    required this.surface,
    required this.position,
    required this.ports,
    this.ratedPowerW,
    this.voltageV,
    this.quantity = 1,
  }) {
    if (id.isEmpty || componentTypeId.isEmpty) {
      throw ArgumentError('Node and component type ids must be non-empty.');
    }
    if (quantity <= 0) throw ArgumentError.value(quantity, 'quantity');
    if (ratedPowerW != null && ratedPowerW! < 0) {
      throw ArgumentError.value(ratedPowerW, 'ratedPowerW');
    }
    if (voltageV != null && voltageV! <= 0) {
      throw ArgumentError.value(voltageV, 'voltageV');
    }
  }

  final String id;
  final String componentTypeId;
  final EngineeringDiscipline discipline;
  final RoomSurfaceRef surface;
  final SurfacePointMm position;
  final List<EngineeringPortSpec> ports;
  final int? ratedPowerW;
  final int? voltageV;
  final int quantity;

  int get connectedLoadW => (ratedPowerW ?? 0) * quantity;

  EngineeringPortSpec? port(String portId) {
    for (final port in ports) {
      if (port.id == portId) return port;
    }
    return null;
  }
}

final class EngineeringEdge {
  EngineeringEdge({
    required this.id,
    required this.fromNodeId,
    required this.fromPortId,
    required this.toNodeId,
    required this.toPortId,
    required this.connectionType,
    this.routeId,
    this.circuitId,
  }) {
    if (id.isEmpty || fromNodeId.isEmpty || toNodeId.isEmpty) {
      throw ArgumentError('Edge and node ids must be non-empty.');
    }
  }

  final String id;
  final String fromNodeId;
  final String fromPortId;
  final String toNodeId;
  final String toPortId;
  final EngineeringConnectionType connectionType;
  final String? routeId;
  final String? circuitId;
}

abstract final class EngineeringGraphValidator {
  static bool canConnect({
    required EngineeringNode from,
    required String fromPortId,
    required EngineeringNode to,
    required String toPortId,
    required EngineeringConnectionType type,
  }) {
    final fromPort = from.port(fromPortId);
    final toPort = to.port(toPortId);
    if (fromPort == null || toPort == null) return false;
    if (!fromPort.accepts(type) || !toPort.accepts(type)) return false;
    if (fromPort.direction == EngineeringPortDirection.input) return false;
    if (toPort.direction == EngineeringPortDirection.output) return false;
    return true;
  }
}

final class CircuitLoadInput {
  CircuitLoadInput({
    required this.circuitId,
    required this.connectedLoadW,
    required this.demandFactor,
    required this.simultaneityFactor,
    required this.voltageV,
    this.powerFactor = 1.0,
  }) {
    if (circuitId.isEmpty) throw ArgumentError('circuitId must be non-empty.');
    if (connectedLoadW < 0 || voltageV <= 0) {
      throw ArgumentError('Invalid circuit load or voltage.');
    }
    if (demandFactor <= 0 || demandFactor > 1 ||
        simultaneityFactor <= 0 || simultaneityFactor > 1 ||
        powerFactor <= 0 || powerFactor > 1) {
      throw ArgumentError('Load factors must be in (0, 1].');
    }
  }

  final String circuitId;
  final int connectedLoadW;
  final double demandFactor;
  final double simultaneityFactor;
  final int voltageV;
  final double powerFactor;

  double get designLoadW =>
      connectedLoadW * demandFactor * simultaneityFactor;

  double get designCurrentA => designLoadW / (voltageV * powerFactor);
}

/// Input to a normative cable sizing policy. The policy itself is profile-
/// specific (KZ/IEC/etc.) and must not be hard-coded in persistence.
final class CableSizingInput {
  CableSizingInput({
    required this.circuitId,
    required this.designCurrentA,
    required this.routeLengthMm,
    required this.ambientTemperatureC,
    required this.groupedLoadedCircuitCount,
    required this.installationMethodId,
    required this.conductorMaterialId,
    required this.insulationClassId,
    required this.maxVoltageDropPercent,
  }) {
    if (designCurrentA < 0 || routeLengthMm < 0) {
      throw ArgumentError('Current and route length must be non-negative.');
    }
    if (groupedLoadedCircuitCount <= 0) {
      throw ArgumentError.value(
        groupedLoadedCircuitCount,
        'groupedLoadedCircuitCount',
      );
    }
    if (maxVoltageDropPercent <= 0) {
      throw ArgumentError.value(
        maxVoltageDropPercent,
        'maxVoltageDropPercent',
      );
    }
  }

  final String circuitId;
  final double designCurrentA;
  final int routeLengthMm;
  final double ambientTemperatureC;
  final int groupedLoadedCircuitCount;
  final String installationMethodId;
  final String conductorMaterialId;
  final String insulationClassId;
  final double maxVoltageDropPercent;
}

final class CableSizingResult {
  const CableSizingResult({
    required this.circuitId,
    required this.cableTypeId,
    required this.sectionMm2,
    required this.correctedAmpacityA,
    required this.voltageDropPercent,
    required this.normativeProfileId,
  });

  final String circuitId;
  final String cableTypeId;
  final double sectionMm2;
  final double correctedAmpacityA;
  final double voltageDropPercent;
  final String normativeProfileId;
}
