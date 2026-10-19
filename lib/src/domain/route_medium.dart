enum RouteMediumFamily {
  power,
  data,
  control,
  safety,
  optical,
  coaxial,
  other,
}

enum RouteFlowVisualKind {
  /// Alternating-current energy transfer. Visuals should oscillate/pulse rather
  /// than imply electrons travelling continuously in one direction.
  acOscillation,

  /// Directional DC/energy/control flow from source to target.
  directionalPulse,

  /// Duplex packet traffic such as Ethernet/LAN.
  bidirectionalPackets,

  /// Optical transport represented by a moving light pulse.
  opticalPulse,

  /// A low-rate logical/control pulse (RS-485, alarm loops, dry-contact buses).
  controlPulse,

  /// Unknown/custom medium. Highlight the route without asserting flow physics.
  neutralPulse,
}

/// Engineering meaning of a routed conductor/media path.
///
/// [id] is deliberately open-ended so manufacturer/project-specific media can
/// participate without adding another enum. [cableType] on a route remains the
/// exact cable/conductor specification (for example `VVGng-LS 3x2.5` or
/// `Cat6A F/UTP`).
final class RouteMediumProfile {
  const RouteMediumProfile({
    required this.id,
    required this.family,
    required this.flowVisual,
    this.bidirectional = false,
    this.protocol,
  });

  final String id;
  final RouteMediumFamily family;
  final RouteFlowVisualKind flowVisual;
  final bool bidirectional;
  final String? protocol;

  static const acPower = RouteMediumProfile(
    id: 'power.ac',
    family: RouteMediumFamily.power,
    flowVisual: RouteFlowVisualKind.acOscillation,
  );

  static const dcPower = RouteMediumProfile(
    id: 'power.dc',
    family: RouteMediumFamily.power,
    flowVisual: RouteFlowVisualKind.directionalPulse,
  );

  static const ethernet = RouteMediumProfile(
    id: 'data.ethernet',
    family: RouteMediumFamily.data,
    flowVisual: RouteFlowVisualKind.bidirectionalPackets,
    bidirectional: true,
    protocol: 'Ethernet',
  );

  static const poe = RouteMediumProfile(
    id: 'data.poe',
    family: RouteMediumFamily.data,
    flowVisual: RouteFlowVisualKind.bidirectionalPackets,
    bidirectional: true,
    protocol: 'Ethernet/PoE',
  );

  static const fiber = RouteMediumProfile(
    id: 'optical.fiber',
    family: RouteMediumFamily.optical,
    flowVisual: RouteFlowVisualKind.opticalPulse,
    bidirectional: true,
  );

  static const rs485 = RouteMediumProfile(
    id: 'control.rs485',
    family: RouteMediumFamily.control,
    flowVisual: RouteFlowVisualKind.controlPulse,
    bidirectional: true,
    protocol: 'RS-485',
  );

  static const fireAlarm = RouteMediumProfile(
    id: 'safety.fire-alarm',
    family: RouteMediumFamily.safety,
    flowVisual: RouteFlowVisualKind.controlPulse,
    bidirectional: true,
    protocol: 'Fire alarm loop',
  );

  static const coax = RouteMediumProfile(
    id: 'data.coax',
    family: RouteMediumFamily.coaxial,
    flowVisual: RouteFlowVisualKind.directionalPulse,
  );

  static const generic = RouteMediumProfile(
    id: 'other.generic',
    family: RouteMediumFamily.other,
    flowVisual: RouteFlowVisualKind.neutralPulse,
  );
}
