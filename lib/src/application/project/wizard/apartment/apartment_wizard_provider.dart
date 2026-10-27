import 'dart:convert';

import '../../../../domain/apartment_topology.dart';
import '../../../../domain/apartment_topology/apartment_geometry.dart';
import '../../../../domain/apartment_topology/apartment_topology_models.dart';
import '../../../../domain/project_aggregate.dart';
import '../../../../domain/project_identity.dart';
import '../../project_mutation.dart';
import '../../project_mutation_reservation.dart';
import '../wizard_contracts.dart';
import 'apartment_candidate_identity.dart';
import 'apartment_candidate_set_service.dart';
import 'apartment_canonical_materializer.dart';
import 'apartment_engineering_pipeline.dart';
import 'apartment_generation_provenance_builder.dart';
import 'apartment_wizard_parameters.dart';
import 'p9_failure.dart';

final class ApartmentWizardProviderException implements Exception {
  const ApartmentWizardProviderException(this.code, [this.facts = const {}]);

  final String code;
  final Map<String, Object?> facts;

  @override
  String toString() => code;
}

/// Production P9 adapter into the shared P8 Wizard provider registry.
///
/// The provider is stateless and reentrant. Candidate exploration remains in
/// [ApartmentCandidateSetService] / session-owned exploration state. During P8
/// generation it deterministically resolves the exact transient selection,
/// verifies the P9.4 evidence bound to that candidate's exact P9.3 projection
/// and, when an engineering pipeline is configured, runs D1-D8 exactly once.
/// The accepted geometry and optional engineering proposal are frozen together
/// in one reserved P8 mutation command. Preview and Apply never rerun P9.
final class ApartmentWizardProvider
    extends TypedWizardProvider<ApartmentWizardParameters> {
  const ApartmentWizardProvider({
    this.candidateSetService = const ApartmentCandidateSetService(),
    this.materializer = const ApartmentCanonicalMaterializer(),
    this.provenanceBuilder = const ApartmentGenerationProvenanceBuilder(),
    this.engineeringPipeline,
  });

  static final WizardFamilyId familyId = WizardFamilyId('apartment');

  final ApartmentCandidateSetService candidateSetService;
  final ApartmentCanonicalMaterializer materializer;
  final ApartmentGenerationProvenanceBuilder provenanceBuilder;
  final ApartmentEngineeringPipeline? engineeringPipeline;

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

    final projection = selected.engineeringProjection;
    final normativeEvidence = selected.normativeEvidence;
    if (projection.selectedCandidateFingerprint !=
            selected.candidateFingerprint ||
        normativeEvidence.selectedCandidateFingerprint !=
            selected.candidateFingerprint ||
        normativeEvidence.projectionFingerprint !=
            projection.projectionFingerprint) {
      throw ApartmentWizardProviderException(
        'NORMATIVE_BLOCKED',
        {
          'reason': 'selected-candidate-normative-lineage-mismatch',
          'candidateFingerprint': selected.candidateFingerprint,
          'projectionFingerprint': projection.projectionFingerprint,
          'normativeProjectionFingerprint':
              normativeEvidence.projectionFingerprint,
        },
      );
    }
    if (normativeEvidence.blocksEligibility) {
      throw ApartmentWizardProviderException(
        'NORMATIVE_BLOCKED',
        {
          'candidateFingerprint': selected.candidateFingerprint,
          'projectionFingerprint': projection.projectionFingerprint,
          'normativeEvidenceFingerprint': normativeEvidence.evidenceFingerprint,
          'normativeState': normativeEvidence.overallState.name,
        },
      );
    }

    ApartmentEngineeringProposal? engineeringProposal;
    final pipeline = engineeringPipeline;
    if (pipeline != null) {
      try {
        engineeringProposal = pipeline.generate(
          candidateSetFingerprint: set.candidateSetFingerprint,
          selected: selected,
          context: context,
        );
        engineeringProposal.validateAgainst(
          candidateSetFingerprint: set.candidateSetFingerprint,
          selected: selected,
        );
      } on ArgumentError catch (error) {
        throw ApartmentWizardProviderException(
          'p9.provider.engineering-pipeline-invalid',
          {
            'candidateFingerprint': selected.candidateFingerprint,
            'reason': error.toString(),
          },
        );
      } on StateError catch (error) {
        throw ApartmentWizardProviderException(
          'p9.provider.engineering-pipeline-invalid',
          {
            'candidateFingerprint': selected.candidateFingerprint,
            'reason': error.toString(),
          },
        );
      }
    }

    return ApartmentReservedProjectCommand(
      target: target,
      descriptor: descriptor,
      candidateSetFingerprint: set.candidateSetFingerprint,
      candidateIdentity: selected.identity,
      selectedCandidate: selected.rankedCandidate.candidate,
      template: selected.template,
      engineeringProposal: engineeringProposal,
      materializer: materializer,
      provenanceBuilder: provenanceBuilder,
    );
  }
}

WizardValidationIssue _issue(String code) => WizardValidationIssue(
      code: code,
      message: code,
      severity: WizardIssueSeverity.blocker,
    );

/// Exact selected-candidate handoff into the shared P8 reserved mutation
/// lifecycle. Identity reservation and canonical candidate construction are
/// deterministic and pure; P8 owns version checks, frozen Preview, commit and
/// Undo/Redo.
final class ApartmentReservedProjectCommand implements ReservedProjectCommand {
  const ApartmentReservedProjectCommand({
    required this.target,
    required this.descriptor,
    required this.candidateSetFingerprint,
    required this.candidateIdentity,
    required this.selectedCandidate,
    required this.template,
    this.engineeringProposal,
    this.materializer = const ApartmentCanonicalMaterializer(),
    this.provenanceBuilder = const ApartmentGenerationProvenanceBuilder(),
  });

  final LevelWizardTarget target;
  final WizardProviderDescriptor descriptor;
  final String candidateSetFingerprint;
  final ApartmentCandidateIdentity candidateIdentity;
  final ApartmentGeometryCandidate selectedCandidate;
  final ApartmentTopologyTemplate template;
  final ApartmentEngineeringProposal? engineeringProposal;
  final ApartmentCanonicalMaterializer materializer;
  final ApartmentGenerationProvenanceBuilder provenanceBuilder;

  bool get hasEngineeringProposal => engineeringProposal != null;

  @override
  String get commandType => 'p9.apartment.materialize';

  @override
  String get normalizedIntentKey => jsonEncode({
        'command': commandType,
        'materializerVersion':
            ApartmentCanonicalMaterializer.materializerVersion,
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
        'engineeringProposalFingerprint':
            engineeringProposal?.proposalFingerprint,
        'engineeringOutputFingerprint':
            engineeringProposal?.output.outputFingerprint,
      });

  @override
  MutationIdentityReservation reserveIdentities(EntityIdFactory factory) =>
      materializer.reserveIdentities(
        factory: factory,
        candidate: selectedCandidate,
      );

  @override
  void validateReservation({
    required ProjectAggregateRoot current,
    required MutationIdentityReservation reservation,
  }) {
    materializer.validateReservation(
      current: current,
      target: target,
      candidate: selectedCandidate,
      reservation: reservation,
    );
  }

  @override
  ProjectCommandCandidate buildCandidate({
    required ProjectAggregateRoot current,
    required MutationIdentityReservation reservation,
  }) {
    final base = materializer.buildCandidate(
      current: current,
      target: target,
      candidate: selectedCandidate,
      template: template,
      reservation: reservation,
    );
    final baseState = base.resolveState(current);
    final materializedProject = ProjectAggregateRoot(
      id: current.id,
      siteId: current.siteId,
      version: current.version,
      engineeringMetadata: baseState.engineeringMetadata,
      stores: baseState.stores,
    );
    final provenance = provenanceBuilder.build(
      current: current.engineeringMetadata.generationProvenanceRegistry,
      materializedProject: materializedProject,
      target: target,
      candidate: selectedCandidate,
      reservation: reservation,
      input: ApartmentGenerationProvenanceInput(
        providerTemplateId: descriptor.templateId,
        providerTemplateVersion: descriptor.templateVersion,
        candidateIdentity: candidateIdentity,
        familyId: selectedCandidate.family.code,
      ),
    );
    return ProjectCommandCandidate.fromState(
      state: ProjectMutableState(
        engineeringMetadata: baseState.engineeringMetadata
            .withGenerationProvenanceRegistry(provenance),
        stores: baseState.stores,
      ),
      affectedEntityIds: base.affectedEntityIds,
    );
  }

  @override
  Iterable<ProjectSemanticOperation> semanticOperations({
    required ProjectAggregateRoot before,
    required ProjectAggregateRoot candidate,
    required MutationIdentityReservation reservation,
  }) sync* {
    materializer.validateReservation(
      current: before,
      target: target,
      candidate: selectedCandidate,
      reservation: reservation,
    );
    yield* materializer.semanticOperations(
      target: target,
      candidate: selectedCandidate,
      reservation: reservation,
    );
  }
}
