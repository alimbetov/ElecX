import 'electrical_circuit_synthesis.dart';
import 'electrical_load_calculation.dart';

/// Explicit calculation policy for one synthesized circuit.
///
/// Voltage, diversity and reserve are supplied by upstream project/normative
/// policy. The calculation layer contains no residential voltage or Ks defaults.
final class ElectricalCircuitCalculationPolicy {
  ElectricalCircuitCalculationPolicy({
    required this.circuitId,
    required this.nominalVoltageV,
    required this.diversityPolicy,
    required this.reservePolicy,
    required this.sourceId,
    required this.sourceRevision,
  }) {
    if (circuitId.trim().isEmpty ||
        sourceId.trim().isEmpty ||
        sourceRevision.trim().isEmpty) {
      throw ArgumentError(
        'Circuit calculation policy identity/source must be non-empty.',
      );
    }
    if (!nominalVoltageV.isFinite || nominalVoltageV <= 0) {
      throw ArgumentError.value(nominalVoltageV, 'nominalVoltageV');
    }
  }

  final String circuitId;
  final double nominalVoltageV;
  final ElectricalDiversityPolicy diversityPolicy;
  final ElectricalReservePolicy reservePolicy;
  final String sourceId;
  final String sourceRevision;
}

final class ElectricalCircuitCalculationRequest {
  ElectricalCircuitCalculationRequest({
    required this.synthesis,
    required Iterable<ElectricalCircuitCalculationPolicy> policies,
  }) : policies = List.unmodifiable(policies) {
    if (synthesis.circuits.isEmpty) {
      throw ArgumentError('Circuit calculation requires synthesized circuits.');
    }
    final expectedIds = synthesis.circuits.map((circuit) => circuit.id).toSet();
    final actualIds = <String>{};
    for (final policy in this.policies) {
      if (!actualIds.add(policy.circuitId)) {
        throw ArgumentError(
          'Duplicate electrical circuit calculation policy '
          '${policy.circuitId}.',
        );
      }
      if (!expectedIds.contains(policy.circuitId)) {
        throw ArgumentError(
          'Calculation policy references unknown circuit ${policy.circuitId}.',
        );
      }
    }
    final missing = expectedIds.difference(actualIds);
    if (missing.isNotEmpty) {
      throw ArgumentError(
        'Missing calculation policy for circuit(s): '
        '${(missing.toList()..sort()).join(', ')}.',
      );
    }
  }

  final ElectricalCircuitSynthesisResult synthesis;
  final List<ElectricalCircuitCalculationPolicy> policies;
}

final class CalculatedElectricalCircuit {
  CalculatedElectricalCircuit({
    required this.circuit,
    required this.calculation,
    required this.policySourceId,
    required this.policySourceRevision,
  }) {
    if (policySourceId.trim().isEmpty || policySourceRevision.trim().isEmpty) {
      throw ArgumentError('Circuit calculation provenance must be non-empty.');
    }
    if (calculation.phaseSystem != circuit.requiredPhaseSystem) {
      throw ArgumentError(
        'Circuit ${circuit.id} phase system does not match its calculation.',
      );
    }
    final circuitLoadIds = circuit.loadIds.toList()..sort();
    final contributionIds = calculation.contributions
        .map((contribution) => contribution.loadId)
        .toList()
      ..sort();
    if (!_sameStringList(circuitLoadIds, contributionIds)) {
      throw ArgumentError(
        'Circuit ${circuit.id} load assignments do not match calculation '
        'contributions.',
      );
    }
  }

  final SynthesizedElectricalCircuit circuit;
  final ElectricalLoadCalculationResult calculation;
  final String policySourceId;
  final String policySourceRevision;

  String get id => circuit.id;
  ElectricalLoadPhaseSystem get phaseSystem => circuit.requiredPhaseSystem;
}

final class ElectricalCircuitCalculationResult {
  ElectricalCircuitCalculationResult({
    required Iterable<CalculatedElectricalCircuit> circuits,
  }) : circuits = List.unmodifiable(circuits) {
    if (this.circuits.isEmpty) {
      throw ArgumentError('Circuit calculation result must not be empty.');
    }
    final ids = <String>{};
    for (final circuit in this.circuits) {
      if (!ids.add(circuit.id)) {
        throw ArgumentError('Duplicate calculated circuit ${circuit.id}.');
      }
    }
  }

  final List<CalculatedElectricalCircuit> circuits;
}

bool _sameStringList(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
