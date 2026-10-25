import '../../../../domain/apartment_topology/apartment_candidate_ranking.dart';
import '../../../../domain/apartment_topology/apartment_topology_catalog_v4.dart';
import '../../../../domain/apartment_topology/apartment_topology_models.dart';
import '../../../../domain/apartment_topology/apartment_vector_scene.dart';
import '../../../../domain/project_aggregate.dart';
import '../wizard_contracts.dart';
import 'apartment_area_fitter.dart';
import 'apartment_candidate_identity.dart';
import 'apartment_candidate_ranker.dart';
import 'apartment_catalog_filter.dart';
import 'apartment_geometry_stage.dart';
import 'apartment_semantic_validator.dart';
import 'apartment_svg_projector.dart';
import 'apartment_topology_grammar.dart';
import 'apartment_topology_vector_renderer.dart';
import 'apartment_wizard_parameters.dart';
import 'p9_failure.dart';

final class ApartmentCandidateCard {
  const ApartmentCandidateCard({
    required this.identity,
    required this.rankedCandidate,
    required this.template,
    required this.scene,
    required this.svg,
  });

  final ApartmentCandidateIdentity identity;
  final RankedApartmentCandidate rankedCandidate;
  final ApartmentTopologyTemplate template;
  final ApartmentTopologyVectorScene scene;
  final String svg;

  String get candidateFingerprint => identity.candidateFingerprint;
}

final class ApartmentCandidateSet {
  ApartmentCandidateSet({
    required this.request,
    required this.catalogVersion,
    required this.generatorVersion,
    required this.scoringProfile,
    required this.identity,
    required Iterable<ApartmentCandidateCard> candidates,
    required Iterable<P9Failure> rejectedSummary,
  })  : candidates = List.unmodifiable(candidates),
        rejectedSummary = List.unmodifiable(rejectedSummary);

  final NormalizedApartmentRequest request;
  final int catalogVersion;
  final String generatorVersion;
  final ApartmentScoringProfile scoringProfile;
  final ApartmentCandidateSetIdentity identity;
  final List<ApartmentCandidateCard> candidates;
  final List<P9Failure> rejectedSummary;

  String get candidateSetFingerprint => identity.candidateSetFingerprint;

  ApartmentCandidateCard? resolveSelection(
    ApartmentCandidateSelection selection,
  ) {
    for (final candidate in candidates) {
      if (candidate.identity.matchesSelection(selection)) {
        return candidate;
      }
    }
    return null;
  }
}

final class ApartmentCandidateSetGenerationResult {
  ApartmentCandidateSetGenerationResult({
    required this.candidateSet,
    required Iterable<P9Failure> failures,
  }) : failures = List.unmodifiable(failures);

  final ApartmentCandidateSet? candidateSet;
  final List<P9Failure> failures;

  bool get hasBlockers => failures.any((failure) => failure.isBlocker);
  bool get accepted => candidateSet != null && !hasBlockers;
}

/// Stateless P9.9 exploration orchestrator.
///
/// It composes already-qualified P9.1..P9.8 stages. It allocates no canonical
/// project identity and never mutates [ProjectAggregateRoot].
final class ApartmentCandidateSetService {
  const ApartmentCandidateSetService({
    this.generatorVersion = 'p9.generator.v2',
  });

  final String generatorVersion;

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
      failures.add(_providerFailure('p9.provider.no-candidates'));
      return ApartmentCandidateSetGenerationResult(
        candidateSet: null,
        failures: failures,
      );
    }

    final expansion = ApartmentTopologyGrammarEngine().expand(
      request: request,
      templates: templates,
    );
    failures.addAll(expansion.failures);

    final rankingInputs = <ApartmentCandidateRankingInput>[];
    for (final draft in expansion.drafts) {
      final fit = const ApartmentAreaFitter().fit(
        draft: draft,
        request: request,
      );
      failures.addAll(fit.failures);
      if (!fit.isValid) {
        continue;
      }
      final template = _templateForDraft(
          templates, draft.templateId.value, draft.templateVersion);
      if (template == null) {
        failures.add(
          _providerFailure(
            'p9.provider.no-candidates',
            facts: {'reason': 'template-lineage-missing'},
          ),
        );
        continue;
      }

      final semantic = const ApartmentSemanticValidator().validate(
        fittedDraft: fit.fittedDraft!,
        request: request,
        template: template,
      );
      if (!semantic.accepted) {
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
        fittedDraft: fit.fittedDraft!,
        semanticValidation: semantic,
        template: template,
        request: request,
      );
      failures.addAll(geometry.failures);
      if (!geometry.accepted) {
        continue;
      }
      rankingInputs.add(
        ApartmentCandidateRankingInput(
          candidate: geometry.candidate!,
          template: template,
        ),
      );
    }

    if (rankingInputs.isEmpty) {
      failures.add(_providerFailure('p9.provider.no-candidates'));
      return ApartmentCandidateSetGenerationResult(
        candidateSet: null,
        failures: failures,
      );
    }

    final profile = scoringProfile ?? ApartmentScoringProfile.recommendedV1();
    final ranking = const ApartmentCandidateRanker().rank(
      candidates: rankingInputs,
      request: request,
      profile: profile,
    );
    failures.addAll(ranking.failures);
    if (ranking.hasBlockers || ranking.selectedCandidates.isEmpty) {
      if (!failures
          .any((failure) => failure.code == 'p9.provider.no-candidates')) {
        failures.add(_providerFailure('p9.provider.no-candidates'));
      }
      return ApartmentCandidateSetGenerationResult(
        candidateSet: null,
        failures: failures,
      );
    }

    const identityService = ApartmentCandidateIdentityService();
    const renderer = ApartmentTopologyVectorRenderer();
    const svgProjector = ApartmentSvgProjector();
    final cards = <ApartmentCandidateCard>[];

    for (final ranked in ranking.selectedCandidates) {
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
      cards.add(
        ApartmentCandidateCard(
          identity: identity,
          rankedCandidate: ranked,
          template: template,
          scene: rendered.scene!,
          svg: svg.svg!,
        ),
      );
    }

    if (cards.isEmpty) {
      failures.add(_providerFailure('p9.provider.no-candidates'));
      return ApartmentCandidateSetGenerationResult(
        candidateSet: null,
        failures: failures,
      );
    }

    final setIdentity = identityService.identifySet(
      request: request,
      catalogVersion: catalog.catalogVersion,
      generatorVersion: generatorVersion,
      scoringProfile: profile,
      diversityPolicyVersion: ApartmentCandidateRanker.diversityPolicyVersion,
      orderedCandidates: cards.map((card) => card.identity),
    );

    return ApartmentCandidateSetGenerationResult(
      candidateSet: ApartmentCandidateSet(
        request: request,
        catalogVersion: catalog.catalogVersion,
        generatorVersion: generatorVersion,
        scoringProfile: profile,
        identity: setIdentity,
        candidates: cards,
        rejectedSummary: failures,
      ),
      failures: failures.where((failure) => !failure.isBlocker),
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
