import 'dart:convert';

import '../../../../domain/apartment_topology/apartment_geometry.dart';
import '../../../../domain/apartment_topology/apartment_topology_models.dart';
import '../../../../domain/project_aggregate.dart';
import '../../../../domain/project_identity.dart';
import '../../project_mutation.dart';
import '../../project_mutation_reservation.dart';
import '../wizard_contracts.dart';
import 'apartment_candidate_identity.dart';
import 'apartment_candidate_set_service.dart';
import 'apartment_wizard_parameters.dart';
import 'p9_failure.dart';

final class ApartmentWizardProviderException implements Exception {
  const ApartmentWizardProviderException(this.code, [this.facts = const {}]);

  final String code;
  final Map<String, Object?> facts;

  @override
  String toString() => code;
}

/// Production P9.9 adapter into the shared P8 Wizard provider registry.
///
/// The provider is stateless and reentrant. Candidate exploration remains in
/// [ApartmentCandidateSetService] / session-owned exploration state. During P8
/// generate it deterministically regenerates the current candidate set and
/// resolves the exact transient selection; it never substitutes a new top card.
final class ApartmentWizardProvider
    extends TypedWizardProvider<ApartmentWizardParameters> {
  const ApartmentWizardProvider({
    this.candidateSetService = const ApartmentCandidateSetService(),
  });

  static final WizardFamilyId familyId = WizardFamilyId('apartment');

  final ApartmentCandidateSetService candidateSetService;

  @override
  WizardProviderDescriptor get descriptor => WizardProviderDescriptor(
        templateId: TemplateId('p9-apartment-provider'),
        templateVersion: 1,
        generatorVersion: candidateSetService.generatorVersion,
        familyId: familyId,
        displayName: 'wizard.family.apartment',
        supportedScopes: const {WizardTargetScope.level},
      );

  @override
  ApartmentWizardParameters typedDefaultsFor(WizardTargetContext target) =>
      const ApartmentWizardParameters(
        request: ApartmentRequestInput.productionDefaults,
      );

  @override
  WizardParameterValidation validateTypedParameters(
    ApartmentWizardParameters parameters,
    WizardTargetContext target,
  ) {
    final issues = <WizardValidationIssue>[];
    if (target is! LevelWizardTarget) {
      issues.add(_issue('p9.provider.unsupported-target'));
      return WizardParameterValidation(issues);
    }

    final normalization =
        const ApartmentRequestNormalizer().normalize(parameters.request);
    for (final failure in normalization.failures) {
      issues.add(_issue(failure.code));
    }
    final selection = parameters.selection;
    if (selection == null) {
      issues.add(_issue('p9.provider.selection-required'));
    } else if (selection.candidateSetFingerprint == null) {
      issues.add(_issue('p9.provider.candidate-set-stale'));
    }
    return WizardParameterValidation(issues);
  }

  @override
  ReservedProjectCommand generateTyped(
    ApartmentWizardParameters parameters,
    WizardGenerationContext context,
  ) {
    final target = context.target;
    if (target is! LevelWizardTarget) {
      throw const ApartmentWizardProviderException(
        'p9.provider.unsupported-target',
      );
    }

    final normalization =
        const ApartmentRequestNormalizer().normalize(parameters.request);
    if (!normalization.isValid) {
      final first = normalization.failures.firstWhere(
        (failure) => failure.isBlocker,
        orElse: () => P9Failure(
          code: 'p9.provider.no-candidates',
          stage: P9FailureStage.provider,
          severity: P9FailureSeverity.blocker,
        ),
      );
      throw ApartmentWizardProviderException(first.code, first.facts);
    }
    final selection = parameters.selection;
    if (selection == null) {
      throw const ApartmentWizardProviderException(
        'p9.provider.selection-required',
      );
    }
    final selectedSetFingerprint = selection.candidateSetFingerprint;
    if (selectedSetFingerprint == null) {
      throw const ApartmentWizardProviderException(
        'p9.provider.candidate-set-stale',
        {'reason': 'candidate-set-fingerprint-missing'},
      );
    }

    final result = candidateSetService.generate(
      input: parameters.request,
      target: target,
      project: context.project,
    );
    final set = result.candidateSet;
    if (set == null || !result.accepted) {
      final blocker = result.failures.where((failure) => failure.isBlocker);
      if (blocker.isNotEmpty) {
        final first = blocker.first;
        throw ApartmentWizardProviderException(first.code, first.facts);
      }
      throw const ApartmentWizardProviderException(
        'p9.provider.no-candidates',
      );
    }

    if (selectedSetFingerprint != set.candidateSetFingerprint) {
      throw ApartmentWizardProviderException(
        'p9.provider.candidate-set-stale',
        {
          'selectedCandidateSetFingerprint': selectedSetFingerprint,
          'currentCandidateSetFingerprint': set.candidateSetFingerprint,
        },
      );
    }

    final selected = set.resolveSelection(selection);
    if (selected == null) {
      final sameFingerprint = set.candidates.any(
        (candidate) =>
            candidate.candidateFingerprint == selection.candidateFingerprint,
      );
      throw ApartmentWizardProviderException(
        sameFingerprint
            ? 'p9.provider.selection-stale'
            : 'p9.provider.selection-not-found',
        {
          'candidateSetFingerprint': set.candidateSetFingerprint,
          'candidateFingerprint': selection.candidateFingerprint,
        },
      );
    }
    if (selected.identity.intentFingerprint !=
        normalization.request!.intentFingerprint) {
      throw const ApartmentWizardProviderException(
        'p9.provider.selection-stale',
      );
    }

    return ApartmentReservedProjectCommand(
      target: target,
      descriptor: descriptor,
      candidateSetFingerprint: set.candidateSetFingerprint,
      candidateIdentity: selected.identity,
      selectedCandidate: selected.rankedCandidate.candidate,
      template: selected.template,
    );
  }
}

WizardValidationIssue _issue(String code) => WizardValidationIssue(
      code: code,
      message: code,
      severity: WizardIssueSeverity.blocker,
    );

/// P9.9 exact-selection handoff into the reserved P8 command boundary.
///
/// This command deliberately carries only semantic candidate state. P9.10 adds
/// apartment-aware preview/diff projection and P9.11 replaces the neutral
/// candidate builder with canonical Zone/Space/Boundary materialization. Until
/// then this handoff is a safe no-op at the mutation layer: it allocates no IDs
/// and cannot mutate canonical state accidentally.
final class ApartmentReservedProjectCommand implements ReservedProjectCommand {
  const ApartmentReservedProjectCommand({
    required this.target,
    required this.descriptor,
    required this.candidateSetFingerprint,
    required this.candidateIdentity,
    required this.selectedCandidate,
    required this.template,
  });

  final LevelWizardTarget target;
  final WizardProviderDescriptor descriptor;
  final String candidateSetFingerprint;
  final ApartmentCandidateIdentity candidateIdentity;
  final ApartmentGeometryCandidate selectedCandidate;
  final ApartmentTopologyTemplate template;

  @override
  String get commandType => 'p9.apartment.prepare';

  @override
  String get normalizedIntentKey => jsonEncode({
        'command': commandType,
        'providerTemplateId': descriptor.templateId.value,
        'providerTemplateVersion': descriptor.templateVersion,
        'generatorVersion': descriptor.generatorVersion,
        'projectId': target.projectId.value,
        'siteId': target.siteId.value,
        'buildingId': target.buildingId.value,
        'levelId': target.levelId.value,
        'intentFingerprint': candidateIdentity.intentFingerprint,
        'candidateSetFingerprint': candidateSetFingerprint,
        'candidateFingerprint': candidateIdentity.candidateFingerprint,
        'templateId': candidateIdentity.templateIdValue,
        'templateVersion': candidateIdentity.templateVersion,
        'variantSeedId': candidateIdentity.variantSeedId,
        'geometryAlgorithmVersion': candidateIdentity.geometryAlgorithmVersion,
        'geometryFingerprint': candidateIdentity.geometryFingerprint,
        'scoringProfileVersion': candidateIdentity.scoringProfileVersion,
      });

  @override
  MutationIdentityReservation reserveIdentities(EntityIdFactory factory) =>
      MutationIdentityReservation.allocate(factory: factory);

  @override
  void validateReservation({
    required ProjectAggregateRoot current,
    required MutationIdentityReservation reservation,
  }) {
    _validateCurrentTarget(current);
    if (reservation.slots.isNotEmpty) {
      throw const ApartmentWizardProviderException(
        'p9.provider.candidate-set-stale',
        {'reason': 'unexpected-p9.9-reservation'},
      );
    }
  }

  @override
  ProjectCommandCandidate buildCandidate({
    required ProjectAggregateRoot current,
    required MutationIdentityReservation reservation,
  }) {
    validateReservation(current: current, reservation: reservation);
    return ProjectCommandCandidate.fromState(
      state: ProjectMutableState.fromProject(current),
      affectedEntityIds: const <EntityId>[],
    );
  }

  @override
  Iterable<ProjectSemanticOperation> semanticOperations({
    required ProjectAggregateRoot before,
    required ProjectAggregateRoot candidate,
    required MutationIdentityReservation reservation,
  }) sync* {
    _validateCurrentTarget(before);
  }

  void _validateCurrentTarget(ProjectAggregateRoot current) {
    if (current.id != target.projectId || current.siteId != target.siteId) {
      throw const ApartmentWizardProviderException(
        'p9.provider.target-missing',
      );
    }
    final level = current.stores.levels[target.levelId];
    if (level == null) {
      throw const ApartmentWizardProviderException(
        'p9.provider.target-missing',
      );
    }
    if (level.buildingId != target.buildingId) {
      throw const ApartmentWizardProviderException(
        'p9.provider.target-building-mismatch',
      );
    }
    final hasSpaces = level.spaceIds.isNotEmpty ||
        current.stores.spaces.values
            .any((space) => space.levelId == target.levelId);
    final hasZones = level.zoneIds.isNotEmpty ||
        current.stores.zones.values
            .any((zone) => zone.levelId == target.levelId);
    if (hasSpaces || hasZones) {
      throw const ApartmentWizardProviderException(
        'p9.provider.target-not-empty',
      );
    }
  }
}
