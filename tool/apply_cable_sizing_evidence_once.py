from pathlib import Path


def replace_once(path: str, old: str, new: str):
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{path}: expected one anchor, found {count}: {old[:120]!r}')
    p.write_text(text.replace(old, new, 1))


Path('lib/src/features/editor/circuit_sizing_evidence.dart').write_text(r'''import '../../domain/cable_spec.dart';
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
    if (routeId.trim().isEmpty) throw ArgumentError('routeId must be non-empty.');
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
              resistanceOhmPerKm:
                  _double(value['resistanceOhmPerKm'], 'resistanceOhmPerKm'),
              reactanceOhmPerKm:
                  _double(value['reactanceOhmPerKm'], 'reactanceOhmPerKm'),
              sourceKey: _nullableString(value['sourceKey']),
            );
          }();
    return CircuitSizingEvidence(
      routeId: _string(json['routeId'], 'routeId'),
      routeGeometrySignature:
          _string(json['routeGeometrySignature'], 'routeGeometrySignature'),
      cable: _cableFromJson(cableJson),
      phaseSystem: CircuitPhaseSystem.values.byName(
        _string(json['phaseSystem'], 'phaseSystem'),
      ),
      designCurrentA: _double(json['designCurrentA'], 'designCurrentA'),
      nominalVoltageV: _double(json['nominalVoltageV'], 'nominalVoltageV'),
      maxVoltageDropRatio:
          _double(json['maxVoltageDropRatio'], 'maxVoltageDropRatio'),
      powerFactor: _double(json['powerFactor'], 'powerFactor'),
      designCurrentSourceKey: _nullableString(json['designCurrentSourceKey']),
      impedanceEvidence: impedance,
      ampacitySections: [
        for (final raw in _list(json['ampacitySections'], 'ampacitySections'))
          () {
            final section = _map(raw, 'ampacitySection');
            return SectionAmpacityEvidence(
              sectionId: _string(section['sectionId'], 'sectionId'),
              baseAmpacityA:
                  _double(section['baseAmpacityA'], 'baseAmpacityA'),
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

  static String? _nullableString(Object? value) => value is String ? value : null;

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
''')

# Editor state + API.
path = 'lib/src/features/editor/editor_p2_session.dart'
replace_once(path,
"import '../../domain/geometry.dart';\n",
"import '../../domain/geometry.dart';\nimport '../../domain/route_medium.dart';\n")
replace_once(path,
"import 'cable_route_constraints.dart';\n",
"import 'cable_route_constraints.dart';\nimport 'circuit_sizing_evidence.dart';\n")
replace_once(path,
"    this.circuitBundles = const [],\n  });\n",
"    this.circuitBundles = const [],\n    this.sizingEvidenceByRoute = const {},\n  });\n")
replace_once(path,
"  final List<CircuitCableBundle> circuitBundles;\n",
"  final List<CircuitCableBundle> circuitBundles;\n  final Map<String, CircuitSizingEvidence> sizingEvidenceByRoute;\n")
replace_once(path,
"    List<CircuitCableBundle>? circuitBundles,\n  }) =>\n",
"    List<CircuitCableBundle>? circuitBundles,\n    Map<String, CircuitSizingEvidence>? sizingEvidenceByRoute,\n  }) =>\n")
replace_once(path,
"        circuitBundles: circuitBundles ?? this.circuitBundles,\n      );\n",
"        circuitBundles: circuitBundles ?? this.circuitBundles,\n        sizingEvidenceByRoute:\n            sizingEvidenceByRoute ?? this.sizingEvidenceByRoute,\n      );\n")
replace_once(path,
"  CircuitCableBundle? circuitBundleForLoad(String componentId) {\n    for (final bundle in state.circuitBundles) {\n      if (bundle.cable.endB.componentId == componentId) return bundle;\n    }\n    return null;\n  }\n",
"  CircuitCableBundle? circuitBundleForLoad(String componentId) {\n    for (final bundle in state.circuitBundles) {\n      if (bundle.cable.endB.componentId == componentId) return bundle;\n    }\n    return null;\n  }\n\n  CircuitSizingEvidence? sizingEvidenceForLoad(String componentId) {\n    final bundle = circuitBundleForLoad(componentId);\n    if (bundle == null) return null;\n    return state.sizingEvidenceByRoute[bundle.cable.routeId];\n  }\n\n  bool setCircuitSizingEvidenceForLoad({\n    required String loadComponentId,\n    required CircuitSizingEvidence evidence,\n  }) {\n    final bundle = circuitBundleForLoad(loadComponentId);\n    if (bundle == null || bundle.cable.routeId != evidence.routeId) return false;\n    final route = _routeForId(evidence.routeId);\n    if (route == null || !evidence.matchesRoute(route)) return false;\n    if (bundle.cable.cableSpecId != evidence.cable.id) return false;\n    final afterEvidence = Map<String, CircuitSizingEvidence>.of(\n      state.sizingEvidenceByRoute,\n    )..[route.id] = evidence;\n    history.execute(\n      _ReplaceEditorStateCommand(\n        before: state,\n        after: state.copyWith(\n          sizingEvidenceByRoute: Map.unmodifiable(afterEvidence),\n        ),\n        label: 'Update cable sizing evidence',\n      ),\n    );\n    notifyListeners();\n    return true;\n  }\n")
# Clear sizing evidence if cable spec is changed.
replace_once(path,
"    final after = state.copyWith(\n      routes: [\n        for (final item in routes)\n          if (item.id == route.id) replacementRoute else item,\n      ],\n      circuitBundles: [\n        for (final item in state.circuitBundles)\n          if (item.cable.routeId == route.id) replacementBundle else item,\n      ],\n    );\n",
"    final nextEvidence = Map<String, CircuitSizingEvidence>.of(\n      state.sizingEvidenceByRoute,\n    )..remove(route.id);\n    final after = state.copyWith(\n      routes: [\n        for (final item in routes)\n          if (item.id == route.id) replacementRoute else item,\n      ],\n      circuitBundles: [\n        for (final item in state.circuitBundles)\n          if (item.cable.routeId == route.id) replacementBundle else item,\n      ],\n      sizingEvidenceByRoute: Map.unmodifiable(nextEvidence),\n    );\n")
# Delete removes evidence.
replace_once(path,
"    final nextConstraints = Map<String, CableRouteConstraints>.of(\n      state.routeConstraints,\n    )..removeWhere((routeId, _) => removedRouteIds.contains(routeId));\n",
"    final nextConstraints = Map<String, CableRouteConstraints>.of(\n      state.routeConstraints,\n    )..removeWhere((routeId, _) => removedRouteIds.contains(routeId));\n    final nextSizingEvidence = Map<String, CircuitSizingEvidence>.of(\n      state.sizingEvidenceByRoute,\n    )..removeWhere((routeId, _) => removedRouteIds.contains(routeId));\n")
replace_once(path,
"      circuitBundles: [\n        for (final bundle in state.circuitBundles)\n          if (!removedRouteIds.contains(bundle.cable.routeId)) bundle,\n      ],\n    );\n",
"      circuitBundles: [\n        for (final bundle in state.circuitBundles)\n          if (!removedRouteIds.contains(bundle.cable.routeId)) bundle,\n      ],\n      sizingEvidenceByRoute: Map.unmodifiable(nextSizingEvidence),\n    );\n")
# Power circuit routes carry power medium.
replace_once(path,
"      segments: segments,\n      cableType: cableType,\n    );\n",
"      segments: segments,\n      cableType: cableType,\n      medium: RouteMediumProfile.acPower,\n    );\n")

# Schema v4.
path = 'lib/src/features/editor/project_schema_migrator.dart'
replace_once(path, '  static const int currentSchemaVersion = 3;\n', '  static const int currentSchemaVersion = 4;\n')
replace_once(path,
"        2 => _v2ToV3(result),\n",
"        2 => _v2ToV3(result),\n        3 => _v3ToV4(result),\n")
replace_once(path,
"  static Map<String, Object?> _v2ToV3(Map<String, Object?> source) {\n",
"  static Map<String, Object?> _v3ToV4(Map<String, Object?> source) {\n    final p2Raw = source['p2'];\n    if (p2Raw is! Map) {\n      throw const FormatException('p2 must be an object for schema v3.');\n    }\n    final p2 = p2Raw.map((key, value) => MapEntry(key.toString(), value));\n    return <String, Object?>{\n      ...source,\n      'schemaVersion': 4,\n      'p2': <String, Object?>{\n        ...p2,\n        'sizingEvidenceByRoute': const <String, Object?>{},\n      },\n    };\n  }\n\n  static Map<String, Object?> _v2ToV3(Map<String, Object?> source) {\n")

# Persistence map delegates JSON to evidence model.
path = 'lib/src/features/editor/editor_project_document.dart'
replace_once(path,
"import 'cable_route_constraints.dart';\n",
"import 'cable_route_constraints.dart';\nimport 'circuit_sizing_evidence.dart';\n")
replace_once(path,
"      'circuitBundles': [\n        for (final bundle in value.circuitBundles) _circuitBundleToJson(bundle),\n      ],\n    };\n",
"      'circuitBundles': [\n        for (final bundle in value.circuitBundles) _circuitBundleToJson(bundle),\n      ],\n      'sizingEvidenceByRoute': {\n        for (final entry in value.sizingEvidenceByRoute.entries)\n          entry.key: entry.value.toJson(),\n      },\n    };\n")
replace_once(path,
"  final constraints = _map(json['routeConstraints'], 'p2.routeConstraints');\n",
"  final constraints = _map(json['routeConstraints'], 'p2.routeConstraints');\n  final sizingEvidence =\n      _map(json['sizingEvidenceByRoute'], 'p2.sizingEvidenceByRoute');\n")
replace_once(path,
"    circuitBundles: [\n      for (final item in _list(json['circuitBundles'], 'p2.circuitBundles'))\n        _circuitBundleFromJson(_map(item, 'circuitBundle')),\n    ],\n  );\n",
"    circuitBundles: [\n      for (final item in _list(json['circuitBundles'], 'p2.circuitBundles'))\n        _circuitBundleFromJson(_map(item, 'circuitBundle')),\n    ],\n    sizingEvidenceByRoute: Map.unmodifiable({\n      for (final entry in sizingEvidence.entries)\n        entry.key: CircuitSizingEvidence.fromJson(\n          _map(entry.value, 'sizingEvidence.${entry.key}'),\n        ),\n    }),\n  );\n")

# Engineering status consumes real engine result when current evidence exists.
path = 'lib/src/features/editor/circuit_engineering_status.dart'
replace_once(path,
"import '../../domain/electrical_routing.dart';\n",
"import '../../domain/electrical_routing.dart';\nimport '../../engine/cable_sizing_engine.dart';\nimport 'circuit_sizing_evidence.dart';\n")
replace_once(path,
"  sizingEvidenceRequired,\n}\n",
"  sizingEvidenceRequired,\n  sizingEvidenceStale,\n  sizingIndeterminate,\n  sizingFailed,\n  sizingPassed,\n}\n")
replace_once(path,
"    required this.estimatedCurrentA,\n  });\n",
"    required this.estimatedCurrentA,\n    this.sizingResult,\n  });\n")
replace_once(path,
"  final double? estimatedCurrentA;\n",
"  final double? estimatedCurrentA;\n  final CableSizingResult? sizingResult;\n")
replace_once(path,
"        CircuitEngineeringReadiness.sizingEvidenceRequired =>\n          'Нужны данные для расчёта кабеля',\n",
"        CircuitEngineeringReadiness.sizingEvidenceRequired =>\n          'Нужны данные для расчёта кабеля',\n        CircuitEngineeringReadiness.sizingEvidenceStale =>\n          'Расчёт кабеля устарел',\n        CircuitEngineeringReadiness.sizingIndeterminate =>\n          'Расчёт кабеля: недостаточно evidence',\n        CircuitEngineeringReadiness.sizingFailed =>\n          'Расчёт кабеля: FAIL',\n        CircuitEngineeringReadiness.sizingPassed =>\n          'Расчёт кабеля: PASS',\n")
replace_once(path,
"        CircuitEngineeringReadiness.sizingEvidenceRequired =>\n          'Для PASS требуются ampacity по участкам и impedance evidence. ElecX не подменяет их предположениями.',\n",
"        CircuitEngineeringReadiness.sizingEvidenceRequired =>\n          'Для PASS требуются ampacity по участкам и impedance evidence. ElecX не подменяет их предположениями.',\n        CircuitEngineeringReadiness.sizingEvidenceStale =>\n          'Геометрия трассы или кабель изменились после расчёта. Обновите evidence.',\n        CircuitEngineeringReadiness.sizingIndeterminate ||\n        CircuitEngineeringReadiness.sizingFailed ||\n        CircuitEngineeringReadiness.sizingPassed =>\n          sizingResult?.reasons.join(' ') ?? 'Нет результата расчёта.',\n")
replace_once(path,
"    required CircuitCableBundle bundle,\n  }) {\n",
"    required CircuitCableBundle bundle,\n    CircuitSizingEvidence? sizingEvidence,\n  }) {\n")
old_logic = """    final readiness = power == null || power <= 0
        ? CircuitEngineeringReadiness.missingLoadPower
        : bundle.protectiveDevice == null
            ? CircuitEngineeringReadiness.missingProtection
            : cableSpec == null || cableSpec.trim().isEmpty
                ? CircuitEngineeringReadiness.missingCableSpecification
                : CircuitEngineeringReadiness.sizingEvidenceRequired;
    return CircuitEngineeringStatus(
      readiness: readiness,
      geometricLengthM: route.geometricLengthMm / 1000,
      installationLengthM: route.installationLengthMm / 1000,
      loadPowerW: power,
      nominalVoltageV: load.voltageV,
      estimatedCurrentA: current,
    );
"""
new_logic = """    CableSizingResult? sizingResult;
    late final CircuitEngineeringReadiness readiness;
    if (power == null || power <= 0) {
      readiness = CircuitEngineeringReadiness.missingLoadPower;
    } else if (bundle.protectiveDevice == null) {
      readiness = CircuitEngineeringReadiness.missingProtection;
    } else if (cableSpec == null || cableSpec.trim().isEmpty) {
      readiness = CircuitEngineeringReadiness.missingCableSpecification;
    } else if (sizingEvidence == null) {
      readiness = CircuitEngineeringReadiness.sizingEvidenceRequired;
    } else if (!sizingEvidence.matchesRoute(route) ||
        sizingEvidence.cable.id != cableSpec) {
      readiness = CircuitEngineeringReadiness.sizingEvidenceStale;
    } else {
      sizingResult = sizingEvidence.evaluate(route);
      final hasFailure =
          sizingResult.currentStatus == EngineeringCheckStatus.fail ||
              sizingResult.voltageDropStatus == EngineeringCheckStatus.fail;
      readiness = hasFailure
          ? CircuitEngineeringReadiness.sizingFailed
          : sizingResult.isIndeterminate
              ? CircuitEngineeringReadiness.sizingIndeterminate
              : CircuitEngineeringReadiness.sizingPassed;
    }
    return CircuitEngineeringStatus(
      readiness: readiness,
      geometricLengthM: route.geometricLengthMm / 1000,
      installationLengthM: route.installationLengthMm / 1000,
      loadPowerW: power,
      nominalVoltageV: load.voltageV,
      estimatedCurrentA: current,
      sizingResult: sizingResult,
    );
"""
replace_once(path, old_logic, new_logic)

# UI sizing evidence dialog for the current single-route workflow.
path = 'lib/src/features/editor/room_circuit_panel.dart'
replace_once(path,
"import '../../domain/circuit_cable_registry.dart';\n",
"import '../../domain/cable_spec.dart';\nimport '../../domain/circuit_cable_registry.dart';\n")
replace_once(path,
"import '../../domain/project_model.dart';\n",
"import '../../domain/project_model.dart';\nimport '../../engine/cable_sizing_engine.dart';\n")
replace_once(path,
"import 'circuit_engineering_status.dart';\n",
"import 'circuit_engineering_status.dart';\nimport 'circuit_sizing_evidence.dart';\n")
replace_once(path,
"                  bundle: bundle,\n                );\n",
"                  bundle: bundle,\n                  sizingEvidence: p2.sizingEvidenceForLoad(selected.id),\n                );\n")
replace_once(path,
"                      OutlinedButton.icon(\n                        key: const ValueKey('assign-cable-specification'),\n",
"                      OutlinedButton.icon(\n                        key: const ValueKey('edit-cable-sizing-evidence'),\n                        onPressed: route == null || bundle.cable.cableSpecId == null\n                            ? null\n                            : () => _editSizingEvidence(\n                                  context,\n                                  load: selected,\n                                  route: route,\n                                  bundle: bundle,\n                                ),\n                        icon: const Icon(Icons.calculate_outlined),\n                        label: const Text('Расчёт'),\n                      ),\n                      OutlinedButton.icon(\n                        key: const ValueKey('assign-cable-specification'),\n")
anchor = """  Future<void> _editLoadData(
"""
helper = r'''  Future<void> _editSizingEvidence(
    BuildContext context, {
    required ElectricalComponentPlacement load,
    required ElectricalCableRoute route,
    required CircuitCableBundle bundle,
  }) async {
    final existing = controller.p2.sizingEvidenceForLoad(load.id);
    final preliminaryCurrent = load.ratedPowerW == null
        ? ''
        : (load.ratedPowerW! / load.voltageV).toStringAsFixed(2);
    var phaseSystem = existing?.phaseSystem ?? CircuitPhaseSystem.singlePhaseAc;
    var designCurrentText = existing?.designCurrentA.toString() ?? preliminaryCurrent;
    var powerFactorText = existing?.powerFactor.toString() ?? '1.0';
    var voltageDropText = existing == null
        ? '3.0'
        : (existing.maxVoltageDropRatio * 100).toString();
    var diameterText = existing?.cable.outerDiameterMm.toString() ?? '';
    var material = existing?.cable.conductorMaterial ?? ConductorMaterial.copper;
    var conductorCountText = existing?.cable.conductorCount?.toString() ?? '3';
    var crossSectionText =
        existing?.cable.conductorCrossSectionMm2?.toString() ?? '';
    var baseAmpacityText = existing?.ampacitySections.firstOrNull?.baseAmpacityA.toString() ?? '';
    var correctionText = existing?.ampacitySections.firstOrNull?.combinedFactor.toString() ?? '1.0';
    var ampacitySource = existing?.ampacitySections.firstOrNull?.sourceKey ?? '';
    var resistanceText = existing?.impedanceEvidence?.resistanceOhmPerKm.toString() ?? '';
    var reactanceText = existing?.impedanceEvidence?.reactanceOhmPerKm.toString() ?? '0';
    var impedanceSource = existing?.impedanceEvidence?.sourceKey ?? '';
    var designCurrentSource = existing?.designCurrentSourceKey ?? '';

    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          key: const ValueKey('cable-sizing-evidence-dialog'),
          title: const Text('Расчёт кабеля · evidence'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<CircuitPhaseSystem>(
                    initialValue: phaseSystem,
                    decoration: const InputDecoration(labelText: 'Система'),
                    items: const [
                      DropdownMenuItem(
                        value: CircuitPhaseSystem.singlePhaseAc,
                        child: Text('1-фаза AC'),
                      ),
                      DropdownMenuItem(
                        value: CircuitPhaseSystem.threePhaseAc,
                        child: Text('3-фазы AC'),
                      ),
                      DropdownMenuItem(
                        value: CircuitPhaseSystem.dc,
                        child: Text('DC'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) setLocalState(() => phaseSystem = value);
                    },
                  ),
                  TextFormField(
                    key: const ValueKey('sizing-design-current'),
                    initialValue: designCurrentText,
                    decoration: InputDecoration(
                      labelText: 'Расчётный ток',
                      suffixText: 'A',
                      helperText: preliminaryCurrent.isEmpty
                          ? 'Введите подтверждённый расчётный ток.'
                          : 'P/U≈$preliminaryCurrent A только как подсказка; подтвердите расчётный ток.',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (value) => designCurrentText = value,
                  ),
                  TextFormField(
                    initialValue: designCurrentSource,
                    decoration: const InputDecoration(labelText: 'Источник расчётного тока'),
                    onChanged: (value) => designCurrentSource = value,
                  ),
                  TextFormField(
                    initialValue: powerFactorText,
                    decoration: const InputDecoration(labelText: 'cosφ'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (value) => powerFactorText = value,
                  ),
                  TextFormField(
                    initialValue: voltageDropText,
                    decoration: const InputDecoration(
                      labelText: 'Допустимое падение напряжения',
                      suffixText: '%',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (value) => voltageDropText = value,
                  ),
                  const Divider(height: 24),
                  TextFormField(
                    initialValue: diameterText,
                    decoration: const InputDecoration(
                      labelText: 'Наружный диаметр кабеля',
                      suffixText: 'мм',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (value) => diameterText = value,
                  ),
                  DropdownButtonFormField<ConductorMaterial>(
                    initialValue: material,
                    decoration: const InputDecoration(labelText: 'Материал жил'),
                    items: const [
                      DropdownMenuItem(value: ConductorMaterial.copper, child: Text('Cu')),
                      DropdownMenuItem(value: ConductorMaterial.aluminum, child: Text('Al')),
                    ],
                    onChanged: (value) {
                      if (value != null) setLocalState(() => material = value);
                    },
                  ),
                  TextFormField(
                    initialValue: conductorCountText,
                    decoration: const InputDecoration(labelText: 'Количество жил'),
                    keyboardType: TextInputType.number,
                    onChanged: (value) => conductorCountText = value,
                  ),
                  TextFormField(
                    initialValue: crossSectionText,
                    decoration: const InputDecoration(
                      labelText: 'Сечение жилы',
                      suffixText: 'мм²',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (value) => crossSectionText = value,
                  ),
                  const Divider(height: 24),
                  TextFormField(
                    key: const ValueKey('sizing-base-ampacity'),
                    initialValue: baseAmpacityText,
                    decoration: const InputDecoration(
                      labelText: 'Base ampacity участка',
                      suffixText: 'A',
                      helperText: 'Оставьте пустым → current check = INDETERMINATE.',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (value) => baseAmpacityText = value,
                  ),
                  TextFormField(
                    initialValue: correctionText,
                    decoration: const InputDecoration(labelText: 'Суммарный correction factor'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (value) => correctionText = value,
                  ),
                  TextFormField(
                    initialValue: ampacitySource,
                    decoration: const InputDecoration(labelText: 'Источник ampacity'),
                    onChanged: (value) => ampacitySource = value,
                  ),
                  TextFormField(
                    key: const ValueKey('sizing-resistance'),
                    initialValue: resistanceText,
                    decoration: const InputDecoration(
                      labelText: 'R',
                      suffixText: 'Ω/км',
                      helperText: 'Оставьте пустым → voltage-drop check = INDETERMINATE.',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (value) => resistanceText = value,
                  ),
                  TextFormField(
                    initialValue: reactanceText,
                    decoration: const InputDecoration(labelText: 'X', suffixText: 'Ω/км'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (value) => reactanceText = value,
                  ),
                  TextFormField(
                    initialValue: impedanceSource,
                    decoration: const InputDecoration(labelText: 'Источник impedance'),
                    onChanged: (value) => impedanceSource = value,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              key: const ValueKey('cable-sizing-evidence-confirm'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Рассчитать'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true || !context.mounted) return;

    double? parseDouble(String value) =>
        double.tryParse(value.trim().replaceAll(',', '.'));
    final designCurrent = parseDouble(designCurrentText);
    final powerFactor = parseDouble(powerFactorText);
    final voltageDropPercent = parseDouble(voltageDropText);
    final diameter = parseDouble(diameterText);
    final conductorCount = int.tryParse(conductorCountText.trim());
    final crossSection = parseDouble(crossSectionText);
    final baseAmpacity = baseAmpacityText.trim().isEmpty
        ? null
        : parseDouble(baseAmpacityText);
    final correction = parseDouble(correctionText);
    final resistance = resistanceText.trim().isEmpty
        ? null
        : parseDouble(resistanceText);
    final reactance = parseDouble(reactanceText) ?? 0;
    final specId = bundle.cable.cableSpecId;
    if (designCurrent == null ||
        designCurrent <= 0 ||
        powerFactor == null ||
        powerFactor <= 0 ||
        powerFactor > 1 ||
        voltageDropPercent == null ||
        voltageDropPercent <= 0 ||
        voltageDropPercent >= 100 ||
        diameter == null ||
        diameter <= 0 ||
        conductorCount == null ||
        conductorCount <= 0 ||
        crossSection == null ||
        crossSection <= 0 ||
        correction == null ||
        correction <= 0 ||
        specId == null) {
      _showResult(context, 'Проверьте обязательные параметры расчёта и CableSpec.');
      return;
    }
    if ((baseAmpacity != null && baseAmpacity <= 0) ||
        (resistance != null && resistance < 0) ||
        reactance < 0) {
      _showResult(context, 'Ampacity/R/X не могут иметь отрицательные значения.');
      return;
    }

    final cable = CableSpec(
      id: specId,
      name: specId,
      medium: route.medium,
      outerDiameterMm: diameter,
      segregationClass: CableSegregationClass.power,
      conductorMaterial: material,
      conductorCount: conductorCount,
      conductorCrossSectionMm2: crossSection,
      ratedVoltageV: load.voltageV,
    );
    final evidence = CircuitSizingEvidence(
      routeId: route.id,
      routeGeometrySignature: CircuitSizingEvidence.geometrySignature(route),
      cable: cable,
      phaseSystem: phaseSystem,
      designCurrentA: designCurrent,
      nominalVoltageV: load.voltageV.toDouble(),
      maxVoltageDropRatio: voltageDropPercent / 100,
      powerFactor: powerFactor,
      designCurrentSourceKey:
          designCurrentSource.trim().isEmpty ? null : designCurrentSource.trim(),
      ampacitySections: baseAmpacity == null
          ? const []
          : [
              SectionAmpacityEvidence(
                sectionId: '${route.id}:whole-route',
                baseAmpacityA: baseAmpacity,
                sourceKey:
                    ampacitySource.trim().isEmpty ? null : ampacitySource.trim(),
                factors: [
                  ThermalCorrectionFactor(
                    id: 'combined-user-factor',
                    factor: correction,
                    reason: 'Engineer-supplied combined factor',
                  ),
                ],
              ),
            ],
      impedanceEvidence: resistance == null
          ? null
          : CableImpedanceEvidence(
              resistanceOhmPerKm: resistance,
              reactanceOhmPerKm: reactance,
              sourceKey:
                  impedanceSource.trim().isEmpty ? null : impedanceSource.trim(),
            ),
    );
    final ok = controller.p2.setCircuitSizingEvidenceForLoad(
      loadComponentId: load.id,
      evidence: evidence,
    );
    _showResult(
      context,
      ok ? 'Расчёт кабеля обновлён.' : 'Не удалось сохранить evidence расчёта.',
    );
  }

'''
replace_once(path, anchor, helper + anchor)

# Persistence tests must follow schema v4.
path = 'test/editor_project_persistence_test.dart'
replace_once(path,
"  test('schema v1 migrates through v3 without losing project identity', () {\n",
"  test('schema v1 migrates through v4 without losing project identity', () {\n")
replace_once(path, "    expect(decoded.schemaVersion, 3);\n", "    expect(decoded.schemaVersion, 4);\n")

# Evidence tests.
Path('test/circuit_sizing_evidence_test.dart').write_text(r'''import 'package:elecx/src/domain/cable_spec.dart';
import 'package:elecx/src/domain/electrical_routing.dart';
import 'package:elecx/src/domain/route_medium.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/engine/cable_sizing_engine.dart';
import 'package:elecx/src/features/editor/circuit_sizing_evidence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final surface = RoomSurfaceRef.wall('room-1', 0);
  ElectricalCableRoute route({int endX = 10000}) => ElectricalCableRoute(
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
            points: [const SurfacePointMm(0, 1000), SurfacePointMm(endX, 1000)],
          ),
        ],
        cableType: 'cable-3x2.5',
        medium: RouteMediumProfile.acPower,
      );

  CableSpec cable() => const CableSpec(
        id: 'cable-3x2.5',
        name: '3x2.5',
        medium: RouteMediumProfile.acPower,
        outerDiameterMm: 10,
        segregationClass: CableSegregationClass.power,
        conductorMaterial: ConductorMaterial.copper,
        conductorCount: 3,
        conductorCrossSectionMm2: 2.5,
        ratedVoltageV: 230,
      );

  test('complete evidence produces actual CableSizingEngine PASS', () {
    final actualRoute = route();
    final evidence = CircuitSizingEvidence(
      routeId: actualRoute.id,
      routeGeometrySignature: CircuitSizingEvidence.geometrySignature(actualRoute),
      cable: cable(),
      phaseSystem: CircuitPhaseSystem.singlePhaseAc,
      designCurrentA: 10,
      nominalVoltageV: 230,
      maxVoltageDropRatio: 0.03,
      powerFactor: 1,
      ampacitySections: [
        SectionAmpacityEvidence(
          sectionId: 'whole-route',
          baseAmpacityA: 20,
          factors: const [
            ThermalCorrectionFactor(id: 'k', factor: 1),
          ],
          sourceKey: 'engineer-table-A',
        ),
      ],
      impedanceEvidence: const CableImpedanceEvidence(
        resistanceOhmPerKm: 7.5,
        sourceKey: 'manufacturer-R',
      ),
    );
    final result = evidence.evaluate(actualRoute);
    expect(result.currentStatus, EngineeringCheckStatus.pass);
    expect(result.voltageDropStatus, EngineeringCheckStatus.pass);
    expect(result.isPass, isTrue);
  });

  test('missing impedance remains INDETERMINATE, never implicit PASS', () {
    final actualRoute = route();
    final evidence = CircuitSizingEvidence(
      routeId: actualRoute.id,
      routeGeometrySignature: CircuitSizingEvidence.geometrySignature(actualRoute),
      cable: cable(),
      phaseSystem: CircuitPhaseSystem.singlePhaseAc,
      designCurrentA: 10,
      nominalVoltageV: 230,
      maxVoltageDropRatio: 0.03,
      powerFactor: 1,
      ampacitySections: [
        SectionAmpacityEvidence(
          sectionId: 'whole-route',
          baseAmpacityA: 20,
          factors: const [],
        ),
      ],
    );
    final result = evidence.evaluate(actualRoute);
    expect(result.currentStatus, EngineeringCheckStatus.pass);
    expect(result.voltageDropStatus, EngineeringCheckStatus.indeterminate);
    expect(result.isPass, isFalse);
  });

  test('route geometry mutation makes saved sizing evidence stale', () {
    final original = route();
    final evidence = CircuitSizingEvidence(
      routeId: original.id,
      routeGeometrySignature: CircuitSizingEvidence.geometrySignature(original),
      cable: cable(),
      phaseSystem: CircuitPhaseSystem.singlePhaseAc,
      designCurrentA: 10,
      nominalVoltageV: 230,
      maxVoltageDropRatio: 0.03,
      powerFactor: 1,
      ampacitySections: const [],
    );
    expect(evidence.matchesRoute(original), isTrue);
    expect(evidence.matchesRoute(route(endX: 12000)), isFalse);
  });

  test('evidence JSON round-trip preserves sources and cable spec', () {
    final actualRoute = route();
    final source = CircuitSizingEvidence(
      routeId: actualRoute.id,
      routeGeometrySignature: CircuitSizingEvidence.geometrySignature(actualRoute),
      cable: cable(),
      phaseSystem: CircuitPhaseSystem.singlePhaseAc,
      designCurrentA: 12,
      nominalVoltageV: 230,
      maxVoltageDropRatio: 0.03,
      powerFactor: 0.95,
      designCurrentSourceKey: 'load-study-1',
      ampacitySections: [
        SectionAmpacityEvidence(
          sectionId: 'wall',
          baseAmpacityA: 24,
          factors: const [ThermalCorrectionFactor(id: 'temp', factor: 0.9)],
          sourceKey: 'table-1',
        ),
      ],
      impedanceEvidence: const CableImpedanceEvidence(
        resistanceOhmPerKm: 7.41,
        reactanceOhmPerKm: 0.08,
        sourceKey: 'datasheet-1',
      ),
    );
    final restored = CircuitSizingEvidence.fromJson(source.toJson());
    expect(restored.cable.conductorCrossSectionMm2, 2.5);
    expect(restored.designCurrentSourceKey, 'load-study-1');
    expect(restored.ampacitySections.single.sourceKey, 'table-1');
    expect(restored.impedanceEvidence!.sourceKey, 'datasheet-1');
  });
}
''')

# Workflow-level persistence/API regression appended to current room circuit suite.
path = 'test/room_circuit_workflow_test.dart'
p = Path(path)
text = p.read_text()
insert_import = "import 'package:elecx/src/domain/electrical_placement.dart';\n"
if insert_import not in text:
    raise SystemExit('room test import anchor missing')
text = text.replace(insert_import,
"import 'package:elecx/src/domain/cable_spec.dart';\n" +
"import 'package:elecx/src/domain/electrical_placement.dart';\n" +
"import 'package:elecx/src/domain/route_medium.dart';\n" +
"import 'package:elecx/src/engine/cable_sizing_engine.dart';\n" +
"import 'package:elecx/src/features/editor/circuit_sizing_evidence.dart';\n", 1)
append = r'''

test('sizing evidence is undoable and survives project reopen', () {
  final editor = EditorController.demo();
  final workspace = EditorBuildingWorkspace.demo(editor);
  addTearDown(() {
    editor.disposeP2State();
    workspace.dispose();
    editor.dispose();
  });
  final surface = RoomSurfaceRef.wall(editor.selectedSpace!.id, 1);
  final board = editor.p2.placeComponent(
    type: ElectricalComponentType.distributionBoard,
    surface: surface,
    position: const SurfacePointMm(300, 2200),
  );
  final load = editor.p2.placeComponent(
    type: ElectricalComponentType.socketOutlet,
    surface: surface,
    position: const SurfacePointMm(1400, 2200),
  );
  expect(
    editor.p2.connectLoadToBoard(
      loadComponentId: load.id,
      boardComponentId: board.id,
      space: editor.selectedSpace,
      cableType: 'cable-3x2.5',
    ),
    isNotNull,
  );
  final route = editor.p2.routes.single;
  final evidence = CircuitSizingEvidence(
    routeId: route.id,
    routeGeometrySignature: CircuitSizingEvidence.geometrySignature(route),
    cable: const CableSpec(
      id: 'cable-3x2.5',
      name: '3x2.5',
      medium: RouteMediumProfile.acPower,
      outerDiameterMm: 10,
      segregationClass: CableSegregationClass.power,
      conductorMaterial: ConductorMaterial.copper,
      conductorCount: 3,
      conductorCrossSectionMm2: 2.5,
      ratedVoltageV: 230,
    ),
    phaseSystem: CircuitPhaseSystem.singlePhaseAc,
    designCurrentA: 10,
    nominalVoltageV: 230,
    maxVoltageDropRatio: 0.03,
    powerFactor: 1,
    ampacitySections: const [],
  );
  final depth = editor.p2.history.undoDepth;
  expect(
    editor.p2.setCircuitSizingEvidenceForLoad(
      loadComponentId: load.id,
      evidence: evidence,
    ),
    isTrue,
  );
  expect(editor.p2.history.undoDepth, depth + 1);
  editor.p2.undo();
  expect(editor.p2.sizingEvidenceForLoad(load.id), isNull);
  editor.p2.redo();
  expect(editor.p2.sizingEvidenceForLoad(load.id), isNotNull);

  final restored = EditorProjectDocument.fromJson(
    EditorProjectDocument.capture(workspace).toJson(),
  ).restore();
  addTearDown(() {
    restored.editor.disposeP2State();
    restored.workspace.dispose();
    restored.editor.dispose();
  });
  expect(restored.editor.p2.sizingEvidenceForLoad(load.id), isNotNull);
});
'''
idx = text.rfind('\n}')
if idx == -1:
    raise SystemExit('room circuit test closing brace missing')
p.write_text(text[:idx] + append + text[idx:])
