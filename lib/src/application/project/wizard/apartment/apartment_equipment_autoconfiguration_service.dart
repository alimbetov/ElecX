import 'apartment_engineering_requirements.dart';
import 'apartment_equipment_configuration.dart';
import 'apartment_overcurrent_product_adapter.dart';
import 'apartment_equipment_ranking.dart';
import 'apartment_equipment_selection.dart';
import 'apartment_verified_product_catalog.dart';
import 'p9_failure.dart';

final class ApartmentEquipmentAutoConfigurationService {
  const ApartmentEquipmentAutoConfigurationService({
    this.resolver = const ApartmentEquipmentCandidateResolver(),
    this.feasibilityEvaluator =
        const ApartmentEngineeringFeasibilityEvaluator(),
    this.normativeEvaluator = const ApartmentEquipmentNormativeEvaluator(),
    this.overcurrentEvaluator =
        const ApartmentOvercurrentProtectionProductEvaluator(),
    this.ranker = const ApartmentEquipmentDeterministicRanker(),
  });

  final ApartmentEquipmentCandidateResolver resolver;
  final ApartmentEngineeringFeasibilityEvaluator feasibilityEvaluator;
  final ApartmentEquipmentNormativeEvaluator normativeEvaluator;
  final ApartmentOvercurrentProtectionProductEvaluator overcurrentEvaluator;
  final ApartmentEquipmentDeterministicRanker ranker;

  ApartmentEquipmentConfigurationResult configure({
    required ApartmentEngineeringDesignRequirements requirements,
    required ApartmentVerifiedProductVariantCatalog catalog,
  }) {
    if (!requirements.readyForEquipmentConfiguration) {
      return _blocked(
        'EQUIPMENT_REQUIREMENTS_UNRESOLVED',
        P9FailureStage.catalog,
        {
          'requirementsFingerprint': requirements.requirementsFingerprint,
          'blockingRequirementIds': requirements.blockingUnresolvedRequirements
              .map((requirement) => requirement.requirementId)
              .toList(growable: false),
        },
      );
    }

    late final ApartmentEquipmentConfigurationIntent intent;
    try {
      intent = ApartmentEquipmentConfigurationIntent.fromRequirements(
        requirements,
      );
    } on Object catch (error) {
      return _blocked(
        'EQUIPMENT_FACT_SCHEMA_INVALID',
        P9FailureStage.catalog,
        {
          'requirementsFingerprint': requirements.requirementsFingerprint,
          'errorType': error.runtimeType.toString(),
        },
      );
    }

    if (intent.designPowerW > intent.availablePowerW) {
      return _blocked(
        'EQUIPMENT_SUPPLY_CAPACITY_EXCEEDED',
        P9FailureStage.catalog,
        {
          'designPowerW': intent.designPowerW,
          'availablePowerW': intent.availablePowerW,
        },
      );
    }

    final candidates = resolver.resolve(catalog);
    final decisions = <ApartmentEquipmentCandidateDecision>[];

    // Conductor selection precedes protection so the existing overcurrent
    // engine can prove Ib <= In <= Iz against the selected cable ampacity.
    final conductor = _selectSlot(
      slot: ApartmentEquipmentConfigurationSlot.conductor,
      candidates: candidates.where(
        (variant) => variant.kind == ApartmentEquipmentProductKind.cable,
      ),
      requirements: requirements,
      intent: intent,
      decisions: decisions,
    );
    if (conductor == null) {
      return _noCandidate(
        slot: ApartmentEquipmentConfigurationSlot.conductor,
        requirements: requirements,
        catalog: catalog,
        decisions: decisions,
      );
    }

    final protection = _selectSlot(
      slot: ApartmentEquipmentConfigurationSlot.protection,
      candidates: candidates.where(
        (variant) =>
            variant.kind == ApartmentEquipmentProductKind.circuitBreaker ||
            variant.kind == ApartmentEquipmentProductKind.rcbo,
      ),
      requirements: requirements,
      intent: intent,
      decisions: decisions,
      cableAmpacityA: conductor.ratings.currentCapacityA!,
    );
    if (protection == null) {
      return _noCandidate(
        slot: ApartmentEquipmentConfigurationSlot.protection,
        requirements: requirements,
        catalog: catalog,
        decisions: decisions,
      );
    }

    final requiredPanelModules = protection.ratings.moduleWidth!;
    final panel = _selectSlot(
      slot: ApartmentEquipmentConfigurationSlot.panel,
      candidates: candidates.where(
        (variant) =>
            variant.kind == ApartmentEquipmentProductKind.distributionBoard,
      ),
      requirements: requirements,
      intent: intent,
      decisions: decisions,
      requiredPanelModules: requiredPanelModules,
    );
    if (panel == null) {
      return _noCandidate(
        slot: ApartmentEquipmentConfigurationSlot.panel,
        requirements: requirements,
        catalog: catalog,
        decisions: decisions,
      );
    }

    return ApartmentEquipmentConfigurationResult(
      configuration: ApartmentEngineeringEquipmentConfiguration(
        requirementsFingerprint: requirements.requirementsFingerprint,
        catalogFingerprint: catalog.catalogFingerprint,
        intentFingerprint: intent.intentFingerprint,
        normativeProfileId: requirements.normativeProfileId,
        normativeProfileVersion: requirements.normativeProfileVersion,
        currencyCode: catalog.currencyCode,
        selectedVariants: {
          ApartmentEquipmentConfigurationSlot.protection: protection,
          ApartmentEquipmentConfigurationSlot.conductor: conductor,
          ApartmentEquipmentConfigurationSlot.panel: panel,
        },
        decisions: decisions,
      ),
    );
  }

  ApartmentVerifiedProductVariant? _selectSlot({
    required ApartmentEquipmentConfigurationSlot slot,
    required Iterable<ApartmentVerifiedProductVariant> candidates,
    required ApartmentEngineeringDesignRequirements requirements,
    required ApartmentEquipmentConfigurationIntent intent,
    required List<ApartmentEquipmentCandidateDecision> decisions,
    int requiredPanelModules = 1,
    double? cableAmpacityA,
  }) {
    final eligible = <ApartmentVerifiedProductVariant>[];
    final local = <String, ApartmentEquipmentCandidateDecision>{};

    for (final variant in candidates) {
      final engineering = feasibilityEvaluator.evaluate(
        variant: variant,
        intent: intent,
        requiredPanelModules: requiredPanelModules,
      );
      if (!engineering.feasible) {
        local[variant.variantId] = ApartmentEquipmentCandidateDecision(
          variant: variant,
          slot: slot,
          state: ApartmentEquipmentCandidateState.engineeringRejected,
          reasonCodes: engineering.rejectionCodes
              .map((code) => 'p9.equipment.reject.${code.name}'),
        );
        continue;
      }

      if (cableAmpacityA != null) {
        final overcurrentReasons = overcurrentEvaluator.rejectionReasonCodes(
          variant: variant,
          intent: intent,
          cableAmpacityA: cableAmpacityA,
        );
        if (overcurrentReasons.isNotEmpty) {
          local[variant.variantId] = ApartmentEquipmentCandidateDecision(
            variant: variant,
            slot: slot,
            state: ApartmentEquipmentCandidateState.engineeringRejected,
            reasonCodes: overcurrentReasons,
          );
          continue;
        }
      }

      final normative = normativeEvaluator.evaluate(
        variant: variant,
        normativeProfileId: requirements.normativeProfileId,
        normativeProfileVersion: requirements.normativeProfileVersion,
      );
      if (!normative.accepted) {
        local[variant.variantId] = ApartmentEquipmentCandidateDecision(
          variant: variant,
          slot: slot,
          state: ApartmentEquipmentCandidateState.normativeRejected,
          reasonCodes: const [
            'p9.equipment.reject.normativeProfileNotVerified',
          ],
        );
        continue;
      }
      eligible.add(variant);
    }

    final ranked = ranker.rank(
      slot: slot,
      variants: eligible,
      intent: intent,
      requiredPanelModules: requiredPanelModules,
    );
    for (final candidate in ranked) {
      local[candidate.variant.variantId] = ApartmentEquipmentCandidateDecision(
        variant: candidate.variant,
        slot: slot,
        state: candidate.rank == 1
            ? ApartmentEquipmentCandidateState.selected
            : ApartmentEquipmentCandidateState.alternative,
        rank: candidate.rank,
        reasonCodes: [
          candidate.rank == 1
              ? 'p9.equipment.selected.bestDeterministicRank'
              : 'p9.equipment.alternative.lowerDeterministicRank',
        ],
      );
    }

    decisions.addAll(
      local.values.toList()
        ..sort((left, right) =>
            left.variant.variantId.compareTo(right.variant.variantId)),
    );
    return ranked.isEmpty ? null : ranked.first.variant;
  }

  ApartmentEquipmentConfigurationResult _noCandidate({
    required ApartmentEquipmentConfigurationSlot slot,
    required ApartmentEngineeringDesignRequirements requirements,
    required ApartmentVerifiedProductVariantCatalog catalog,
    required List<ApartmentEquipmentCandidateDecision> decisions,
  }) =>
      ApartmentEquipmentConfigurationResult(
        configuration: null,
        failures: [
          P9Failure(
            code: 'EQUIPMENT_NO_ELIGIBLE_${slot.name.toUpperCase()}',
            stage: P9FailureStage.catalog,
            severity: P9FailureSeverity.blocker,
            facts: {
              'slot': slot.name,
              'requirementsFingerprint': requirements.requirementsFingerprint,
              'catalogFingerprint': catalog.catalogFingerprint,
              'rejections': {
                for (final decision
                    in decisions.where((decision) => decision.slot == slot))
                  decision.variant.variantId: decision.reasonCodes,
              },
            },
          ),
        ],
      );

  ApartmentEquipmentConfigurationResult _blocked(
    String code,
    P9FailureStage stage,
    Map<String, Object?> facts,
  ) =>
      ApartmentEquipmentConfigurationResult(
        configuration: null,
        failures: [
          P9Failure(
            code: code,
            stage: stage,
            severity: P9FailureSeverity.blocker,
            facts: facts,
          ),
        ],
      );
}
