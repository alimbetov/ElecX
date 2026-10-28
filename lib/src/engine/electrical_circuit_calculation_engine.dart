import '../domain/electrical_circuit_calculation.dart';
import '../domain/electrical_load_calculation.dart';
import 'load_calculation_engine.dart';

const String electricalCircuitCalculationVersion =
    'electrical.circuit-calculation.v1';

/// Calculates P/Q/S/Ib independently for every synthesized circuit.
///
/// Every circuit must have one explicit policy. This prevents the engine from
/// silently applying global residential voltage/diversity assumptions.
abstract final class ElectricalCircuitCalculationEngine {
  static ElectricalCircuitCalculationResult calculate(
    ElectricalCircuitCalculationRequest request,
  ) {
    final policyByCircuit = {
      for (final policy in request.policies) policy.circuitId: policy,
    };
    final calculated = <CalculatedElectricalCircuit>[];

    for (final circuit in request.synthesis.circuits) {
      final policy = policyByCircuit[circuit.id];
      if (policy == null) {
        throw StateError('Missing calculation policy for ${circuit.id}.');
      }
      final calculation = LoadCalculationEngine.calculate(
        ElectricalLoadCalculationRequest(
          phaseSystem: circuit.requiredPhaseSystem,
          nominalVoltageV: policy.nominalVoltageV,
          loads: circuit.loads.map((item) => item.load),
          diversityPolicy: policy.diversityPolicy,
          reservePolicy: policy.reservePolicy,
        ),
      );
      calculated.add(
        CalculatedElectricalCircuit(
          circuit: circuit,
          calculation: calculation,
          policySourceId: policy.sourceId,
          policySourceRevision: policy.sourceRevision,
        ),
      );
    }

    calculated.sort((left, right) => left.id.compareTo(right.id));
    return ElectricalCircuitCalculationResult(circuits: calculated);
  }
}
