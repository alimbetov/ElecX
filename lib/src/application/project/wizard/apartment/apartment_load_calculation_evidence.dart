import '../../../../domain/electrical_load_calculation.dart';
import '../../../../engine/load_calculation_engine.dart';
import 'apartment_engineering_requirements.dart';

/// Replaces only the P9.5-A load requirement with proven calculation evidence.
/// Supply, circuit and protection requirements remain untouched and therefore
/// continue to block equipment configuration until independently proven.
abstract final class ApartmentLoadCalculationEvidenceService {
  static ApartmentEngineeringDesignRequirements apply({
    required ApartmentEngineeringDesignRequirements requirements,
    required ElectricalLoadCalculationRequest request,
    required ElectricalLoadCalculationResult calculation,
  }) {
    final loadRequirements = requirements.requirements
        .where(
          (item) => item.domain == ApartmentEngineeringRequirementDomain.load,
        )
        .toList(growable: false);
    if (loadRequirements.length != 1) {
      throw StateError(
        'P9.5-A must contain exactly one load requirement; found '
        '${loadRequirements.length}.',
      );
    }

    _validateCalculationBinding(request: request, calculation: calculation);
    final current = loadRequirements.single;
    final factEvidence = <ApartmentEngineeringFactEvidence>[
      ApartmentEngineeringFactEvidence(
        factKey: 'load.connectedPowerW',
        valueKind: ApartmentEngineeringFactValueKind.integer,
        value: calculation.connectedPowerW,
        unit: ApartmentEngineeringFactUnit.watt,
        sourceId: electricalLoadCalculationVersion,
        sourceRevision: electricalLoadCalculationVersion,
      ),
      ApartmentEngineeringFactEvidence(
        factKey: 'load.designPowerW',
        valueKind: ApartmentEngineeringFactValueKind.decimal,
        value: calculation.designPowerW,
        unit: ApartmentEngineeringFactUnit.watt,
        sourceId: electricalLoadCalculationVersion,
        sourceRevision: electricalLoadCalculationVersion,
      ),
      ApartmentEngineeringFactEvidence(
        factKey: 'load.designCurrentA',
        valueKind: ApartmentEngineeringFactValueKind.decimal,
        value: calculation.designCurrentA,
        unit: ApartmentEngineeringFactUnit.ampere,
        sourceId: electricalLoadCalculationVersion,
        sourceRevision: electricalLoadCalculationVersion,
      ),
      ApartmentEngineeringFactEvidence(
        factKey: 'load.diversityPolicy',
        valueKind: ApartmentEngineeringFactValueKind.text,
        value: request.diversityPolicy.id,
        unit: ApartmentEngineeringFactUnit.code,
        sourceId: request.diversityPolicy.sourceId,
        sourceRevision: request.diversityPolicy.sourceRevision,
      ),
    ];

    final provenLoad = ApartmentEngineeringRequirement(
      requirementId: current.requirementId,
      domain: current.domain,
      subjectKind: current.subjectKind,
      subjectStableId: current.subjectStableId,
      evidenceState: ApartmentEngineeringRequirementEvidenceState.proven,
      criticality: current.criticality,
      rationaleCode: 'p9.requirements.load-calculated',
      requiredFactKeys: current.requiredFactKeys,
      factEvidence: factEvidence,
    );

    return ApartmentEngineeringDesignRequirements(
      requirementsVersion: requirements.requirementsVersion,
      selectedCandidateFingerprint: requirements.selectedCandidateFingerprint,
      projectionFingerprint: requirements.projectionFingerprint,
      graphFingerprint: requirements.graphFingerprint,
      placementFingerprint: requirements.placementFingerprint,
      normativeEvidenceFingerprint: requirements.normativeEvidenceFingerprint,
      normativeProfileId: requirements.normativeProfileId,
      normativeProfileVersion: requirements.normativeProfileVersion,
      requirements: [
        for (final item in requirements.requirements)
          if (item.domain == ApartmentEngineeringRequirementDomain.load)
            provenLoad
          else
            item,
      ],
    );
  }

  static void _validateCalculationBinding({
    required ElectricalLoadCalculationRequest request,
    required ElectricalLoadCalculationResult calculation,
  }) {
    if (calculation.phaseSystem != request.phaseSystem ||
        calculation.nominalVoltageV != request.nominalVoltageV ||
        calculation.diversityPolicyId != request.diversityPolicy.id ||
        calculation.diversityFactor != request.diversityPolicy.factor ||
        calculation.reservePolicyId != request.reservePolicy.id ||
        calculation.reserveRatio != request.reservePolicy.reserveRatio) {
      throw ArgumentError(
        'Load calculation result does not match the supplied calculation request.',
      );
    }
    final requestIds = request.loads.map((item) => item.id).toSet();
    final resultIds = calculation.contributions
        .map((item) => item.loadId)
        .toSet();
    if (requestIds.length != resultIds.length ||
        !requestIds.containsAll(resultIds)) {
      throw ArgumentError(
        'Load calculation contributions do not match the supplied loads.',
      );
    }
  }
}
