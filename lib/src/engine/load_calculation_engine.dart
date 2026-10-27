import 'dart:math' as math;

import '../domain/electrical_load_calculation.dart';

const String electricalLoadCalculationVersion =
    'electrical.load-calculation.v2';

/// Deterministic active/reactive/apparent-power calculation for one electrical
/// group.
///
/// Calculation order:
/// connected -> utilization -> P/Q aggregation -> diversity -> explicit
/// reserve -> apparent power -> design current.
///
/// Power factor and reactive-power direction are applied per load. The engine
/// aggregates P and Q before deriving S, so mixed power factors are treated as
/// electrical vectors rather than by summing individual apparent powers.
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
          utilizedReactivePowerVar: _reactivePowerVar(load),
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
    final utilizedReactivePowerVar = contributions.fold<double>(
      0,
      (sum, item) => sum + item.utilizedReactivePowerVar,
    );

    final diversity = request.diversityPolicy.factor;
    final reserveMultiplier = 1 + request.reservePolicy.reserveRatio;
    final designScale = diversity * reserveMultiplier;
    final designPowerW = utilizedPowerW * designScale;
    final designReactivePowerVar = utilizedReactivePowerVar * designScale;
    final designApparentPowerVa = math.sqrt(
      designPowerW * designPowerW +
          designReactivePowerVar * designReactivePowerVar,
    );
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
      utilizedReactivePowerVar: utilizedReactivePowerVar,
      designPowerW: designPowerW,
      designReactivePowerVar: designReactivePowerVar,
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

  static double _reactivePowerVar(ElectricalLoadInput load) {
    if (load.utilizedPowerW == 0 || load.powerFactor == 1) return 0;
    final phaseAngle = math.acos(load.powerFactor);
    final magnitude = load.utilizedPowerW * math.tan(phaseAngle);
    return switch (load.reactivePowerKind) {
      ElectricalReactivePowerKind.lagging => magnitude,
      ElectricalReactivePowerKind.leading => -magnitude,
    };
  }
}
