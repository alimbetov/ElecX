import '../../../../domain/overcurrent_protection.dart';
import '../../../../engine/overcurrent_protection_selection_engine.dart';
import 'apartment_engineering_requirements.dart';

/// Adds proven overload coordination evidence without falsely marking the whole
/// protection domain as proven.
///
/// Breaking capacity participates in candidate filtering, but it is not enough
/// to establish the broader `protection.shortCircuit` fact. Short-circuit
/// thermal withstand, residual-current protection and disconnection evidence
/// remain mandatory, so the requirement stays indeterminate.
abstract final class ApartmentOvercurrentProtectionEvidenceService {
  static ApartmentEngineeringDesignRequirements apply({
    required ApartmentEngineeringDesignRequirements requirements,
    required OvercurrentProtectionRequest request,
    required OvercurrentProtectionSelectionResult selection,
  }) {
    final protectionRequirements = requirements.requirements
        .where(
          (item) =>
              item.domain == ApartmentEngineeringRequirementDomain.protection,
        )
        .toList(growable: false);
    if (protectionRequirements.length != 1) {
      throw StateError(
        'P9.5-A must contain exactly one protection requirement; found '
        '${protectionRequirements.length}.',
      );
    }
    if (!selection.isSelected || selection.selected == null) {
      throw ArgumentError(
        'Overcurrent evidence requires one compliant selected device.',
      );
    }

    final selected = selection.selected!;
    _validateSelectionBinding(request: request, selected: selected);
    final current = protectionRequirements.single;
    final partialProtection = ApartmentEngineeringRequirement(
      requirementId: current.requirementId,
      domain: current.domain,
      subjectKind: current.subjectKind,
      subjectStableId: current.subjectStableId,
      evidenceState: ApartmentEngineeringRequirementEvidenceState.indeterminate,
      criticality: current.criticality,
      rationaleCode: 'p9.requirements.protection-overcurrent-proven-partial',
      requiredFactKeys: current.requiredFactKeys,
      factEvidence: [
        ApartmentEngineeringFactEvidence(
          factKey: 'protection.overload',
          valueKind: ApartmentEngineeringFactValueKind.text,
          value: 'Ib=${request.designCurrentA};In=${selected.ratedCurrentA};'
              'Iz=${request.cableAmpacityA};device=${selected.id};'
              'breakingCapacityKa=${selected.breakingCapacityKa};'
              'Ipsc=${request.prospectiveShortCircuitCurrentA}',
          unit: ApartmentEngineeringFactUnit.code,
          sourceId: overcurrentProtectionSelectionVersion,
          sourceRevision: overcurrentProtectionSelectionVersion,
        ),
      ],
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
          if (item.domain == ApartmentEngineeringRequirementDomain.protection)
            partialProtection
          else
            item,
      ],
    );
  }

  static void _validateSelectionBinding({
    required OvercurrentProtectionRequest request,
    required OvercurrentProtectiveDeviceSpec selected,
  }) {
    final exists = request.candidates.any(
      (candidate) =>
          candidate.id == selected.id &&
          candidate.kind == selected.kind &&
          candidate.ratedCurrentA == selected.ratedCurrentA &&
          candidate.breakingCapacityKa == selected.breakingCapacityKa &&
          candidate.poleCount == selected.poleCount &&
          candidate.tripCurve == selected.tripCurve &&
          candidate.sourceId == selected.sourceId &&
          candidate.sourceRevision == selected.sourceRevision,
    );
    if (!exists ||
        !request.allowedKinds.contains(selected.kind) ||
        selected.ratedCurrentA < request.designCurrentA ||
        selected.ratedCurrentA > request.cableAmpacityA ||
        selected.breakingCapacityKa * 1000 <
            request.prospectiveShortCircuitCurrentA) {
      throw ArgumentError(
        'Selected protective device is not bound to the supplied request.',
      );
    }
  }
}
