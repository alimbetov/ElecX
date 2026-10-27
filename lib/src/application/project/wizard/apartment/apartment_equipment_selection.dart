import 'apartment_engineering_requirements.dart';
import 'apartment_verified_product_catalog.dart';
import 'p9_canonical_serialization.dart';
import 'p9_sha256.dart';

const String apartmentEquipmentConfigurationVersion =
    'p9.equipment-configuration.v1';

enum ApartmentEquipmentConfigurationSlot {
  protection,
  conductor,
  panel,
}

enum ApartmentEquipmentCandidateState {
  selected,
  alternative,
  engineeringRejected,
  normativeRejected,
}

enum ApartmentEquipmentRejectionCode {
  voltageInsufficient,
  polesInsufficient,
  ratedCurrentInsufficient,
  breakingCapacityInsufficient,
  residualProtectionMissing,
  residualCurrentTooHigh,
  conductorCrossSectionInsufficient,
  cableAmpacityInsufficient,
  panelPhaseCountInsufficient,
  panelModuleCapacityInsufficient,
  normativeProfileNotVerified,
}

/// Typed equipment-facing interpretation of already-proven P9.5-A facts.
///
/// No value is inferred here. Required facts must exist with the expected unit
/// and numeric type, otherwise auto-configuration fails closed.
final class ApartmentEquipmentConfigurationIntent {
  const ApartmentEquipmentConfigurationIntent._({
    required this.supplyVoltageV,
    required this.phaseCount,
    required this.prospectiveShortCircuitCurrentA,
    required this.availablePowerW,
    required this.designPowerW,
    required this.designCurrentA,
    required this.minimumConductorCrossSectionMm2,
    required this.maximumResidualCurrentMA,
  });

  factory ApartmentEquipmentConfigurationIntent.fromRequirements(
    ApartmentEngineeringDesignRequirements requirements,
  ) {
    if (!requirements.readyForEquipmentConfiguration) {
      throw StateError(
        'P9.5-C requires a fully resolved engineering requirements envelope.',
      );
    }
    final facts = _indexFacts(requirements);
    return ApartmentEquipmentConfigurationIntent._(
      supplyVoltageV: _numericFact(
        facts,
        'supply.voltageV',
        ApartmentEngineeringFactUnit.volt,
      ),
      phaseCount: _integerFact(
        facts,
        'supply.phaseCount',
        ApartmentEngineeringFactUnit.count,
      ),
      prospectiveShortCircuitCurrentA: _numericFact(
        facts,
        'supply.prospectiveShortCircuitCurrentA',
        ApartmentEngineeringFactUnit.ampere,
      ),
      availablePowerW: _numericFact(
        facts,
        'supply.availablePowerW',
        ApartmentEngineeringFactUnit.watt,
      ),
      designPowerW: _numericFact(
        facts,
        'load.designPowerW',
        ApartmentEngineeringFactUnit.watt,
      ),
      designCurrentA: _numericFact(
        facts,
        'load.designCurrentA',
        ApartmentEngineeringFactUnit.ampere,
      ),
      minimumConductorCrossSectionMm2: _numericFact(
        facts,
        'circuit.conductorConstraints',
        ApartmentEngineeringFactUnit.squareMillimeter,
      ),
      maximumResidualCurrentMA: _numericFact(
        facts,
        'protection.residualCurrent',
        ApartmentEngineeringFactUnit.milliampere,
      ),
    );
  }

  final double supplyVoltageV;
  final int phaseCount;
  final double prospectiveShortCircuitCurrentA;
  final double availablePowerW;
  final double designPowerW;
  final double designCurrentA;
  final double minimumConductorCrossSectionMm2;
  final double maximumResidualCurrentMA;

  double get prospectiveShortCircuitCurrentKA =>
      prospectiveShortCircuitCurrentA / 1000.0;

  String get stableSerialization => p9CanonicalSerializeFields([
        MapEntry('supplyVoltageV', supplyVoltageV.toString()),
        MapEntry('phaseCount', phaseCount.toString()),
        MapEntry(
          'prospectiveShortCircuitCurrentA',
          prospectiveShortCircuitCurrentA.toString(),
        ),
        MapEntry('availablePowerW', availablePowerW.toString()),
        MapEntry('designPowerW', designPowerW.toString()),
        MapEntry('designCurrentA', designCurrentA.toString()),
        MapEntry(
          'minimumConductorCrossSectionMm2',
          minimumConductorCrossSectionMm2.toString(),
        ),
        MapEntry(
          'maximumResidualCurrentMA',
          maximumResidualCurrentMA.toString(),
        ),
      ]);

  String get intentFingerprint => p9Sha256Hex(stableSerialization);
}

final class ApartmentEquipmentFeasibilityEvaluation {
  ApartmentEquipmentFeasibilityEvaluation({
    required this.variant,
    required Iterable<ApartmentEquipmentRejectionCode> rejectionCodes,
  }) : rejectionCodes = List.unmodifiable(
          rejectionCodes.toSet().toList()
            ..sort((left, right) => left.name.compareTo(right.name)),
        );

  final ApartmentVerifiedProductVariant variant;
  final List<ApartmentEquipmentRejectionCode> rejectionCodes;

  bool get feasible => rejectionCodes.isEmpty;
}

final class ApartmentEngineeringFeasibilityEvaluator {
  const ApartmentEngineeringFeasibilityEvaluator();

  ApartmentEquipmentFeasibilityEvaluation evaluate({
    required ApartmentVerifiedProductVariant variant,
    required ApartmentEquipmentConfigurationIntent intent,
    int requiredPanelModules = 1,
  }) {
    final rejections = <ApartmentEquipmentRejectionCode>[];
    final ratings = variant.ratings;
    switch (variant.kind) {
      case ApartmentEquipmentProductKind.circuitBreaker:
      case ApartmentEquipmentProductKind.rcbo:
        if (ratings.ratedVoltageV! < intent.supplyVoltageV) {
          rejections.add(
            ApartmentEquipmentRejectionCode.voltageInsufficient,
          );
        }
        if (ratings.poleCount! < intent.phaseCount) {
          rejections.add(ApartmentEquipmentRejectionCode.polesInsufficient);
        }
        if (ratings.ratedCurrentA! < intent.designCurrentA) {
          rejections.add(
            ApartmentEquipmentRejectionCode.ratedCurrentInsufficient,
          );
        }
        if (ratings.breakingCapacityKA! <
            intent.prospectiveShortCircuitCurrentKA) {
          rejections.add(
            ApartmentEquipmentRejectionCode.breakingCapacityInsufficient,
          );
        }
        if (variant.kind == ApartmentEquipmentProductKind.circuitBreaker) {
          rejections.add(
            ApartmentEquipmentRejectionCode.residualProtectionMissing,
          );
        } else if (ratings.residualCurrentMA! >
            intent.maximumResidualCurrentMA) {
          rejections.add(
            ApartmentEquipmentRejectionCode.residualCurrentTooHigh,
          );
        }
        break;
      case ApartmentEquipmentProductKind.cable:
        if (ratings.conductorCrossSectionMm2! <
            intent.minimumConductorCrossSectionMm2) {
          rejections.add(
            ApartmentEquipmentRejectionCode.conductorCrossSectionInsufficient,
          );
        }
        if (ratings.currentCapacityA! < intent.designCurrentA) {
          rejections.add(
            ApartmentEquipmentRejectionCode.cableAmpacityInsufficient,
          );
        }
        break;
      case ApartmentEquipmentProductKind.distributionBoard:
        if (ratings.supportedPhaseCount! < intent.phaseCount) {
          rejections.add(
            ApartmentEquipmentRejectionCode.panelPhaseCountInsufficient,
          );
        }
        if (ratings.moduleCapacity! < requiredPanelModules) {
          rejections.add(
            ApartmentEquipmentRejectionCode.panelModuleCapacityInsufficient,
          );
        }
        break;
    }
    return ApartmentEquipmentFeasibilityEvaluation(
      variant: variant,
      rejectionCodes: rejections,
    );
  }
}

final class ApartmentEquipmentNormativeEvaluation {
  ApartmentEquipmentNormativeEvaluation({
    required this.variant,
    required this.accepted,
  });

  final ApartmentVerifiedProductVariant variant;
  final bool accepted;

  ApartmentEquipmentRejectionCode? get rejectionCode => accepted
      ? null
      : ApartmentEquipmentRejectionCode.normativeProfileNotVerified;
}

/// Product normative verification is independent from electrical feasibility.
final class ApartmentEquipmentNormativeEvaluator {
  const ApartmentEquipmentNormativeEvaluator();

  ApartmentEquipmentNormativeEvaluation evaluate({
    required ApartmentVerifiedProductVariant variant,
    required String normativeProfileId,
    required String normativeProfileVersion,
  }) {
    final accepted = variant.normativeDeclarations.any(
      (declaration) =>
          declaration.profileId == normativeProfileId &&
          declaration.profileVersion == normativeProfileVersion,
    );
    return ApartmentEquipmentNormativeEvaluation(
      variant: variant,
      accepted: accepted,
    );
  }
}

/// Catalog resolver deliberately returns all supported variants; feasibility
/// and normative rejection remain visible and explainable downstream.
final class ApartmentEquipmentCandidateResolver {
  const ApartmentEquipmentCandidateResolver();

  List<ApartmentVerifiedProductVariant> resolve(
    ApartmentVerifiedProductVariantCatalog catalog,
  ) =>
      List.unmodifiable(catalog.variants);
}

Map<String, ApartmentEngineeringFactEvidence> _indexFacts(
  ApartmentEngineeringDesignRequirements requirements,
) {
  final result = <String, ApartmentEngineeringFactEvidence>{};
  for (final requirement in requirements.requirements) {
    for (final entry in requirement.factEvidence.entries) {
      final existing = result[entry.key];
      if (existing != null &&
          existing.evidenceFingerprint != entry.value.evidenceFingerprint) {
        throw StateError('Conflicting proven P9.5 fact ${entry.key}.');
      }
      result[entry.key] = entry.value;
    }
  }
  return result;
}

double _numericFact(
  Map<String, ApartmentEngineeringFactEvidence> facts,
  String key,
  ApartmentEngineeringFactUnit unit,
) {
  final fact = facts[key];
  if (fact == null || fact.unit != unit) {
    throw StateError('Missing or invalid P9.5 fact $key.');
  }
  final value = switch (fact.valueKind) {
    ApartmentEngineeringFactValueKind.integer => (fact.value as int).toDouble(),
    ApartmentEngineeringFactValueKind.decimal => fact.value as double,
    _ => throw StateError('P9.5 fact $key must be numeric.'),
  };
  if (!value.isFinite || value <= 0) {
    throw StateError('P9.5 fact $key must be finite and positive.');
  }
  return value;
}

int _integerFact(
  Map<String, ApartmentEngineeringFactEvidence> facts,
  String key,
  ApartmentEngineeringFactUnit unit,
) {
  final fact = facts[key];
  if (fact == null ||
      fact.unit != unit ||
      fact.valueKind != ApartmentEngineeringFactValueKind.integer) {
    throw StateError('Missing or invalid integer P9.5 fact $key.');
  }
  final value = fact.value as int;
  if (value <= 0) {
    throw StateError('P9.5 fact $key must be positive.');
  }
  return value;
}
