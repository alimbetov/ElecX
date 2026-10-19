enum CableEnd { a, b }

enum CableLabelPurpose { field, cabinet, installation, commissioning }

final class CircuitRef {
  const CircuitRef({
    required this.id,
    required this.name,
    this.boardId,
    this.protectiveDeviceId,
  });

  final String id;
  final String name;
  final String? boardId;
  final String? protectiveDeviceId;
}

final class CableTerminationRef {
  const CableTerminationRef({
    required this.componentId,
    required this.portId,
    this.terminalId,
  });

  final String componentId;
  final String portId;
  final String? terminalId;
}

/// Stable identity carried from design through installation and commissioning.
/// This object deliberately does not contain printer-specific layout settings.
final class CableIdentity {
  const CableIdentity({
    required this.id,
    required this.routeId,
    required this.circuitId,
    required this.designation,
    required this.endA,
    required this.endB,
    this.cableSpecId,
  });

  final String id;
  final String routeId;
  final String circuitId;
  final String designation;
  final String? cableSpecId;
  final CableTerminationRef endA;
  final CableTerminationRef endB;
}

final class CableLabelData {
  const CableLabelData({
    required this.cableId,
    required this.end,
    required this.primaryText,
    required this.secondaryText,
    this.tertiaryText,
    this.qrPayload,
  });

  final String cableId;
  final CableEnd end;
  final String primaryText;
  final String secondaryText;
  final String? tertiaryText;
  final String? qrPayload;
}

abstract final class CableLabelComposer {
  static CableLabelData compose({
    required CableIdentity cable,
    required CircuitRef circuit,
    required CableEnd end,
    String? cableSpecDisplayName,
  }) {
    final termination = end == CableEnd.a ? cable.endA : cable.endB;
    final opposite = end == CableEnd.a ? cable.endB : cable.endA;
    final board = circuit.boardId == null ? '' : '${circuit.boardId} / ';
    final breaker = circuit.protectiveDeviceId == null
        ? ''
        : ' / ${circuit.protectiveDeviceId}';
    return CableLabelData(
      cableId: cable.id,
      end: end,
      primaryText: cable.designation,
      secondaryText: '$board${circuit.name}$breaker',
      tertiaryText: cableSpecDisplayName == null
          ? '${termination.componentId}:${termination.portId} → '
              '${opposite.componentId}:${opposite.portId}'
          : '$cableSpecDisplayName · '
              '${termination.componentId}:${termination.portId}',
      qrPayload: 'elecx://cable/${cable.id}?end=${end.name}',
    );
  }
}
