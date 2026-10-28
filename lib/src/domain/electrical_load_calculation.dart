enum ElectricalLoadPhaseSystem { singlePhaseAc, threePhaseAc }

enum ElectricalReactivePowerKind { lagging, leading }

/// One authoritative load input participating in a circuit/group calculation.
///
/// The model deliberately keeps utilization, power factor and reactive-power
/// direction explicit. Unknown values must be resolved upstream instead of
/// being replaced by hidden defaults inside the calculation engine.
final class ElectricalLoadInput {
  const ElectricalLoadInput({
    required this.id,
    required this.ratedPowerW,
    required this.quantity,
    required this.utilizationFactor,
    required this.powerFactor,
    required this.reactivePowerKind,
    required this.sourceId,
    required this.sourceRevision,
  })  : assert(ratedPowerW >= 0),
        assert(quantity > 0),
        assert(utilizationFactor > 0 && utilizationFactor <= 1),
        assert(powerFactor > 0 && powerFactor <= 1),
        assert(id != ''),
        assert(sourceId != ''),
        assert(sourceRevision != '');

  final String id;
  final int ratedPowerW;
  final int quantity;
  final double utilizationFactor;
  final double powerFactor;
  final ElectricalReactivePowerKind reactivePowerKind;
  final String sourceId;
  final String sourceRevision;

  int get connectedPowerW => ratedPowerW * quantity;
  double get utilizedPowerW => connectedPowerW * utilizationFactor;
}

/// Explicit diversity/simultaneity policy. A value below one reduces the
/// utilized load according to the cited engineering policy.
final class ElectricalDiversityPolicy {
  const ElectricalDiversityPolicy({
    required this.id,
    required this.factor,
    required this.sourceId,
    required this.sourceRevision,
  })  : assert(id != ''),
        assert(factor > 0 && factor <= 1),
        assert(sourceId != ''),
        assert(sourceRevision != '');

  final String id;
  final double factor;
  final String sourceId;
  final String sourceRevision;
}

/// Optional explicit project reserve applied after utilization and diversity.
///
/// This is intentionally separate from diversity: reserve must never be hidden
/// inside Ks/Ki and therefore cannot be applied twice accidentally.
final class ElectricalReservePolicy {
  const ElectricalReservePolicy({
    required this.id,
    required this.reserveRatio,
    required this.sourceId,
    required this.sourceRevision,
  })  : assert(id != ''),
        assert(reserveRatio >= 0),
        assert(sourceId != ''),
        assert(sourceRevision != '');

  final String id;
  final double reserveRatio;
  final String sourceId;
  final String sourceRevision;

  static const none = ElectricalReservePolicy(
    id: 'none',
    reserveRatio: 0,
    sourceId: 'project-policy',
    sourceRevision: 'none',
  );
}

final class ElectricalLoadCalculationRequest {
  ElectricalLoadCalculationRequest({
    required this.phaseSystem,
    required this.nominalVoltageV,
    required Iterable<ElectricalLoadInput> loads,
    required this.diversityPolicy,
    this.reservePolicy = ElectricalReservePolicy.none,
  }) : loads = List.unmodifiable(loads) {
    if (nominalVoltageV <= 0) {
      throw ArgumentError.value(nominalVoltageV, 'nominalVoltageV');
    }
    if (this.loads.isEmpty) {
      throw ArgumentError('At least one electrical load is required.');
    }
    final ids = <String>{};
    for (final load in this.loads) {
      if (!ids.add(load.id)) {
        throw ArgumentError('Duplicate electrical load id ${load.id}.');
      }
    }
  }

  final ElectricalLoadPhaseSystem phaseSystem;
  final double nominalVoltageV;
  final List<ElectricalLoadInput> loads;
  final ElectricalDiversityPolicy diversityPolicy;
  final ElectricalReservePolicy reservePolicy;
}

final class ElectricalLoadContribution {
  const ElectricalLoadContribution({
    required this.loadId,
    required this.connectedPowerW,
    required this.utilizedPowerW,
    required this.utilizedReactivePowerVar,
  });

  final String loadId;
  final int connectedPowerW;
  final double utilizedPowerW;
  final double utilizedReactivePowerVar;
}

final class ElectricalLoadCalculationResult {
  const ElectricalLoadCalculationResult({
    required this.connectedPowerW,
    required this.utilizedPowerW,
    required this.utilizedReactivePowerVar,
    required this.designPowerW,
    required this.designReactivePowerVar,
    required this.designApparentPowerVa,
    required this.designCurrentA,
    required this.equivalentPowerFactor,
    required this.diversityPolicyId,
    required this.diversityFactor,
    required this.reservePolicyId,
    required this.reserveRatio,
    required this.phaseSystem,
    required this.nominalVoltageV,
    required this.contributions,
  });

  final int connectedPowerW;
  final double utilizedPowerW;
  final double utilizedReactivePowerVar;
  final double designPowerW;
  final double designReactivePowerVar;
  final double designApparentPowerVa;
  final double designCurrentA;
  final double equivalentPowerFactor;
  final String diversityPolicyId;
  final double diversityFactor;
  final String reservePolicyId;
  final double reserveRatio;
  final ElectricalLoadPhaseSystem phaseSystem;
  final double nominalVoltageV;
  final List<ElectricalLoadContribution> contributions;
}
