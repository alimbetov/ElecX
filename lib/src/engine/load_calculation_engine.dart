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
    _validateRequest(request);

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

  static void _validateRequest(ElectricalLoadCalculationRequest request) {
    if (!request.nominalVoltageV.isFinite || request.nominalVoltageV <= 0) {
      throw ArgumentError.value(request.nominalVoltageV, 'nominalVoltageV');
    }
    if (request.loads.isEmpty) {
      throw ArgumentError('At least one electrical load is required.');
    }

    final loadIds = <String>{};
    for (final load in request.loads) {
      if (load.id.trim().isEmpty ||
          load.sourceId.trim().isEmpty ||
          load.sourceRevision.trim().isEmpty) {
        throw ArgumentError(
          'Electrical load identity/source fields must be non-empty.',
        );
      }
      if (!loadIds.add(load.id)) {
        throw ArgumentError('Duplicate electrical load id ${load.id}.');
      }
      if (load.ratedPowerW < 0) {
        throw ArgumentError.value(load.ratedPowerW, 'ratedPowerW');
      }
      if (load.quantity <= 0) {
        throw ArgumentError.value(load.quantity, 'quantity');
      }
      if (!load.utilizationFactor.isFinite ||
          load.utilizationFactor <= 0 ||
          load.utilizationFactor > 1) {
        throw ArgumentError.value(
          load.utilizationFactor,
          'utilizationFactor',
        );
      }
      if (!load.powerFactor.isFinite ||
          load.powerFactor <= 0 ||
          load.powerFactor > 1) {
        throw ArgumentError.value(load.powerFactor, 'powerFactor');
      }
    }

    final diversity = request.diversityPolicy;
    if (diversity.id.trim().isEmpty ||
        diversity.sourceId.trim().isEmpty ||
        diversity.sourceRevision.trim().isEmpty) {
      throw ArgumentError(
        'Electrical diversity policy identity/source must be non-empty.',
      );
    }
    if (!diversity.factor.isFinite ||
        diversity.factor <= 0 ||
        diversity.factor > 1) {
      throw ArgumentError.value(diversity.factor, 'diversityFactor');
    }

    final reserve = request.reservePolicy;
    if (reserve.id.trim().isEmpty ||
        reserve.sourceId.trim().isEmpty ||
        reserve.sourceRevision.trim().isEmpty) {
      throw ArgumentError(
        'Electrical reserve policy identity/source must be non-empty.',
      );
    }
    if (!reserve.reserveRatio.isFinite || reserve.reserveRatio < 0) {
      throw ArgumentError.value(reserve.reserveRatio, 'reserveRatio');
    }
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
