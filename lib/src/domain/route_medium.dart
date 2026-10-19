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
  acOscillation,
  directionalPulse,
  bidirectionalPackets,
  opticalPulse,
  controlPulse,
  neutralPulse,
}

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

  String get displayName => switch (id) {
        'power.ac' => 'AC',
        'power.dc' => 'DC',
        'data.ethernet' => 'Ethernet',
        'data.poe' => 'PoE',
        'optical.fiber' => 'Fiber',
        'control.rs485' => 'RS-485',
        'safety.fire-alarm' => 'Fire Alarm',
        'data.coax' => 'Coax',
        _ => protocol ?? id,
      };

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
