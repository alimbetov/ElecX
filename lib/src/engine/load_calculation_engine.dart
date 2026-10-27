import 'dart:math' as math;

import '../domain/electrical_load_calculation.dart';

const String electricalLoadCalculationVersion =
    'electrical.load-calculation.v1';

/// Deterministic active/apparent-power calculation for one electrical group.
///
/// Calculation order:
/// connected -> utilization -> diversity -> explicit reserve -> design current.
/// Power factor is applied per load before aggregation, so mixed load types do
/// not rely on one guessed group cos(phi).
abstract final class LoadCalculationEngine {
  static ElectricalLoadCalculationResult calculate(
    ElectricalLoadCalculationRequest request,
  ) {
    final contributions = <ElectricalLoadContribution>[
      for (final load in request.loads)
        ElectricalLoadContribution(
          loadId: load.id,
          connectedPowerW: load.connectedPowerW,
          utilizedPowerW: load.utilizedPowerW,
          utilizedApparentPowerVa: load.utilizedApparentPowerVa,
        ),
    ]..sort((left, right) => left.loadId.compareTo(right.loadId));

    final connectedPowerW = contributions.fold<int>(
      0,
      (sum, item) => sum + item.connectedPowerW,
    );
    final utilizedPowerW = contributions.fold<double>(
      0,
      (sum, item) => sum + item.utilizedPowerW,
    );
    final utilizedApparentPowerVa = contributions.fold<double>(
      0,
      (sum, item) => sum + item.utilizedApparentPowerVa,
    );

    final diversity = request.diversityPolicy.factor;
    final reserveMultiplier = 1 + request.reservePolicy.reserveRatio;
    final designPowerW = utilizedPowerW * diversity * reserveMultiplier;
    final designApparentPowerVa =
        utilizedApparentPowerVa * diversity * reserveMultiplier;
    final equivalentPowerFactor =
        designApparentPowerVa == 0 ? 1.0 : designPowerW / designApparentPowerVa;
    final currentDivisor = switch (request.phaseSystem) {
      ElectricalLoadPhaseSystem.singlePhaseAc => request.nominalVoltageV,
      ElectricalLoadPhaseSystem.threePhaseAc =>
        math.sqrt(3) * request.nominalVoltageV,
    };
    final designCurrentA = designApparentPowerVa / currentDivisor;

    return ElectricalLoadCalculationResult(
      connectedPowerW: connectedPowerW,
      utilizedPowerW: utilizedPowerW,
      designPowerW: designPowerW,
      designApparentPowerVa: designApparentPowerVa,
      designCurrentA: designCurrentA,
      equivalentPowerFactor: equivalentPowerFactor,
      diversityPolicyId: request.diversityPolicy.id,
      diversityFactor: diversity,
      reservePolicyId: request.reservePolicy.id,
      reserveRatio: request.reservePolicy.reserveRatio,
      phaseSystem: request.phaseSystem,
      nominalVoltageV: request.nominalVoltageV,
      contributions: List.unmodifiable(contributions),
    );
  }
}
