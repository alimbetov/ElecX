import 'package:elecx/src/application/project/wizard/apartment/apartment_area_fitter.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_candidate_ranker.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_catalog_filter.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_geometry_stage.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_semantic_validator.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_topology_grammar.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_wizard_parameters.dart';
import 'package:elecx/src/domain/apartment_topology.dart';
import 'package:elecx/src/domain/apartment_topology/apartment_candidate_ranking.dart';
import 'package:elecx/src/domain/apartment_topology/apartment_geometry.dart';
import 'package:elecx/src/domain/apartment_topology/apartment_topology_catalog_v4.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('P9.7-NFR-001 score + rank + diversify 64 candidates p99 <= 25 ms', () {
    final fixture = _rankingFixture();
    final candidates = <ApartmentCandidateRankingInput>[
      for (var index = 0; index < 64; index++)
        ApartmentCandidateRankingInput(
          candidate: _copyWithFingerprint(
            fixture.input.candidate,
            '${fixture.input.candidate.geometryFingerprint}-nfr-$index',
          ),
          template: fixture.input.template,
        ),
    ];
    final profile = ApartmentScoringProfile(
      scoringProfileVersion: 'p9.score.v1.nfr',
      weightBp: ApartmentScoringProfile.recommendedV1().weightBp,
      selectableFloorBp: 0,
    );
    const ranker = ApartmentCandidateRanker();

    for (var index = 0; index < 20; index++) {
      ranker.rank(
        candidates: candidates,
        request: fixture.request,
        profile: profile,
      );
    }

    final samplesUs = <int>[];
    for (var index = 0; index < 100; index++) {
      final stopwatch = Stopwatch()..start();
      final result = ranker.rank(
        candidates: candidates,
        request: fixture.request,
        profile: profile,
      );
      stopwatch.stop();
      expect(result.rankedCandidates, hasLength(64));
      samplesUs.add(stopwatch.elapsedMicroseconds);
    }
    samplesUs.sort();
    final p99Us = samplesUs[98];

    expect(
      p99Us,
      lessThanOrEqualTo(25000),
      reason: 'P9.7 64-candidate p99=${p99Us}us exceeds 25000us contract',
    );
  });
}

final class _RankingFixture {
  const _RankingFixture({required this.request, required this.input});

  final NormalizedApartmentRequest request;
  final ApartmentCandidateRankingInput input;
}

_RankingFixture _rankingFixture() {
  const raw = ApartmentRequestInput(
    habitableRoomCount: 3,
    approximateAreaDm2: 7800,
    bathroomCount: 1,
    separateWcCount: 0,
    balconyCount: 0,
    balconyKind: ApartmentBalconyKind.none,
    kitchenMode: ApartmentKitchenMode.separate,
    corridorMode: ApartmentCorridorMode.auto,
    exteriorExposurePreference: ApartmentExteriorExposurePreference.any,
  );
  final request = const ApartmentRequestNormalizer().normalize(raw).request!;
  final catalog = P9ApartmentTopologyCatalogV4.create();
  final templates = const ApartmentTopologyCatalogFilter()
      .compatibleTemplates(catalog, request);
  final expansion = ApartmentTopologyGrammarEngine().expand(
    request: request,
    templates: templates,
  );

  for (final draft in expansion.drafts) {
    final fitted = const ApartmentAreaFitter().fit(
      draft: draft,
      request: request,
    );
    if (!fitted.isValid) {
      continue;
    }
    final template = templates.firstWhere(
      (candidate) =>
          candidate.templateId == draft.templateId &&
          candidate.templateVersion == draft.templateVersion,
    );
    final semantic = const ApartmentSemanticValidator().validate(
      fittedDraft: fitted.fittedDraft!,
      request: request,
      template: template,
    );
    if (!semantic.accepted) {
      continue;
    }
    final geometry = const ApartmentGeometryStage().generate(
      fittedDraft: fitted.fittedDraft!,
      semanticValidation: semantic,
      template: template,
      request: request,
    );
    if (geometry.accepted) {
      return _RankingFixture(
        request: request,
        input: ApartmentCandidateRankingInput(
          candidate: geometry.candidate!,
          template: template,
        ),
      );
    }
  }
  throw StateError('P9.7 NFR fixture requires one accepted P9.6 candidate.');
}

ApartmentGeometryCandidate _copyWithFingerprint(
  ApartmentGeometryCandidate source,
  String geometryFingerprint,
) =>
    ApartmentGeometryCandidate(
      templateId: source.templateId,
      templateVersion: source.templateVersion,
      family: source.family,
      variantSeedId: source.variantSeedId,
      areaFitFingerprint: source.areaFitFingerprint,
      interiorEnvelope: source.interiorEnvelope,
      interiorSpaces: source.interiorSpaces,
      exteriorAppendages: source.exteriorAppendages,
      sharedBoundaries: source.sharedBoundaries,
      exteriorBoundaries: source.exteriorBoundaries,
      openingIntents: source.openingIntents,
      metrics: source.metrics,
      validation: source.validation,
      geometryAlgorithmVersion: source.geometryAlgorithmVersion,
      geometryFingerprint: geometryFingerprint,
    );
