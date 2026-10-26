import 'package:elecx/src/domain/apartment_topology.dart';
import 'package:elecx/src/domain/apartment_topology/apartment_candidate_ranking.dart';
import 'package:elecx/src/domain/apartment_topology/apartment_geometry.dart';
import 'package:elecx/src/domain/apartment_topology/apartment_topology_generation_runtime.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const runtime = ApartmentTopologyGenerationRuntime();

  group('P9.1 frozen deterministic selection contract', () {
    test('Q01 same input selects the same winner', () {
      final candidates = [
        _evaluation(templateId: 'tpl-b', scoreBp: 8700, stableOrder: 20),
        _evaluation(templateId: 'tpl-a', scoreBp: 9100, stableOrder: 10),
      ];

      final first = runtime.select(candidates);
      final second = runtime.select(candidates);

      expect(first.selectedCandidate.candidate.templateId.value, 'tpl-a');
      expect(
        second.selectedCandidate.candidate.templateId.value,
        first.selectedCandidate.candidate.templateId.value,
      );
    });

    test('Q02 shuffled candidates select the same winner', () {
      final first = _evaluation(
        templateId: 'tpl-a',
        scoreBp: 9000,
        stableOrder: 10,
      );
      final second = _evaluation(
        templateId: 'tpl-b',
        scoreBp: 8800,
        stableOrder: 20,
      );
      final third = _evaluation(
        templateId: 'tpl-c',
        scoreBp: 8700,
        stableOrder: 30,
      );

      final forward = runtime.select([first, second, third]);
      final shuffled = runtime.select([third, first, second]);

      expect(forward.selectedCandidate.candidate.templateId.value, 'tpl-a');
      expect(
        shuffled.selectedCandidate.candidate.templateId.value,
        forward.selectedCandidate.candidate.templateId.value,
      );
    });

    test('Q03 invalid candidate is rejected', () {
      final valid = _evaluation(
        templateId: 'tpl-valid',
        scoreBp: 7000,
        stableOrder: 20,
      );
      final invalid = _evaluation(
        templateId: 'tpl-invalid',
        scoreBp: 6500,
        stableOrder: 10,
        geometryAccepted: false,
      );

      final result = runtime.select([invalid, valid]);

      expect(result.selectedCandidate.candidate.templateId.value, 'tpl-valid');
      expect(result.rejected, hasLength(1));
      expect(
        result.rejected.single.rankedCandidate.candidate.templateId.value,
        'tpl-invalid',
      );
      expect(
          result.rejected.single.blockerCodes, contains('p9.geometry.blocked'));
    });

    test('Q04 invalid higher-score candidate never wins', () {
      final invalidHighScore = _evaluation(
        templateId: 'tpl-invalid-high',
        scoreBp: 9999,
        stableOrder: 1,
        blockerCodes: const ['p9.normative.blocked'],
      );
      final validLowerScore = _evaluation(
        templateId: 'tpl-valid-lower',
        scoreBp: 5000,
        stableOrder: 99,
      );

      final result = runtime.select([invalidHighScore, validLowerScore]);

      expect(
        result.selectedCandidate.candidate.templateId.value,
        'tpl-valid-lower',
      );
      expect(result.rejected.single.blockerCodes, ['p9.normative.blocked']);
    });

    test('Q05 equal score uses stable deterministic tie-breaks', () {
      final highStableOrder = _evaluation(
        templateId: 'tpl-a',
        scoreBp: 8000,
        stableOrder: 20,
      );
      final lowStableOrder = _evaluation(
        templateId: 'tpl-z',
        scoreBp: 8000,
        stableOrder: 10,
      );
      expect(
        runtime
            .select([highStableOrder, lowStableOrder])
            .selectedCandidate
            .candidate
            .templateId
            .value,
        'tpl-z',
      );

      final identityB = _evaluation(
        templateId: 'tpl-b',
        scoreBp: 8000,
        stableOrder: 10,
      );
      final identityA = _evaluation(
        templateId: 'tpl-a',
        scoreBp: 8000,
        stableOrder: 10,
      );
      expect(
        runtime
            .select([identityB, identityA])
            .selectedCandidate
            .candidate
            .templateId
            .value,
        'tpl-a',
      );

      final version2 = _evaluation(
        templateId: 'tpl-versioned',
        templateVersion: 2,
        scoreBp: 8000,
        stableOrder: 10,
      );
      final version1 = _evaluation(
        templateId: 'tpl-versioned',
        templateVersion: 1,
        scoreBp: 8000,
        stableOrder: 10,
      );
      expect(
        runtime
            .select([version2, version1])
            .selectedCandidate
            .candidate
            .templateVersion,
        1,
      );
    });

    test('Q06 no valid candidates fails explicitly', () {
      final invalidA = _evaluation(
        templateId: 'tpl-invalid-a',
        scoreBp: 9000,
        stableOrder: 10,
        blockerCodes: const ['p9.semantic.blocked'],
      );
      final invalidB = _evaluation(
        templateId: 'tpl-invalid-b',
        scoreBp: 8000,
        stableOrder: 20,
        geometryAccepted: false,
      );

      expect(
        () => runtime.select([invalidA, invalidB]),
        throwsA(
          isA<ApartmentTopologyGenerationFailure>().having(
            (failure) => failure.code,
            'code',
            ApartmentTopologyGenerationFailureCode.noValidTopologyCandidate,
          ),
        ),
      );
    });
  });
}

ApartmentTopologyCandidateEvaluation _evaluation({
  required String templateId,
  required int scoreBp,
  required int stableOrder,
  int templateVersion = 1,
  int familyStableOrder = 0,
  int variantSeedStableOrder = 0,
  bool geometryAccepted = true,
  Iterable<String> blockerCodes = const [],
}) {
  final family = ApartmentTopologyFamily.compact;
  final candidate = ApartmentGeometryCandidate(
    templateId: TemplateId(templateId),
    templateVersion: templateVersion,
    family: family,
    variantSeedId: 'seed-$variantSeedStableOrder',
    areaFitFingerprint: 'area-$templateId-$templateVersion',
    interiorEnvelope: RectilinearPolygonMm.rectangle(
      xMm: 0,
      yMm: 0,
      widthMm: 4000,
      heightMm: 4000,
    ),
    interiorSpaces: const [],
    exteriorAppendages: const [],
    sharedBoundaries: const [],
    exteriorBoundaries: const [],
    openingIntents: const [],
    metrics: const GeometryMetrics(
      interiorAreaMm2: 16000000,
      appendageAreaMm2: 0,
      maxAreaErrorMm2: 0,
      sharedBoundaryLengthMm: 0,
      exteriorExposureLengthMm: 16000,
      wetCoreMaxSeparationMm: 0,
    ),
    validation: GeometryValidationReport(
      geometryAccepted
          ? const []
          : [
              GeometryValidationIssue(
                code: 'p9.geometry.blocked',
                severity: GeometryValidationSeverity.blocker,
              ),
            ],
    ),
    geometryAlgorithmVersion: 'p9.geometry.test',
    geometryFingerprint: 'geometry-$templateId-$templateVersion',
  );

  return ApartmentTopologyCandidateEvaluation.failClosed(
    rankedCandidate: RankedApartmentCandidate(
      candidate: candidate,
      breakdown: ApartmentScoreBreakdown(
        scoringProfileVersion: 'p9.score.test',
        metricScoreBp: const {},
        weightedContributionBp: const {},
        finalScoreBp: scoreBp,
      ),
      similaritySignature: CandidateSimilaritySignature(
        family: family,
        templateIdValue: templateId,
        adjacencyGraphClass: 'test',
        wetCoreGrouping: 'test',
        entryOrientation: 'test',
        exteriorExposurePattern: 'test',
        mirrored: false,
      ),
      familyStableOrder: familyStableOrder,
      templateStableOrder: stableOrder,
      variantSeedStableOrder: variantSeedStableOrder,
    ),
    blockerCodes: blockerCodes,
  );
}
