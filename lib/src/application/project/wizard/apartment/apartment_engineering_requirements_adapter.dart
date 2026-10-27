import 'apartment_candidate_set_service.dart';
import 'apartment_engineering_requirements.dart';

/// Production-facing P9.5-A adapter for an already-qualified preview card.
///
/// The adapter derives requirements from the exact P9.3 projection and P9.4
/// evidence already owned by the card. No generator, geometry, normative rule
/// or catalog stage is rerun.
extension ApartmentCandidateCardEngineeringRequirements
    on ApartmentCandidateCard {
  ApartmentEngineeringRequirementsResult deriveEngineeringRequirements({
    ApartmentEngineeringRequirementsService service =
        const ApartmentEngineeringRequirementsService(),
  }) =>
      service.derive(
        selectedCandidateFingerprint: candidateFingerprint,
        projection: engineeringProjection,
        normativeEvidence: normativeEvidence,
      );

  ApartmentEngineeringDesignRequirements get engineeringRequirements {
    final result = deriveEngineeringRequirements();
    final requirements = result.requirements;
    if (!result.accepted || requirements == null) {
      final codes = result.failures.map((failure) => failure.code).join(',');
      throw StateError(
        'Accepted apartment candidate cannot derive P9.5-A requirements: '
        '$codes',
      );
    }
    return requirements;
  }
}

extension ApartmentCandidateSetEngineeringRequirements
    on ApartmentCandidateSet {
  /// Backward-compatible requirements view for the selected production winner.
  ApartmentEngineeringDesignRequirements get engineeringRequirements =>
      recommendedCandidate.engineeringRequirements;
}
