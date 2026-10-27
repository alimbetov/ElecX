import 'electrical_load_calculation.dart';

enum ElectricalCircuitLoadKind {
  lighting,
  generalSocket,
  cookingAppliance,
  dishwasher,
  washingMachine,
  waterHeater,
  hvac,
  fixedAppliance,
  other,
}

/// One authoritative load participating in circuit synthesis.
///
/// [kind], [locationId] and [requiredPhaseSystem] are explicit engineering
/// inputs. The synthesis engine never infers them from room names or load power.
final class CircuitSynthesisLoad {
  const CircuitSynthesisLoad({
    required this.load,
    required this.kind,
    required this.locationId,
    required this.requiredPhaseSystem,
  }) : assert(locationId != '');

  final ElectricalLoadInput load;
  final ElectricalCircuitLoadKind kind;
  final String locationId;
  final ElectricalLoadPhaseSystem requiredPhaseSystem;
}

/// One source-pinned rule that makes matching loads dedicated circuits.
///
/// A rule matches when either the load id is explicitly listed, or its kind is
/// listed and the optional minimum connected-power threshold is satisfied.
final class DedicatedCircuitRule {
  DedicatedCircuitRule({
    required this.id,
    Iterable<ElectricalCircuitLoadKind> loadKinds = const [],
    Iterable<String> loadIds = const [],
    this.minimumConnectedPowerW,
    required this.sourceId,
    required this.sourceRevision,
  })  : loadKinds = Set.unmodifiable(loadKinds),
        loadIds = Set.unmodifiable(loadIds) {
    if (id.trim().isEmpty ||
        sourceId.trim().isEmpty ||
        sourceRevision.trim().isEmpty) {
      throw ArgumentError('Dedicated-circuit rule identity must be non-empty.');
    }
    if (this.loadKinds.isEmpty && this.loadIds.isEmpty) {
      throw ArgumentError(
        'Dedicated-circuit rule must match at least one load kind or id.',
      );
    }
    if (this.loadIds.any((value) => value.trim().isEmpty)) {
      throw ArgumentError('Dedicated-circuit load ids must be non-empty.');
    }
    if (minimumConnectedPowerW != null && minimumConnectedPowerW! < 0) {
      throw ArgumentError.value(
        minimumConnectedPowerW,
        'minimumConnectedPowerW',
      );
    }
  }

  final String id;
  final Set<ElectricalCircuitLoadKind> loadKinds;
  final Set<String> loadIds;
  final int? minimumConnectedPowerW;
  final String sourceId;
  final String sourceRevision;

  bool matches(CircuitSynthesisLoad candidate) {
    if (loadIds.contains(candidate.load.id)) return true;
    if (!loadKinds.contains(candidate.kind)) return false;
    final threshold = minimumConnectedPowerW;
    return threshold == null || candidate.load.connectedPowerW >= threshold;
  }
}

/// Explicit dedicated-circuit policy. An empty rule list means that no load is
/// made dedicated by this policy; the engine contains no hidden appliance rules.
final class DedicatedCircuitPolicy {
  DedicatedCircuitPolicy({
    required this.id,
    required Iterable<DedicatedCircuitRule> rules,
    required this.sourceId,
    required this.sourceRevision,
  }) : rules = List.unmodifiable(
          rules.toList()..sort((left, right) => left.id.compareTo(right.id)),
        ) {
    if (id.trim().isEmpty ||
        sourceId.trim().isEmpty ||
        sourceRevision.trim().isEmpty) {
      throw ArgumentError(
        'Dedicated-circuit policy identity/source must be non-empty.',
      );
    }
    final ids = <String>{};
    for (final rule in this.rules) {
      if (!ids.add(rule.id)) {
        throw ArgumentError('Duplicate dedicated-circuit rule ${rule.id}.');
      }
    }
  }

  final String id;
  final List<DedicatedCircuitRule> rules;
  final String sourceId;
  final String sourceRevision;
}

/// Source-pinned policy controlling only grouping mechanics.
///
/// Values here are project/normative inputs, not engine defaults. They bound
/// non-dedicated groups and define compatibility partitions.
final class CircuitGroupingPolicy {
  CircuitGroupingPolicy({
    required this.id,
    required this.maxGroupedLoadsPerCircuit,
    required this.maxGroupedConnectedPowerW,
    required this.separateByLocation,
    required this.separateByLoadKind,
    required this.sourceId,
    required this.sourceRevision,
  }) {
    if (id.trim().isEmpty ||
        sourceId.trim().isEmpty ||
        sourceRevision.trim().isEmpty) {
      throw ArgumentError(
        'Circuit-grouping policy identity/source must be non-empty.',
      );
    }
    if (maxGroupedLoadsPerCircuit <= 0) {
      throw ArgumentError.value(
        maxGroupedLoadsPerCircuit,
        'maxGroupedLoadsPerCircuit',
      );
    }
    if (maxGroupedConnectedPowerW <= 0) {
      throw ArgumentError.value(
        maxGroupedConnectedPowerW,
        'maxGroupedConnectedPowerW',
      );
    }
  }

  final String id;
  final int maxGroupedLoadsPerCircuit;
  final int maxGroupedConnectedPowerW;
  final bool separateByLocation;
  final bool separateByLoadKind;
  final String sourceId;
  final String sourceRevision;
}

final class ElectricalCircuitSynthesisRequest {
  ElectricalCircuitSynthesisRequest({
    required Iterable<CircuitSynthesisLoad> loads,
    required this.groupingPolicy,
    required this.dedicatedCircuitPolicy,
  }) : loads = List.unmodifiable(loads) {
    if (this.loads.isEmpty) {
      throw ArgumentError(
          'At least one load is required for circuit synthesis.');
    }
    final ids = <String>{};
    for (final item in this.loads) {
      if (!ids.add(item.load.id)) {
        throw ArgumentError(
            'Duplicate circuit-synthesis load ${item.load.id}.');
      }
    }
  }

  final List<CircuitSynthesisLoad> loads;
  final CircuitGroupingPolicy groupingPolicy;
  final DedicatedCircuitPolicy dedicatedCircuitPolicy;
}

final class SynthesizedElectricalCircuit {
  SynthesizedElectricalCircuit({
    required this.id,
    required this.requiredPhaseSystem,
    required this.dedicated,
    required Iterable<CircuitSynthesisLoad> loads,
    required this.groupingPolicyId,
    required this.groupingPolicyRevision,
    required this.dedicatedPolicyId,
    required this.dedicatedPolicyRevision,
    this.dedicatedRuleId,
  }) : loads = List.unmodifiable(
          loads.toList()
            ..sort((left, right) => left.load.id.compareTo(right.load.id)),
        ) {
    if (id.trim().isEmpty || this.loads.isEmpty) {
      throw ArgumentError(
          'Synthesized circuit identity/loads must be non-empty.');
    }
    if (dedicated && this.loads.length != 1) {
      throw ArgumentError('Dedicated circuit must contain exactly one load.');
    }
    if (dedicated != (dedicatedRuleId != null)) {
      throw ArgumentError(
        'Dedicated circuit and dedicated-rule evidence must agree.',
      );
    }
  }

  final String id;
  final ElectricalLoadPhaseSystem requiredPhaseSystem;
  final bool dedicated;
  final List<CircuitSynthesisLoad> loads;
  final String groupingPolicyId;
  final String groupingPolicyRevision;
  final String dedicatedPolicyId;
  final String dedicatedPolicyRevision;
  final String? dedicatedRuleId;

  int get connectedPowerW => loads.fold<int>(
        0,
        (sum, item) => sum + item.load.connectedPowerW,
      );

  List<String> get loadIds =>
      List.unmodifiable(loads.map((item) => item.load.id));
}

final class ElectricalCircuitSynthesisResult {
  ElectricalCircuitSynthesisResult({
    required Iterable<SynthesizedElectricalCircuit> circuits,
  }) : circuits = List.unmodifiable(circuits);

  final List<SynthesizedElectricalCircuit> circuits;
}
