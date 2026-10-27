import 'apartment_candidate_set_service.dart';
import 'apartment_engineering_evidence_binding.dart';
import 'apartment_engineering_requirements.dart';
import 'apartment_engineering_requirements_adapter.dart';
import 'apartment_equipment_autoconfiguration_service.dart';
import 'apartment_equipment_configuration.dart';
import 'apartment_verified_product_catalog.dart';
import 'p9_failure.dart';

/// P9.5-E production wiring for an accepted preview candidate.
///
/// The caller supplies authoritative electrical facts and a revision-pinned
/// verified product catalog. This extension does not Apply or persist anything.
extension ApartmentCandidateCardEquipmentAutoConfiguration
    on ApartmentCandidateCard {
  ApartmentEquipmentConfigurationResult configureEquipment({
    required Iterable<ApartmentEngineeringFactEvidence> authoritativeFacts,
    required ApartmentVerifiedProductVariantCatalog catalog,
    ApartmentEquipmentAutoConfigurationService service =
        const ApartmentEquipmentAutoConfigurationService(),
  }) {
    final requirementsResult = deriveEngineeringRequirements();
    final baseRequirements = requirementsResult.requirements;
    if (!requirementsResult.accepted || baseRequirements == null) {
      return ApartmentEquipmentConfigurationResult(
        configuration: null,
        failures: requirementsResult.failures,
      );
    }

    late final ApartmentEngineeringDesignRequirements boundRequirements;
    try {
      boundRequirements = baseRequirements.bindAuthoritativeEvidence(
        authoritativeFacts,
      );
    } on Object catch (error) {
      return ApartmentEquipmentConfigurationResult(
        configuration: null,
        failures: [
          P9Failure(
            code: 'EQUIPMENT_EVIDENCE_BINDING_INVALID',
            stage: P9FailureStage.catalog,
            severity: P9FailureSeverity.blocker,
            facts: {
              'candidateFingerprint': candidateFingerprint,
              'requirementsFingerprint':
                  baseRequirements.requirementsFingerprint,
              'errorType': error.runtimeType.toString(),
            },
          ),
        ],
      );
    }

    return service.configure(
      requirements: boundRequirements,
      catalog: catalog,
    );
  }
}

extension ApartmentCandidateSetEquipmentAutoConfiguration
    on ApartmentCandidateSet {
  ApartmentEquipmentConfigurationResult configureRecommendedEquipment({
    required Iterable<ApartmentEngineeringFactEvidence> authoritativeFacts,
    required ApartmentVerifiedProductVariantCatalog catalog,
    ApartmentEquipmentAutoConfigurationService service =
        const ApartmentEquipmentAutoConfigurationService(),
  }) =>
      recommendedCandidate.configureEquipment(
        authoritativeFacts: authoritativeFacts,
        catalog: catalog,
        service: service,
      );
}
