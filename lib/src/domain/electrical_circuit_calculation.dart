import 'electrical_circuit_synthesis.dart';
import 'electrical_load_calculation.dart';

/// Explicit calculation policy for one synthesized circuit.
///
/// Voltage, diversity and reserve are supplied by upstream project/normative
/// policy. The calculation layer contains no residential voltage or Ks defaults.
final class ElectricalCircuitCalculationPolicy {
  const ElectricalCircuitCalculationPolicy({
    required this.circuitId,
    required this.nominalVoltageV,
    required this.diversityPolicy,
    required this.reservePolicy,
    required this.sourceId,
    required this.sourceRevision,
  })  : assert(circuitId != ''),
        assert(nominalVoltageV > 0),
        assert(sourceId != ''),
        assert(sourceRevision != '');

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
  const CalculatedElectricalCircuit({
    required this.circuit,
    required this.calculation,
    required this.policySourceId,
    required this.policySourceRevision,
  });

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
  }) : circuits = List.unmodifiable(circuits);

  final List<CalculatedElectricalCircuit> circuits;
}
