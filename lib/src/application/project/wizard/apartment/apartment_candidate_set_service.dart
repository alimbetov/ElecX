import '../../../../domain/apartment_topology/apartment_area_fit.dart';
import '../../../../domain/apartment_topology/apartment_candidate_ranking.dart';
import '../../../../domain/apartment_topology/apartment_geometry.dart';
import '../../../../domain/apartment_topology/apartment_topology_catalog_v4.dart';
import '../../../../domain/apartment_topology/apartment_topology_draft.dart';
import '../../../../domain/apartment_topology/apartment_topology_generation_runtime.dart';
import '../../../../domain/apartment_topology/apartment_topology_models.dart';
import '../../../../domain/apartment_topology/apartment_vector_scene.dart';
import '../../../../domain/project_aggregate.dart';
import '../wizard_contracts.dart';
import 'apartment_area_fitter.dart';
import 'apartment_candidate_identity.dart';
import 'apartment_candidate_ranker.dart';
import 'apartment_canonical_projection.dart';
import 'apartment_catalog_filter.dart';
import 'apartment_generation_diagnostics.dart';
import 'apartment_geometry_stage.dart';
import 'apartment_normative_evidence.dart';
import 'apartment_semantic_validator.dart';
import 'apartment_svg_projector.dart';
import 'apartment_topology_grammar.dart';
import 'apartment_topology_vector_renderer.dart';
import 'apartment_wizard_parameters.dart';
import 'p9_failure.dart';

const String apartmentGeneratorVersion = 'p9.generator.v3';

final class ApartmentCandidateCard {
  const ApartmentCandidateCard({
    required this.identity,
    required this.rankedCandidate,
    required this.template,
    required this.scene,
    required this.svg,
    required this.engineeringProjection,
    required this.normativeEvidence,
  });

  final ApartmentCandidateIdentity identity;
  final RankedApartmentCandidate rankedCandidate;
  final ApartmentTopologyTemplate template;
  final ApartmentTopologyVectorScene scene;
  final String svg;
  final ApartmentEngineeringProjection engineeringProjection;
  final ApartmentNormativeEvidenceBundle normativeEvidence;

  String get candidateFingerprint => identity.candidateFingerprint;

  ApartmentCandidateSelection toSelection({
    required String candidateSetFingerprint,
  }) =>
      identity.toSelection(
        candidateSetFingerprint: candidateSetFingerprint,
      );
}

final class ApartmentCandidateSet {
  ApartmentCandidateSet({
    required this.request,
    required this.catalogVersion,
    required this.generatorVersion,
    required this.scoringProfile,
    required this.identity,
    required this.recommendedCandidate,
    required this.engineeringProjection,
    required Iterable<ApartmentCandidateCard> candidates,
    required Iterable<P9Failure> rejectedSummary,
    this.diagnostics,
  })  : candidates = List.unmodifiable(candidates),
        rejectedSummary = List.unmodifiable(rejectedSummary) {
    final containsRecommended = this.candidates.any(
          (candidate) =>
              candidate.candidateFingerprint ==
              recommendedCandidate.candidateFingerprint,
        );
    if (!containsRecommended) {
      throw ArgumentError.value(
        recommendedCandidate.candidateFingerprint,
        'recommendedCandidate',
        'Recommended candidate must belong to the candidate set.',
      );
    }
    if (engineeringProjection.selectedCandidateFingerprint !=
            recommendedCandidate.candidateFingerprint ||
        engineeringProjection.projectionFingerprint !=
            recommendedCandidate.engineeringProjection.projectionFingerprint) {
      throw ArgumentError(
        'Engineering projection must belong to the recommended candidate.',
      );
    }
    for (final candidate in this.candidates) {
      if (candidate.engineeringProjection.selectedCandidateFingerprint !=
          candidate.candidateFingerprint) {
        throw ArgumentError(
          'Every preview candidate must own its exact P9.3 projection.',
        );
      }
      if (candidate.normativeEvidence.selectedCandidateFingerprint !=
              candidate.candidateFingerprint ||
          candidate.normativeEvidence.projectionFingerprint !=
              candidate.engineeringProjection.projectionFingerprint) {
        throw ArgumentError(
          'Every preview candidate must own normative evidence for its exact projection.',
        );
      }
    }
  }

  final NormalizedApartmentRequest request;
  final int catalogVersion;
  final String generatorVersion;
  final ApartmentScoringProfile scoringProfile;
  final ApartmentCandidateSetIdentity identity;
  final ApartmentCandidateCard recommendedCandidate;

  /// Backward-compatible P9.3 projection of [recommendedCandidate].
  final ApartmentEngineeringProjection engineeringProjection;
  final List<ApartmentCandidateCard> candidates;
  final List<P9Failure> rejectedSummary;
  final ApartmentGenerationDiagnosticReport? diagnostics;

  ApartmentNormativeEvidenceBundle get normativeEvidence =>
      recommendedCandidate.normativeEvidence;

  String get candidateSetFingerprint => identity.candidateSetFingerprint;

  ApartmentCandidateCard? resolveSelection(
    ApartmentCandidateSelection selection,
  ) {
    final selectedSetFingerprint = selection.candidateSetFingerprint;
    if (selectedSetFingerprint != null &&
        selectedSetFingerprint != candidateSetFingerprint) {
      return null;
    }
    for (final candidate in candidates) {
      if (candidate.identity.matchesSelection(selection)) {
        return candidate;
      }
    }
    return null;
  }

  ApartmentCandidateSelection selectionFor(ApartmentCandidateCard candidate) {
    for (final current in candidates) {
      if (current.candidateFingerprint == candidate.candidateFingerprint &&
          current.identity.matchesSelection(candidate.identity.toSelection())) {
        return current.toSelection(
          candidateSetFingerprint: candidateSetFingerprint,
        );
      }
    }
    throw ArgumentError.value(
      candidate.candidateFingerprint,
      'candidate',
      'Candidate does not belong to this candidate set.',
    );
  }
}

final class ApartmentCandidateSetGenerationResult {
  ApartmentCandidateSetGenerationResult({
    required this.candidateSet,
    required Iterable<P9Failure> failures,
    this.diagnostics,
  }) : failures = List.unmodifiable(failures);

  final ApartmentCandidateSet? candidateSet;
  final List<P9Failure> failures;
  final ApartmentGenerationDiagnosticReport? diagnostics;

  bool get hasBlockers => failures.any((failure) => failure.isBlocker);
  bool get accepted => candidateSet != null && !hasBlockers;
}

/// Stateless P9.9 exploration orchestrator.
///
/// It composes already-qualified P9.1..P9.8 stages. It allocates no canonical
/// project identity and never mutates [ProjectAggregateRoot]. P9.2 diagnostics
/// are captured from this authoritative execution; no second generation pass is
/// used to explain the result. P9.3 projection consumes the exact
/// draft/area-fit/geometry lineage from this same execution for every candidate
/// that may reach Preview. P9.4 then overlays immutable normative evidence onto
/// each exact P9.3 projection.
final class ApartmentCandidateSetService {
  const ApartmentCandidateSetService({
    this.generatorVersion = apartmentGeneratorVersion,
    this.normativeEvaluator = const ApartmentNormativeEvidenceEvaluator(),
  }) : assert(generatorVersion != '');

  final String generatorVersion;
  final ApartmentNormativeEvidencePort normativeEvaluator;

  ApartmentCandidateSetGenerationResult generate({
    required ApartmentRequestInput input,
    required LevelWizardTarget target,
    required ProjectAggregateRoot project,
    ApartmentScoringProfile? scoringProfile,
  }) {
    final failures = <P9Failure>[];
    failures.addAll(validateTarget(target: target, project: project));
    if (_hasBlockers(failures)) {
      return ApartmentCandidateSetGenerationResult(
        candidateSet: null,
        failures: failures,
      );
    }

    final normalization = const ApartmentRequestNormalizer().normalize(input);
    failures.addAll(normalization.failures);
    final request = normalization.request;
    if (request == null || _hasBlockers(failures)) {
      return ApartmentCandidateSetGenerationResult(
        candidateSet: null,
        failures: failures,
      );
    }

    final catalog = P9ApartmentTopologyCatalogV4.create();
    final templates = const ApartmentTopologyCatalogFilter()
        .compatibleTemplates(catalog, request);
    if (templates.isEmpty) {
      failures.add(
        _topologyFailure(ApartmentTopologyGenerationFailureCode.noCandidates),
      );
      failures.add(_providerFailure('p9.provider.no-candidates'));
      final diagnostics = ApartmentGenerationDiagnosticReport(
        catalogVersion: catalog.catalogVersion,
        intentFingerprint: request.intentFingerprint,
        generatorVersion: generatorVersion,
        grammarFailures: const [],
        globalFailures: failures,
        entries: const [],
      );
      return ApartmentCandidateSetGenerationResult(
        candidateSet: null,
        failures: failures,
        diagnostics: diagnostics,
      );
    }

    final expansion = ApartmentTopologyGrammarEngine().expand(
      request: request,
      templates: templates,
    );
    failures.addAll(expansion.failures);

    final rankingInputs = <ApartmentCandidateRankingInput>[];
    final productionLineages = <_ProductionCandidateLineage>[];
    final terminalDiagnostics = <ApartmentGenerationDiagnosticEntry>[];
    final diagnosticSeeds = <ApartmentGenerationDiagnosticSeed>[];

    for (final draft in expansion.drafts) {
      final template = _templateForDraft(
        templates,
        draft.templateId.value,
        draft.templateVersion,
      );
      if (template == null) {
        failures.add(
          _providerFailure(
            'p9.provider.no-candidates',
            facts: {'reason': 'template-lineage-missing'},
          ),
        );
        continue;
      }

      final fit = const ApartmentAreaFitter().fit(
        draft: draft,
        request: request,
      );
      failures.addAll(fit.failures);
      if (!fit.isValid) {
        final blockerCodes = fit.failures
            .where((failure) => failure.isBlocker)
            .map((failure) => failure.code);
        final warningCodes = fit.failures
            .where(
              (failure) => failure.severity == P9FailureSeverity.warning,
            )
            .map((failure) => failure.code);
        terminalDiagnostics.add(
          ApartmentGenerationDiagnosticEntry(
            templateId: template.templateId.value,
            templateVersion: template.templateVersion,
            family: template.family,
            variantSeedId: draft.variantSeedId,
            draftFingerprint: draft.draftFingerprint,
            stage: ApartmentGenerationDiagnosticStage.area,
            codes: fit.failures.map((failure) => failure.code),
            status: ApartmentCandidateDiagnosticStatus.rejected,
            blockerCodes: blockerCodes,
            warningCodes: warningCodes,
            rationaleCode: 'p9.diagnostics.rejected.area',
          ),
        );
        continue;
      }

      final fittedDraft = fit.fittedDraft!;
      final semantic = const ApartmentSemanticValidator().validate(
        fittedDraft: fittedDraft,
        request: request,
        template: template,
      );
      final semanticWarnings = semantic.preferenceMisses
          .map((miss) => 'p9.semantic.preference-miss:${miss.ruleId}');
      if (!semantic.accepted) {
        final blockerCodes = semantic.blockers.map((blocker) => blocker.code);
        terminalDiagnostics.add(
          ApartmentGenerationDiagnosticEntry(
            templateId: template.templateId.value,
            templateVersion: template.templateVersion,
            family: template.family,
            variantSeedId: draft.variantSeedId,
            draftFingerprint: draft.draftFingerprint,
            stage: ApartmentGenerationDiagnosticStage.semantic,
            codes: blockerCodes,
            status: ApartmentCandidateDiagnosticStatus.rejected,
            blockerCodes: blockerCodes,
            warningCodes: semanticWarnings,
            rationaleCode: 'p9.diagnostics.rejected.semantic',
          ),
        );
        for (final blocker in semantic.blockers) {
          failures.add(
            P9Failure(
              code: blocker.code,
              stage: P9FailureStage.semantics,
              severity: P9FailureSeverity.blocker,
              facts: {
                'ruleId': blocker.ruleId,
                ...blocker.facts,
                if (blocker.affectedKeys.isNotEmpty)
                  'affectedKeys': blocker.affectedKeys.join(','),
              },
            ),
          );
        }
        continue;
      }

      final geometry = const ApartmentGeometryStage().generate(
        fittedDraft: fittedDraft,
        semanticValidation: semantic,
        template: template,
        request: request,
      );
      failures.addAll(geometry.failures);
      if (!geometry.accepted) {
        final blockerCodes = <String>[
          ...geometry.failures
              .where((failure) => failure.isBlocker)
              .map((failure) => failure.code),
          ...?geometry.candidate?.validation.issues
              .where((issue) => issue.severity.name == 'blocker')
              .map((issue) => issue.code),
        ];
        final warningCodes = <String>[
          ...semanticWarnings,
          ...geometry.failures
              .where(
                (failure) => failure.severity == P9FailureSeverity.warning,
              )
              .map((failure) => failure.code),
        ];
        terminalDiagnostics.add(
          ApartmentGenerationDiagnosticEntry(
            templateId: template.templateId.value,
            templateVersion: template.templateVersion,
            family: template.family,
            variantSeedId: draft.variantSeedId,
            draftFingerprint: draft.draftFingerprint,
            stage: ApartmentGenerationDiagnosticStage.geometry,
            codes: [
              ...blockerCodes,
              ...warningCodes,
            ],
            status: ApartmentCandidateDiagnosticStatus.rejected,
            blockerCodes: blockerCodes,
            warningCodes: warningCodes,
            geometryFingerprint: geometry.candidate?.geometryFingerprint,
            rationaleCode: 'p9.diagnostics.rejected.geometry',
          ),
        );
        continue;
      }

      final candidate = geometry.candidate!;
      productionLineages.add(
        _ProductionCandidateLineage(
          draft: draft,
          fittedDraft: fittedDraft,
          geometry: candidate,
        ),
      );
      diagnosticSeeds.add(
        ApartmentGenerationDiagnosticSeed(
          templateId: template.templateId.value,
          templateVersion: template.templateVersion,
          family: template.family,
          variantSeedId: draft.variantSeedId,
          draftFingerprint: draft.draftFingerprint,
          geometryFingerprint: candidate.geometryFingerprint,
          areaFitFingerprint: candidate.areaFitFingerprint,
          warningCodes: [
            ...fit.failures
                .where(
                  (failure) => failure.severity == P9FailureSeverity.warning,
                )
                .map((failure) => failure.code),
            ...semanticWarnings,
            ...geometry.failures
                .where(
                  (failure) => failure.severity == P9FailureSeverity.warning,
                )
                .map((failure) => failure.code),
          ],
        ),
      );
      rankingInputs.add(
        ApartmentCandidateRankingInput(
          candidate: candidate,
          template: template,
        ),
      );
    }

    if (rankingInputs.isEmpty) {
      final code = expansion.drafts.isEmpty
          ? ApartmentTopologyGenerationFailureCode.noCandidates
          : ApartmentTopologyGenerationFailureCode.noValidTopologyCandidate;
      failures.add(
        _topologyFailure(
          code,
          facts: {
            'discoveredCandidateCount': expansion.drafts.length,
            'eligibleCandidateCount': 0,
          },
        ),
      );
      failures.add(_providerFailure('p9.provider.no-candidates'));
      final diagnostics = ApartmentGenerationDiagnosticReport(
        catalogVersion: catalog.catalogVersion,
        intentFingerprint: request.intentFingerprint,
        generatorVersion: generatorVersion,
        grammarFailures: expansion.failures,
        globalFailures: failures,
        entries: terminalDiagnostics,
      );
      return ApartmentCandidateSetGenerationResult(
        candidateSet: null,
        failures: failures,
        diagnostics: diagnostics,
      );
    }

    final profile = scoringProfile ?? ApartmentScoringProfile.recommendedV1();
    final ranking = const ApartmentCandidateRanker().rank(
      candidates: rankingInputs,
      request: request,
      profile: profile,
    );
    failures.addAll(ranking.failures);
    if (ranking.hasBlockers) {
      if (ranking.failures.any(
        (failure) => failure.code == 'p9.score.no-valid-candidates',
      )) {
        failures.add(
          _topologyFailure(
            ApartmentTopologyGenerationFailureCode.noValidTopologyCandidate,
            facts: {
              'discoveredCandidateCount': rankingInputs.length,
              'eligibleCandidateCount': 0,
            },
          ),
        );
      }
      final rankingBlockers = ranking.failures
          .where((failure) => failure.isBlocker)
          .map((failure) => failure.code)
          .toList();
      final diagnostics = ApartmentGenerationDiagnosticReport(
        catalogVersion: catalog.catalogVersion,
        intentFingerprint: request.intentFingerprint,
        generatorVersion: generatorVersion,
        grammarFailures: expansion.failures,
        globalFailures: failures,
        entries: [
          ...terminalDiagnostics,
          for (final seed in diagnosticSeeds)
            seed.toEntry(
              stage: ApartmentGenerationDiagnosticStage.scoring,
              status: ApartmentCandidateDiagnosticStatus.rejected,
              blockerCodes: rankingBlockers,
              rationaleCode: 'p9.diagnostics.rejected.scoring',
            ),
        ],
      );
      return ApartmentCandidateSetGenerationResult(
        candidateSet: null,
        failures: failures,
        diagnostics: diagnostics,
      );
    }

    late final ApartmentTopologyGenerationSelection generationSelection;
    try {
      generationSelection =
          const ApartmentTopologyGenerationRuntime().selectRankedCandidates(
        ranking.rankedCandidates,
        selectableFloorBp: profile.selectableFloorBp,
      );
    } on ApartmentTopologyGenerationFailure catch (error) {
      failures.add(
        _topologyFailure(
          error.code,
          facts: {
            'rankedCandidateCount': ranking.rankedCandidates.length,
            'eligibleCandidateCount': error.evaluations
                .where((evaluation) => evaluation.isEligible)
                .length,
          },
        ),
      );
      failures.add(_providerFailure('p9.provider.no-candidates'));
      final diagnostics =
          const ApartmentGenerationDiagnostics().fromProductionSelection(
        catalogVersion: catalog.catalogVersion,
        generatorVersion: generatorVersion,
        intentFingerprint: request.intentFingerprint,
        grammarFailures: expansion.failures,
        globalFailures: failures,
        terminalEntries: terminalDiagnostics,
        seeds: diagnosticSeeds,
        evaluations: error.evaluations,
      );
      return ApartmentCandidateSetGenerationResult(
        candidateSet: null,
        failures: failures,
        diagnostics: diagnostics,
      );
    }

    final winner = generationSelection.selectedCandidate;
    final winnerLineage = _lineageForRanked(productionLineages, winner);
    if (winnerLineage == null) {
      failures.add(
        P9Failure(
          code: 'INTERNAL_GENERATION_ERROR',
          stage: P9FailureStage.materialization,
          severity: P9FailureSeverity.blocker,
          facts: {
            'reason': 'selected-winner-lineage-missing',
            'geometryFingerprint': winner.candidate.geometryFingerprint,
          },
        ),
      );
      final diagnostics =
          const ApartmentGenerationDiagnostics().fromProductionSelection(
        catalogVersion: catalog.catalogVersion,
        generatorVersion: generatorVersion,
        intentFingerprint: request.intentFingerprint,
        grammarFailures: expansion.failures,
        globalFailures: failures,
        terminalEntries: terminalDiagnostics,
        seeds: diagnosticSeeds,
        evaluations: generationSelection.evaluations,
        selectedGeometryFingerprint: winner.candidate.geometryFingerprint,
      );
      return ApartmentCandidateSetGenerationResult(
        candidateSet: null,
        failures: failures,
        diagnostics: diagnostics,
      );
    }

    final rankedForRendering = <RankedApartmentCandidate>[winner];
    for (final ranked in ranking.selectedCandidates) {
      if (ranked.candidate.geometryFingerprint ==
          winner.candidate.geometryFingerprint) {
        continue;
      }
      if (rankedForRendering.length >= profile.maximumCandidateCount) {
        break;
      }
      rankedForRendering.add(ranked);
    }

    const identityService = ApartmentCandidateIdentityService();
    const renderer = ApartmentTopologyVectorRenderer();
    const svgProjector = ApartmentSvgProjector();
    const projectionService = ApartmentCanonicalProjectionService();
    final cards = <ApartmentCandidateCard>[];
    final candidateFingerprintsByGeometry = <String, String>{};
    ApartmentCandidateCard? recommendedCard;

    for (final ranked in rankedForRendering) {
      final template = _templateForRanked(templates, ranked);
      if (template == null) {
        failures.add(
          _providerFailure(
            'p9.provider.no-candidates',
            facts: {'reason': 'ranked-template-lineage-missing'},
          ),
        );
        continue;
      }
      final rendered = renderer.render(
        rankedCandidate: ranked,
        template: template,
      );
      failures.addAll(rendered.failures);
      if (!rendered.accepted) {
        continue;
      }
      final svg = svgProjector.project(rendered.scene!);
      failures.addAll(svg.failures);
      if (!svg.accepted) {
        continue;
      }
      final identity = identityService.identifyCandidate(
        request: request,
        rankedCandidate: ranked,
        scoringProfile: profile,
        catalogVersion: catalog.catalogVersion,
        generatorVersion: generatorVersion,
      );
      final lineage = _lineageForRanked(productionLineages, ranked);
      if (lineage == null) {
        final isWinner = ranked.candidate.geometryFingerprint ==
            winner.candidate.geometryFingerprint;
        failures.add(
          P9Failure(
            code: 'INTERNAL_GENERATION_ERROR',
            stage: P9FailureStage.materialization,
            severity: isWinner
                ? P9FailureSeverity.blocker
                : P9FailureSeverity.warning,
            facts: {
              'reason': isWinner
                  ? 'selected-winner-lineage-missing'
                  : 'alternative-candidate-lineage-missing',
              'geometryFingerprint': ranked.candidate.geometryFingerprint,
            },
          ),
        );
        continue;
      }
      final projectionResult = projectionService.project(
        selectedCandidateFingerprint: identity.candidateFingerprint,
        draft: lineage.draft,
        fittedDraft: lineage.fittedDraft,
        geometry: lineage.geometry,
        targetLevelId: target.levelId,
      );
      final engineeringProjection = projectionResult.projection;
      if (engineeringProjection == null || !projectionResult.accepted) {
        final isWinner = ranked.candidate.geometryFingerprint ==
            winner.candidate.geometryFingerprint;
        if (isWinner) {
          failures.addAll(projectionResult.failures);
        } else {
          failures.add(
            P9Failure(
              code: 'INTERNAL_GENERATION_ERROR',
              stage: P9FailureStage.materialization,
              severity: P9FailureSeverity.warning,
              facts: {
                'reason': 'alternative-candidate-projection-failed',
                'geometryFingerprint': ranked.candidate.geometryFingerprint,
              },
            ),
          );
        }
        continue;
      }
      final normativeResult = normativeEvaluator.evaluate(
        projection: engineeringProjection,
      );
      final normativeEvidence = normativeResult.evidence;
      if (normativeEvidence == null || !normativeResult.accepted) {
        final isWinner = ranked.candidate.geometryFingerprint ==
            winner.candidate.geometryFingerprint;
        if (isWinner) {
          failures.addAll(normativeResult.failures);
          if (!normativeResult.failures.any((failure) => failure.isBlocker)) {
            failures.add(
              P9Failure(
                code: 'NORMATIVE_BLOCKED',
                stage: P9FailureStage.normative,
                severity: P9FailureSeverity.blocker,
                facts: {
                  'candidateFingerprint': identity.candidateFingerprint,
                  'projectionFingerprint':
                      engineeringProjection.projectionFingerprint,
                  if (normativeEvidence != null)
                    'normativeEvidenceFingerprint':
                        normativeEvidence.evidenceFingerprint,
                  if (normativeEvidence != null)
                    'normativeState': normativeEvidence.overallState.name,
                },
              ),
            );
          }
        } else {
          failures.add(
            P9Failure(
              code: 'NORMATIVE_BLOCKED',
              stage: P9FailureStage.normative,
              severity: P9FailureSeverity.warning,
              facts: {
                'candidateFingerprint': identity.candidateFingerprint,
                'projectionFingerprint':
                    engineeringProjection.projectionFingerprint,
                'reason': 'alternative-candidate-not-eligible',
                if (normativeEvidence != null)
                  'normativeEvidenceFingerprint':
                      normativeEvidence.evidenceFingerprint,
                if (normativeEvidence != null)
                  'normativeState': normativeEvidence.overallState.name,
              },
            ),
          );
        }
        continue;
      }
      final card = ApartmentCandidateCard(
        identity: identity,
        rankedCandidate: ranked,
        template: template,
        scene: rendered.scene!,
        svg: svg.svg!,
        engineeringProjection: engineeringProjection,
        normativeEvidence: normativeEvidence,
      );
      cards.add(card);
      candidateFingerprintsByGeometry[ranked.candidate.geometryFingerprint] =
          identity.candidateFingerprint;
      if (ranked.candidate.geometryFingerprint ==
          winner.candidate.geometryFingerprint) {
        recommendedCard = card;
      }
    }

    final selectionDiagnostics =
        const ApartmentGenerationDiagnostics().fromProductionSelection(
      catalogVersion: catalog.catalogVersion,
      generatorVersion: generatorVersion,
      intentFingerprint: request.intentFingerprint,
      grammarFailures: expansion.failures,
      globalFailures: failures,
      terminalEntries: terminalDiagnostics,
      seeds: diagnosticSeeds,
      evaluations: generationSelection.evaluations,
      selectedGeometryFingerprint: winner.candidate.geometryFingerprint,
      candidateFingerprintsByGeometry: candidateFingerprintsByGeometry,
    );

    if (recommendedCard == null) {
      if (!failures.any((failure) => failure.isBlocker)) {
        failures.add(
          P9Failure(
            code: 'INTERNAL_GENERATION_ERROR',
            stage: P9FailureStage.rendering,
            severity: P9FailureSeverity.blocker,
            facts: {
              'reason': 'selected-winner-render-projection-or-normative-failed',
              'geometryFingerprint': winner.candidate.geometryFingerprint,
            },
          ),
        );
      }
      final failedDiagnostics =
          const ApartmentGenerationDiagnostics().fromProductionSelection(
        catalogVersion: catalog.catalogVersion,
        generatorVersion: generatorVersion,
        intentFingerprint: request.intentFingerprint,
        grammarFailures: expansion.failures,
        globalFailures: failures,
        terminalEntries: terminalDiagnostics,
        seeds: diagnosticSeeds,
        evaluations: generationSelection.evaluations,
        selectedGeometryFingerprint: winner.candidate.geometryFingerprint,
        candidateFingerprintsByGeometry: candidateFingerprintsByGeometry,
      );
      return ApartmentCandidateSetGenerationResult(
        candidateSet: null,
        failures: failures,
        diagnostics: failedDiagnostics,
      );
    }

    final diagnostics =
        selectionDiagnostics.withNormativeEvidence(recommendedCard.normativeEvidence);
    final engineeringProjection = recommendedCard.engineeringProjection;

    final setIdentity = identityService.identifySet(
      request: request,
      catalogVersion: catalog.catalogVersion,
      generatorVersion: generatorVersion,
      scoringProfile: profile,
      diversityPolicyVersion: ApartmentCandidateRanker.diversityPolicyVersion,
      orderedCandidates: cards.map((card) => card.identity),
    );

    final candidateSet = ApartmentCandidateSet(
      request: request,
      catalogVersion: catalog.catalogVersion,
      generatorVersion: generatorVersion,
      scoringProfile: profile,
      identity: setIdentity,
      recommendedCandidate: recommendedCard,
      engineeringProjection: engineeringProjection,
      candidates: cards,
      rejectedSummary: failures,
      diagnostics: diagnostics,
    );

    return ApartmentCandidateSetGenerationResult(
      candidateSet: candidateSet,
      failures: failures.where((failure) => !failure.isBlocker),
      diagnostics: diagnostics,
    );
  }

  List<P9Failure> validateTarget({
    required LevelWizardTarget target,
    required ProjectAggregateRoot project,
  }) {
    final failures = <P9Failure>[];
    if (project.id != target.projectId || project.siteId != target.siteId) {
      failures.add(
        _providerFailure(
          'p9.provider.target-missing',
          facts: {'reason': 'project-context-mismatch'},
        ),
      );
      return failures;
    }

    final level = project.stores.levels[target.levelId];
    if (level == null) {
      failures.add(_providerFailure('p9.provider.target-missing'));
      return failures;
    }
    if (level.buildingId != target.buildingId) {
      failures.add(
        _providerFailure('p9.provider.target-building-mismatch'),
      );
    }
    final building = project.stores.buildings[target.buildingId];
    if (building == null || !building.levelIds.contains(target.levelId)) {
      failures.add(
        _providerFailure('p9.provider.target-building-mismatch'),
      );
    }

    final hasSpaces = level.spaceIds.isNotEmpty ||
        project.stores.spaces.values
            .any((space) => space.levelId == target.levelId);
    final hasZones = level.zoneIds.isNotEmpty ||
        project.stores.zones.values
            .any((zone) => zone.levelId == target.levelId);
    if (hasSpaces || hasZones) {
      failures.add(
        _providerFailure(
          'p9.provider.target-not-empty',
          facts: {'hasSpaces': hasSpaces, 'hasStructuralZones': hasZones},
        ),
      );
    }
    return failures;
  }
}

final class _ProductionCandidateLineage {
  const _ProductionCandidateLineage({
    required this.draft,
    required this.fittedDraft,
    required this.geometry,
  });

  final ApartmentTopologyDraft draft;
  final AreaFittedTopologyDraft fittedDraft;
  final ApartmentGeometryCandidate geometry;
}

_ProductionCandidateLineage? _lineageForRanked(
  Iterable<_ProductionCandidateLineage> lineages,
  RankedApartmentCandidate ranked,
) {
  for (final lineage in lineages) {
    if (identical(lineage.geometry, ranked.candidate)) {
      return lineage;
    }
  }
  return null;
}

ApartmentTopologyTemplate? _templateForDraft(
  Iterable<ApartmentTopologyTemplate> templates,
  String templateId,
  int templateVersion,
) {
  for (final template in templates) {
    if (template.templateId.value == templateId &&
        template.templateVersion == templateVersion) {
      return template;
    }
  }
  return null;
}

ApartmentTopologyTemplate? _templateForRanked(
  Iterable<ApartmentTopologyTemplate> templates,
  RankedApartmentCandidate ranked,
) =>
    _templateForDraft(
      templates,
      ranked.candidate.templateId.value,
      ranked.candidate.templateVersion,
    );

bool _hasBlockers(Iterable<P9Failure> failures) =>
    failures.any((failure) => failure.isBlocker);

P9Failure _topologyFailure(
  ApartmentTopologyGenerationFailureCode code, {
  Map<String, Object?> facts = const {},
}) =>
    P9Failure(
      code: code.code,
      stage: P9FailureStage.scoring,
      severity: P9FailureSeverity.blocker,
      facts: facts,
    );

P9Failure _providerFailure(
  String code, {
  Map<String, Object?> facts = const {},
}) =>
    P9Failure(
      code: code,
      stage: P9FailureStage.provider,
      severity: P9FailureSeverity.blocker,
      facts: facts,
    );
