import 'apartment_engineering_requirements.dart';

/// Binds source-pinned facts to a P9.5-A requirements envelope without
/// inventing or deriving electrical intent.
///
/// Complete evidence promotes a requirement to `proven`; partial evidence is
/// `indeterminate` and therefore remains blocking for critical requirements.
extension ApartmentEngineeringEvidenceBinding
    on ApartmentEngineeringDesignRequirements {
  ApartmentEngineeringDesignRequirements bindAuthoritativeEvidence(
    Iterable<ApartmentEngineeringFactEvidence> evidence,
  ) {
    final incoming = <String, ApartmentEngineeringFactEvidence>{};
    for (final fact in evidence) {
      final previous = incoming[fact.factKey];
      if (previous != null &&
          previous.evidenceFingerprint != fact.evidenceFingerprint) {
        throw ArgumentError(
          'Conflicting P9.5 evidence for ${fact.factKey}.',
        );
      }
      incoming[fact.factKey] = fact;
    }

    final declaredKeys = <String>{
      for (final requirement in requirements) ...requirement.requiredFactKeys,
    };
    final unknownKeys = incoming.keys
        .where((key) => !declaredKeys.contains(key))
        .toList(growable: false)
      ..sort();
    if (unknownKeys.isNotEmpty) {
      throw ArgumentError(
        'P9.5 evidence contains undeclared facts: $unknownKeys.',
      );
    }

    final rebound = <ApartmentEngineeringRequirement>[];
    for (final requirement in requirements) {
      final merged = <String, ApartmentEngineeringFactEvidence>{
        ...requirement.factEvidence,
      };
      for (final key in requirement.requiredFactKeys) {
        final fact = incoming[key];
        if (fact == null) {
          continue;
        }
        final previous = merged[key];
        if (previous != null &&
            previous.evidenceFingerprint != fact.evidenceFingerprint) {
          throw ArgumentError('Conflicting P9.5 evidence for $key.');
        }
        merged[key] = fact;
      }

      if (requirement.evidenceState ==
              ApartmentEngineeringRequirementEvidenceState.notApplicable &&
          merged.isNotEmpty) {
        throw ArgumentError(
          'P9.5 not-applicable requirement ${requirement.requirementId} '
          'cannot receive evidence.',
        );
      }

      final hasAll = requirement.requiredFactKeys.every(merged.containsKey);
      final state = requirement.evidenceState ==
              ApartmentEngineeringRequirementEvidenceState.notApplicable
          ? ApartmentEngineeringRequirementEvidenceState.notApplicable
          : hasAll
              ? ApartmentEngineeringRequirementEvidenceState.proven
              : merged.isEmpty
                  ? ApartmentEngineeringRequirementEvidenceState.notEvaluated
                  : ApartmentEngineeringRequirementEvidenceState.indeterminate;

      rebound.add(
        ApartmentEngineeringRequirement(
          requirementId: requirement.requirementId,
          domain: requirement.domain,
          subjectKind: requirement.subjectKind,
          subjectStableId: requirement.subjectStableId,
          evidenceState: state,
          criticality: requirement.criticality,
          rationaleCode: requirement.rationaleCode,
          requiredFactKeys: requirement.requiredFactKeys,
          factEvidence: merged.values,
        ),
      );
    }

    return ApartmentEngineeringDesignRequirements(
      requirementsVersion: requirementsVersion,
      selectedCandidateFingerprint: selectedCandidateFingerprint,
      projectionFingerprint: projectionFingerprint,
      graphFingerprint: graphFingerprint,
      placementFingerprint: placementFingerprint,
      normativeEvidenceFingerprint: normativeEvidenceFingerprint,
      normativeProfileId: normativeProfileId,
      normativeProfileVersion: normativeProfileVersion,
      requirements: rebound,
    );
  }
}
