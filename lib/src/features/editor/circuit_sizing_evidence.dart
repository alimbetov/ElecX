import '../../domain/cable_spec.dart';
import '../../domain/electrical_routing.dart';
import '../../domain/route_medium.dart';
import '../../engine/cable_sizing_engine.dart';

final class CircuitSizingEvidence {
  CircuitSizingEvidence({
    required this.routeId,
    required this.routeGeometrySignature,
    required this.cable,
    required this.phaseSystem,
    required this.designCurrentA,
    required this.nominalVoltageV,
    required this.maxVoltageDropRatio,
    required this.powerFactor,
    required Iterable<SectionAmpacityEvidence> ampacitySections,
    this.impedanceEvidence,
    this.designCurrentSourceKey,
  }) : ampacitySections = List.unmodifiable(ampacitySections) {
    if (routeId.trim().isEmpty) {
      throw ArgumentError('routeId must be non-empty.');
    }
    if (designCurrentA <= 0 || nominalVoltageV <= 0) {
      throw ArgumentError('Design current and voltage must be positive.');
    }
    if (maxVoltageDropRatio <= 0 || maxVoltageDropRatio >= 1) {
      throw ArgumentError('Voltage-drop limit must be between 0 and 1.');
    }
    if (powerFactor <= 0 || powerFactor > 1) {
      throw ArgumentError('Power factor must be in (0, 1].');
    }
  }

  final String routeId;
  final String routeGeometrySignature;
  final CableSpec cable;
  final CircuitPhaseSystem phaseSystem;
  final double designCurrentA;
  final double nominalVoltageV;
  final double maxVoltageDropRatio;
  final double powerFactor;
  final CableImpedanceEvidence? impedanceEvidence;
  final List<SectionAmpacityEvidence> ampacitySections;
  final String? designCurrentSourceKey;

  bool matchesRoute(ElectricalCableRoute route) =>
      route.id == routeId && routeGeometrySignature == geometrySignature(route);

  CableSizingResult evaluate(ElectricalCableRoute route) {
    if (!matchesRoute(route)) {
      throw StateError('Cable sizing evidence is stale for route ${route.id}.');
    }
    return CableSizingEngine.evaluate(
      CableSizingRequest(
        cable: cable,
        requirement: CircuitElectricalRequirement(
          phaseSystem: phaseSystem,
          designCurrentA: designCurrentA,
          nominalVoltageV: nominalVoltageV,
          routeLengthMm: route.geometricLengthMm,
          maxVoltageDropRatio: maxVoltageDropRatio,
          powerFactor: powerFactor,
        ),
        impedanceEvidence: impedanceEvidence,
        ampacitySections: ampacitySections,
      ),
    );
  }

  Map<String, Object?> toJson() => {
    'routeId': routeId,
    'routeGeometrySignature': routeGeometrySignature,
    'cable': _cableToJson(cable),
    'phaseSystem': phaseSystem.name,
    'designCurrentA': designCurrentA,
    'nominalVoltageV': nominalVoltageV,
    'maxVoltageDropRatio': maxVoltageDropRatio,
    'powerFactor': powerFactor,
    'designCurrentSourceKey': designCurrentSourceKey,
    'impedanceEvidence': impedanceEvidence == null
        ? null
        : {
            'resistanceOhmPerKm': impedanceEvidence!.resistanceOhmPerKm,
            'reactanceOhmPerKm': impedanceEvidence!.reactanceOhmPerKm,
            'sourceKey': impedanceEvidence!.sourceKey,
          },
    'ampacitySections': [
      for (final section in ampacitySections)
        {
          'sectionId': section.sectionId,
          'baseAmpacityA': section.baseAmpacityA,
          'sourceKey': section.sourceKey,
          'factors': [
            for (final factor in section.factors)
              {
                'id': factor.id,
                'factor': factor.factor,
                'reason': factor.reason,
              },
          ],
        },
    ],
  };

  factory CircuitSizingEvidence.fromJson(Map<String, Object?> json) {
    final cableJson = _map(json['cable'], 'cable');
    final impedanceRaw = json['impedanceEvidence'];
    final impedance = impedanceRaw == null
        ? null
        : () {
            final value = _map(impedanceRaw, 'impedanceEvidence');
            return CableImpedanceEvidence(
              resistanceOhmPerKm: _double(
                value['resistanceOhmPerKm'],
                'resistanceOhmPerKm',
              ),
              reactanceOhmPerKm: _double(
                value['reactanceOhmPerKm'],
                'reactanceOhmPerKm',
              ),
              sourceKey: _nullableString(value['sourceKey']),
            );
          }();
    return CircuitSizingEvidence(
      routeId: _string(json['routeId'], 'routeId'),
      routeGeometrySignature: _string(
        json['routeGeometrySignature'],
        'routeGeometrySignature',
      ),
      cable: _cableFromJson(cableJson),
      phaseSystem: CircuitPhaseSystem.values.byName(
        _string(json['phaseSystem'], 'phaseSystem'),
      ),
      designCurrentA: _double(json['designCurrentA'], 'designCurrentA'),
      nominalVoltageV: _double(json['nominalVoltageV'], 'nominalVoltageV'),
      maxVoltageDropRatio: _double(
        json['maxVoltageDropRatio'],
        'maxVoltageDropRatio',
      ),
      powerFactor: _double(json['powerFactor'], 'powerFactor'),
      designCurrentSourceKey: _nullableString(json['designCurrentSourceKey']),
      impedanceEvidence: impedance,
      ampacitySections: [
        for (final raw in _list(json['ampacitySections'], 'ampacitySections'))
          () {
            final section = _map(raw, 'ampacitySection');
            return SectionAmpacityEvidence(
              sectionId: _string(section['sectionId'], 'sectionId'),
              baseAmpacityA: _double(section['baseAmpacityA'], 'baseAmpacityA'),
              sourceKey: _nullableString(section['sourceKey']),
              factors: [
                for (final factorRaw in _list(section['factors'], 'factors'))
                  () {
                    final factor = _map(factorRaw, 'factor');
                    return ThermalCorrectionFactor(
                      id: _string(factor['id'], 'factor.id'),
                      factor: _double(factor['factor'], 'factor.factor'),
                      reason: _nullableString(factor['reason']),
                    );
                  }(),
              ],
            );
          }(),
      ],
    );
  }

  static String geometrySignature(ElectricalCableRoute route) => route.segments
      .map(
        (segment) => [
          segment.surface.spaceId,
          segment.surface.type.name,
          segment.surface.wallIndex?.toString() ?? '-',
          for (final point in segment.points) '${point.xMm},${point.yMm}',
        ].join(':'),
      )
      .join('|');

  static Map<String, Object?> _cableToJson(CableSpec value) => {
    'id': value.id,
    'name': value.name,
    'medium': {
      'id': value.medium.id,
      'family': value.medium.family.name,
      'flowVisual': value.medium.flowVisual.name,
      'bidirectional': value.medium.bidirectional,
      'protocol': value.medium.protocol,
    },
    'outerDiameterMm': value.outerDiameterMm,
    'segregationClass': value.segregationClass.name,
    'conductorMaterial': value.conductorMaterial.name,
    'conductorCount': value.conductorCount,
    'conductorCrossSectionMm2': value.conductorCrossSectionMm2,
    'pairCount': value.pairCount,
    'fiberCount': value.fiberCount,
    'shielding': value.shielding.name,
    'ratedVoltageV': value.ratedVoltageV,
    'category': value.category,
  };

  static CableSpec _cableFromJson(Map<String, Object?> json) {
    final medium = _map(json['medium'], 'cable.medium');
    return CableSpec(
      id: _string(json['id'], 'cable.id'),
      name: _string(json['name'], 'cable.name'),
      medium: RouteMediumProfile(
        id: _string(medium['id'], 'medium.id'),
        family: RouteMediumFamily.values.byName(
          _string(medium['family'], 'medium.family'),
        ),
        flowVisual: RouteFlowVisualKind.values.byName(
          _string(medium['flowVisual'], 'medium.flowVisual'),
        ),
        bidirectional: _bool(medium['bidirectional'], 'medium.bidirectional'),
        protocol: _nullableString(medium['protocol']),
      ),
      outerDiameterMm: _double(json['outerDiameterMm'], 'outerDiameterMm'),
      segregationClass: CableSegregationClass.values.byName(
        _string(json['segregationClass'], 'segregationClass'),
      ),
      conductorMaterial: ConductorMaterial.values.byName(
        _string(json['conductorMaterial'], 'conductorMaterial'),
      ),
      conductorCount: _nullableInt(json['conductorCount']),
      conductorCrossSectionMm2: json['conductorCrossSectionMm2'] == null
          ? null
          : _double(
              json['conductorCrossSectionMm2'],
              'conductorCrossSectionMm2',
            ),
      pairCount: _nullableInt(json['pairCount']),
      fiberCount: _nullableInt(json['fiberCount']),
      shielding: CableShielding.values.byName(
        _string(json['shielding'], 'shielding'),
      ),
      ratedVoltageV: _nullableInt(json['ratedVoltageV']),
      category: _nullableString(json['category']),
    );
  }

  static Map<String, Object?> _map(Object? value, String field) {
    if (value is! Map) throw FormatException('$field must be an object.');
    return value.map((key, item) => MapEntry(key.toString(), item));
  }

  static List<Object?> _list(Object? value, String field) {
    if (value is! List) throw FormatException('$field must be a list.');
    return value.cast<Object?>();
  }

  static String _string(Object? value, String field) {
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$field must be a non-empty string.');
    }
    return value;
  }

  static String? _nullableString(Object? value) =>
      value is String ? value : null;

  static double _double(Object? value, String field) {
    if (value is num) return value.toDouble();
    throw FormatException('$field must be a number.');
  }

  static bool _bool(Object? value, String field) {
    if (value is bool) return value;
    throw FormatException('$field must be a bool.');
  }

  static int? _nullableInt(Object? value) => value is int ? value : null;
}
