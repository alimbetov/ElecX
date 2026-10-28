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
  late _PreparedRanking base;

  setUpAll(() {
    base = _prepare(_request(roomCount: 3, areaDm2: 7800));
    expect(base.inputs, isNotEmpty);
  });

  group('P9.7 candidate scoring, ranking and diversity', () {
    test('P9.7-AT-001 weights sum to 10000', () {
      final profile = ApartmentScoringProfile.recommendedV1();
      expect(
        profile.weightBp.values.fold<int>(0, (sum, value) => sum + value),
        10000,
      );
      expect(
          profile.weightBp.keys.toSet(), ApartmentScoreMetric.values.toSet());
    });

    test('P9.7 profile defects fail closed with typed errors', () {
      final baseProfile = ApartmentScoringProfile.recommendedV1();
      final missing = Map<ApartmentScoreMetric, int>.of(baseProfile.weightBp)
        ..remove(ApartmentScoreMetric.privacySeparation);
      final missingResult = const ApartmentCandidateRanker().rank(
        candidates: base.inputs.take(1),
        request: base.request,
        profile: ApartmentScoringProfile(
          scoringProfileVersion: 'p9.score.invalid.missing',
          weightBp: missing,
        ),
      );
      expect(
        missingResult.failures.map((failure) => failure.code),
        contains('p9.score.missing-metric'),
      );
      expect(missingResult.hasBlockers, isTrue);

      final wrongSum = Map<ApartmentScoreMetric, int>.of(baseProfile.weightBp)
        ..update(
          ApartmentScoreMetric.interiorAreaMatch,
          (value) => value - 1,
        );
      final wrongSumResult = const ApartmentCandidateRanker().rank(
        candidates: base.inputs.take(1),
        request: base.request,
        profile: ApartmentScoringProfile(
          scoringProfileVersion: 'p9.score.invalid.sum',
          weightBp: wrongSum,
        ),
      );
      expect(
        wrongSumResult.failures.map((failure) => failure.code),
        contains('p9.score.weight-sum'),
      );
      expect(wrongSumResult.hasBlockers, isTrue);
    });

    test('P9.7-AT-002 invalid candidate cannot be scored selectable', () {
      final source = base.inputs.first;
      final invalid = ApartmentCandidateRankingInput(
        candidate: _copyCandidate(
          source.candidate,
          validation: GeometryValidationReport([
            GeometryValidationIssue(
              code: 'p9.geometry.test-blocker',
              severity: GeometryValidationSeverity.blocker,
            ),
          ]),
          geometryFingerprint:
              '${source.candidate.geometryFingerprint}-invalid',
        ),
        template: source.template,
      );

      final result = const ApartmentCandidateRanker().rank(
        candidates: [invalid],
        request: base.request,
      );

      expect(result.selectedCandidates, isEmpty);
      expect(result.rankedCandidates, isEmpty);
      expect(
        result.failures.map((failure) => failure.code),
        contains('p9.score.no-valid-candidates'),
      );
    });

    test('P9.7-AT-003 identical candidates deduplicate', () {
      final source = base.inputs.first;
      final result = const ApartmentCandidateRanker().rank(
        candidates: [source, source, source],
        request: base.request,
        profile: _profileWithFloor(0),
      );

      expect(result.rankedCandidates, hasLength(1));
      expect(result.availability.validCandidateCount, 3);
    });

    test('P9.7-AT-004 stable tie-break is independent of input order', () {
      final source = base.inputs.take(16).toList();
      final reversed = source.reversed.toList();
      final first = const ApartmentCandidateRanker().rank(
        candidates: source,
        request: base.request,
        profile: _profileWithFloor(0),
      );
      final second = const ApartmentCandidateRanker().rank(
        candidates: reversed,
        request: base.request,
        profile: _profileWithFloor(0),
      );

      expect(
        second.rankedCandidates
            .map((candidate) => candidate.candidate.geometryFingerprint)
            .toList(),
        first.rankedCandidates
            .map((candidate) => candidate.candidate.geometryFingerprint)
            .toList(),
      );
      expect(second.rankingFingerprint, first.rankingFingerprint);
    });

    test('P9.7-AT-005 preferred family influences valid candidates only', () {
      final families =
          base.inputs.map((input) => input.candidate.family).toSet();
      expect(families.length, greaterThan(1));
      final preferred = families.first;
      final prepared = _prepare(
        _request(
          roomCount: 3,
          areaDm2: 7800,
          preferredFamily: preferred,
        ),
      );
      final result = const ApartmentCandidateRanker().rank(
        candidates: prepared.inputs,
        request: prepared.request,
        profile: _profileWithFloor(0),
      );

      final matching = result.rankedCandidates
          .firstWhere((candidate) => candidate.candidate.family == preferred);
      final nonMatching = result.rankedCandidates
          .firstWhere((candidate) => candidate.candidate.family != preferred);
      expect(
        matching.breakdown
            .metricScoreBp[ApartmentScoreMetric.familyPreferenceMatch],
        10000,
      );
      expect(
        nonMatching.breakdown
            .metricScoreBp[ApartmentScoreMetric.familyPreferenceMatch],
        0,
      );
    });

    test('P9.7-AT-006 diversity exposes another family when floor permits', () {
      final result = const ApartmentCandidateRanker().rank(
        candidates: base.inputs,
        request: base.request,
        profile: _profileWithFloor(0),
      );

      expect(result.selectedCandidates, isNotEmpty);
      expect(
        result.selectedCandidates
            .map((candidate) => candidate.candidate.family)
            .toSet()
            .length,
        greaterThan(1),
      );
    });

    test('P9.7-AT-007 near-identical mirrors do not crowd out alternatives',
        () {
      final baseline = const ApartmentCandidateRanker().rank(
        candidates: base.inputs,
        request: base.request,
        profile: _profileWithFloor(0),
      );
      final firstRanked = baseline.rankedCandidates.first;
      final firstInput = base.inputs.firstWhere(
        (input) =>
            input.candidate.geometryFingerprint ==
            firstRanked.candidate.geometryFingerprint,
      );
      final alternativeRanked = baseline.rankedCandidates.firstWhere(
        (candidate) =>
            candidate.similaritySignature.nearDuplicateKey !=
            firstRanked.similaritySignature.nearDuplicateKey,
      );
      final alternativeInput = base.inputs.firstWhere(
        (input) =>
            input.candidate.geometryFingerprint ==
            alternativeRanked.candidate.geometryFingerprint,
      );
      final nearDuplicates = <ApartmentCandidateRankingInput>[
        for (var index = 0; index < 6; index++)
          ApartmentCandidateRankingInput(
            candidate: _copyCandidate(
              firstInput.candidate,
              geometryFingerprint:
                  '${firstInput.candidate.geometryFingerprint}-mirror-$index',
            ),
            template: firstInput.template,
          ),
      ];

      final result = const ApartmentCandidateRanker().rank(
        candidates: [...nearDuplicates, alternativeInput],
        request: base.request,
        profile: _profileWithFloor(0),
      );

      expect(
        result.selectedCandidates.any(
          (candidate) =>
              candidate.similaritySignature.nearDuplicateKey ==
              alternativeRanked.similaritySignature.nearDuplicateKey,
        ),
        isTrue,
      );
    });

    test('P9.7-AT-008 score breakdown recomputes final score', () {
      final result = const ApartmentCandidateRanker().rank(
        candidates: base.inputs.take(8),
        request: base.request,
        profile: _profileWithFloor(0),
      );

      for (final candidate in result.rankedCandidates) {
        final recomputed = candidate.breakdown.weightedContributionBp.values
            .fold<int>(0, (sum, value) => sum + value);
        expect(candidate.finalScoreBp, recomputed);
        for (final score in candidate.breakdown.metricScoreBp.values) {
          expect(score, inInclusiveRange(0, 10000));
        }
      }
    });

    test('P9.7-AT-009 repeated ranking yields identical selection fingerprint',
        () {
      final first = const ApartmentCandidateRanker().rank(
        candidates: base.inputs,
        request: base.request,
        profile: _profileWithFloor(0),
      );
      final second = const ApartmentCandidateRanker().rank(
        candidates: base.inputs,
        request: base.request,
        profile: _profileWithFloor(0),
      );

      expect(second.rankingFingerprint, first.rankingFingerprint);
      expect(
        second.selectedCandidates
            .map((candidate) => candidate.candidate.geometryFingerprint)
            .toList(),
        first.selectedCandidates
            .map((candidate) => candidate.candidate.geometryFingerprint)
            .toList(),
      );
    });

    test('P9.7-AT-010 quality floor may return fewer than 3', () {
      final source = base.inputs.first;
      final baseline = const ApartmentCandidateRanker().rank(
        candidates: [source],
        request: base.request,
        profile: _profileWithFloor(0),
      );
      final score = baseline.rankedCandidates.single.finalScoreBp;
      expect(score, lessThan(10000));

      final result = const ApartmentCandidateRanker().rank(
        candidates: [source],
        request: base.request,
        profile: _profileWithFloor(score + 1),
      );

      expect(result.selectedCandidates, isEmpty);
      expect(result.availability.qualifyingCandidateCount, 0);
      expect(result.availability.belowMinimumUseful, isTrue);
    });

    test('P9.7-AT-011 balcony area never contributes to interiorAreaMatch', () {
      final prepared = _prepare(
        _request(
          roomCount: 3,
          areaDm2: 7800,
          balconyCount: 1,
          balconyKind: ApartmentBalconyKind.balcony,
        ),
      );
      expect(prepared.inputs, isNotEmpty);
      final source = prepared.inputs.first;
      expect(source.candidate.exteriorAppendages, isNotEmpty);
      final mutated = ApartmentCandidateRankingInput(
        candidate: _copyCandidate(
          source.candidate,
          metrics: GeometryMetrics(
            interiorAreaMm2: source.candidate.metrics.interiorAreaMm2,
            appendageAreaMm2: source.candidate.metrics.appendageAreaMm2 * 50,
            maxAreaErrorMm2: source.candidate.metrics.maxAreaErrorMm2,
            sharedBoundaryLengthMm:
                source.candidate.metrics.sharedBoundaryLengthMm,
            exteriorExposureLengthMm:
                source.candidate.metrics.exteriorExposureLengthMm,
            wetCoreMaxSeparationMm:
                source.candidate.metrics.wetCoreMaxSeparationMm,
          ),
          geometryFingerprint:
              '${source.candidate.geometryFingerprint}-appendage-metric',
        ),
        template: source.template,
      );
      final original = const ApartmentCandidateRanker()
          .rank(
            candidates: [source],
            request: prepared.request,
            profile: _profileWithFloor(0),
          )
          .rankedCandidates
          .single;
      final changed = const ApartmentCandidateRanker()
          .rank(
            candidates: [mutated],
            request: prepared.request,
            profile: _profileWithFloor(0),
          )
          .rankedCandidates
          .single;

      expect(
        changed.breakdown.metricScoreBp[ApartmentScoreMetric.interiorAreaMatch],
        original
            .breakdown.metricScoreBp[ApartmentScoreMetric.interiorAreaMatch],
      );
    });

    test('P9.7-AT-012 exposure metric uses candidate-local pattern only', () {
      final source = base.inputs.first;
      expect(source.candidate.exteriorBoundaries, isNotEmpty);
      final firstBoundary = source.candidate.exteriorBoundaries.first;
      final oneSide = ApartmentCandidateRankingInput(
        candidate: _copyCandidate(
          source.candidate,
          exteriorBoundaries: [
            GeneratedExteriorBoundary(
              spaceSemanticKey: firstBoundary.spaceSemanticKey,
              side: GeometryEnvelopeSide.west,
              segment: firstBoundary.segment,
            ),
          ],
          geometryFingerprint:
              '${source.candidate.geometryFingerprint}-one-side',
        ),
        template: source.template,
      );
      final twoSides = ApartmentCandidateRankingInput(
        candidate: _copyCandidate(
          source.candidate,
          exteriorBoundaries: [
            GeneratedExteriorBoundary(
              spaceSemanticKey: firstBoundary.spaceSemanticKey,
              side: GeometryEnvelopeSide.west,
              segment: firstBoundary.segment,
            ),
            GeneratedExteriorBoundary(
              spaceSemanticKey: firstBoundary.spaceSemanticKey,
              side: GeometryEnvelopeSide.east,
              segment: firstBoundary.segment,
            ),
          ],
          geometryFingerprint:
              '${source.candidate.geometryFingerprint}-two-sides',
        ),
        template: source.template,
      );
      final request = const ApartmentRequestNormalizer()
          .normalize(
            _request(
              roomCount: 3,
              areaDm2: 7800,
              exposure: ApartmentExteriorExposurePreference.oneSide,
            ),
          )
          .request!;
      final result = const ApartmentCandidateRanker().rank(
        candidates: [oneSide, twoSides],
        request: request,
        profile: _profileWithFloor(0),
      );
      final byFingerprint = {
        for (final ranked in result.rankedCandidates)
          ranked.candidate.geometryFingerprint: ranked,
      };

      expect(
        byFingerprint[oneSide.candidate.geometryFingerprint]!
                .breakdown
                .metricScoreBp[
            ApartmentScoreMetric.exteriorExposurePreferenceMatch],
        10000,
      );
      expect(
        byFingerprint[twoSides.candidate.geometryFingerprint]!
                .breakdown
                .metricScoreBp[
            ApartmentScoreMetric.exteriorExposurePreferenceMatch],
        5000,
      );
    });
  });
}

final class _PreparedRanking {
  const _PreparedRanking({required this.request, required this.inputs});

  final NormalizedApartmentRequest request;
  final List<ApartmentCandidateRankingInput> inputs;
}

_PreparedRanking _prepare(ApartmentRequestInput input) {
  final request = const ApartmentRequestNormalizer().normalize(input).request!;
  final catalog = P9ApartmentTopologyCatalogV4.create();
  final templates = const ApartmentTopologyCatalogFilter()
      .compatibleTemplates(catalog, request);
  final expansion = ApartmentTopologyGrammarEngine().expand(
    request: request,
    templates: templates,
  );
  final inputs = <ApartmentCandidateRankingInput>[];

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
    if (!geometry.accepted) {
      continue;
    }
    inputs.add(
      ApartmentCandidateRankingInput(
        candidate: geometry.candidate!,
        template: template,
      ),
    );
  }
  return _PreparedRanking(request: request, inputs: inputs);
}

ApartmentScoringProfile _profileWithFloor(int floorBp) {
  final base = ApartmentScoringProfile.recommendedV1();
  return ApartmentScoringProfile(
    scoringProfileVersion: base.scoringProfileVersion,
    weightBp: base.weightBp,
    selectableFloorBp: floorBp,
    preferredCandidateCount: base.preferredCandidateCount,
    minimumUsefulCandidateCount: base.minimumUsefulCandidateCount,
    maximumCandidateCount: base.maximumCandidateCount,
  );
}

ApartmentGeometryCandidate _copyCandidate(
  ApartmentGeometryCandidate source, {
  GeometryValidationReport? validation,
  GeometryMetrics? metrics,
  Iterable<GeneratedExteriorBoundary>? exteriorBoundaries,
  String? geometryFingerprint,
}) =>
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
      exteriorBoundaries: exteriorBoundaries ?? source.exteriorBoundaries,
      openingIntents: source.openingIntents,
      metrics: metrics ?? source.metrics,
      validation: validation ?? source.validation,
      geometryAlgorithmVersion: source.geometryAlgorithmVersion,
      geometryFingerprint: geometryFingerprint ?? source.geometryFingerprint,
    );

ApartmentRequestInput _request({
  required int roomCount,
  required int areaDm2,
  int balconyCount = 0,
  ApartmentBalconyKind balconyKind = ApartmentBalconyKind.none,
  ApartmentExteriorExposurePreference exposure =
      ApartmentExteriorExposurePreference.any,
  ApartmentTopologyFamily? preferredFamily,
}) =>
    ApartmentRequestInput(
      habitableRoomCount: roomCount,
      approximateAreaDm2: areaDm2,
      bathroomCount: 1,
      separateWcCount: 0,
      balconyCount: balconyCount,
      balconyKind: balconyKind,
      kitchenMode: ApartmentKitchenMode.separate,
      corridorMode: ApartmentCorridorMode.auto,
      exteriorExposurePreference: exposure,
      preferredFamily: preferredFamily,
    );
