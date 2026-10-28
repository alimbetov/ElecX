import 'package:elecx/src/application/project/wizard/apartment/apartment_area_fitter.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_candidate_identity.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_candidate_ranker.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_catalog_filter.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_geometry_stage.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_preview_presentation.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_semantic_validator.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_topology_grammar.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_wizard_parameters.dart';
import 'package:elecx/src/domain/apartment_topology.dart';
import 'package:elecx/src/domain/apartment_topology/apartment_candidate_ranking.dart';
import 'package:elecx/src/domain/apartment_topology/apartment_topology_catalog_v4.dart';
import 'package:flutter_test/flutter_test.dart';

const _generatorVersion = 'p9.generator.v2';

void main() {
  late _PreparedIdentityFixture prepared;

  setUpAll(() {
    prepared = _prepareIdentityFixture(
      _request(roomCount: 3, areaDm2: 7800),
    );
    expect(prepared.inputs, isNotEmpty);
  });

  group('P9 candidate and candidate-set identity', () {
    test('same semantic inputs produce identical exact identities', () {
      final profile = _profile('p9.score.identity.v1');
      final first = _rank(prepared, profile);
      final second = _rank(prepared, profile);
      final firstSet = _identifySet(prepared, first, profile);
      final secondSet = _identifySet(prepared, second, profile);

      expect(
        secondSet.orderedCandidates
            .map((candidate) => candidate.candidateFingerprint)
            .toList(),
        firstSet.orderedCandidates
            .map((candidate) => candidate.candidateFingerprint)
            .toList(),
      );
      expect(
        secondSet.candidateSetFingerprint,
        firstSet.candidateSetFingerprint,
      );
    });

    test('scoring profile version changes identity, not geometry', () {
      final firstProfile = _profile('p9.score.identity.v1');
      final secondProfile = _profile('p9.score.identity.v2');
      final firstRanking = _rank(prepared, firstProfile);
      final secondRanking = _rank(prepared, secondProfile);
      final firstCandidate = firstRanking.rankedCandidates.first;
      final sameGeometry = secondRanking.rankedCandidates.firstWhere(
        (candidate) =>
            candidate.candidate.geometryFingerprint ==
            firstCandidate.candidate.geometryFingerprint,
      );
      const service = ApartmentCandidateIdentityService();
      final firstIdentity = service.identifyCandidate(
        request: prepared.request,
        rankedCandidate: firstCandidate,
        scoringProfile: firstProfile,
        catalogVersion: prepared.catalogVersion,
        generatorVersion: _generatorVersion,
      );
      final secondIdentity = service.identifyCandidate(
        request: prepared.request,
        rankedCandidate: sameGeometry,
        scoringProfile: secondProfile,
        catalogVersion: prepared.catalogVersion,
        generatorVersion: _generatorVersion,
      );

      expect(
        secondIdentity.geometryFingerprint,
        firstIdentity.geometryFingerprint,
      );
      expect(
        secondIdentity.candidateFingerprint,
        isNot(firstIdentity.candidateFingerprint),
      );
    });

    test('silent scoring weight change still changes exact identity', () {
      final firstProfile = _profile('p9.score.identity.v1');
      final changedWeights = Map<ApartmentScoreMetric, int>.of(
        firstProfile.weightBp,
      )
        ..update(
          ApartmentScoreMetric.interiorAreaMatch,
          (value) => value + 1,
        )
        ..update(
          ApartmentScoreMetric.circulationEfficiency,
          (value) => value - 1,
        );
      final secondProfile = ApartmentScoringProfile(
        scoringProfileVersion: firstProfile.scoringProfileVersion,
        weightBp: changedWeights,
        selectableFloorBp: 0,
        preferredCandidateCount: firstProfile.preferredCandidateCount,
        minimumUsefulCandidateCount: firstProfile.minimumUsefulCandidateCount,
        maximumCandidateCount: firstProfile.maximumCandidateCount,
      );
      final firstRanking = _rank(prepared, firstProfile);
      final secondRanking = _rank(prepared, secondProfile);
      final firstCandidate = firstRanking.rankedCandidates.first;
      final sameGeometry = secondRanking.rankedCandidates.firstWhere(
        (candidate) =>
            candidate.candidate.geometryFingerprint ==
            firstCandidate.candidate.geometryFingerprint,
      );
      const service = ApartmentCandidateIdentityService();
      final firstIdentity = service.identifyCandidate(
        request: prepared.request,
        rankedCandidate: firstCandidate,
        scoringProfile: firstProfile,
        catalogVersion: prepared.catalogVersion,
        generatorVersion: _generatorVersion,
      );
      final secondIdentity = service.identifyCandidate(
        request: prepared.request,
        rankedCandidate: sameGeometry,
        scoringProfile: secondProfile,
        catalogVersion: prepared.catalogVersion,
        generatorVersion: _generatorVersion,
      );

      expect(
        secondIdentity.geometryFingerprint,
        firstIdentity.geometryFingerprint,
      );
      expect(
        secondIdentity.candidateFingerprint,
        isNot(firstIdentity.candidateFingerprint),
      );
    });

    test('selection resolves only against exact candidate identity', () {
      final profile = _profile('p9.score.identity.v1');
      final ranking = _rank(prepared, profile);
      final identitySet = _identifySet(prepared, ranking, profile);
      final identity = identitySet.orderedCandidates.first;
      final selection = identity.toSelection();

      expect(identitySet.resolveSelection(selection), same(identity));
      expect(identitySet.containsSelection(selection), isTrue);

      final staleFingerprint = ApartmentCandidateSelection(
        candidateFingerprint: '${selection.candidateFingerprint}-stale',
        templateIdValue: selection.templateIdValue,
        templateVersion: selection.templateVersion,
        variantSeedId: selection.variantSeedId,
      );
      expect(identitySet.resolveSelection(staleFingerprint), isNull);

      final staleTemplateVersion = ApartmentCandidateSelection(
        candidateFingerprint: selection.candidateFingerprint,
        templateIdValue: selection.templateIdValue,
        templateVersion: selection.templateVersion + 1,
        variantSeedId: selection.variantSeedId,
      );
      expect(identitySet.resolveSelection(staleTemplateVersion), isNull);
    });

    test('semantic request change invalidates previous selection', () {
      final profile = _profile('p9.score.identity.v1');
      final ranking = _rank(prepared, profile);
      final previousSet = _identifySet(prepared, ranking, profile);
      final previousSelection =
          previousSet.orderedCandidates.first.toSelection();
      final changedRequest = const ApartmentRequestNormalizer()
          .normalize(_request(roomCount: 3, areaDm2: 7900))
          .request!;
      const service = ApartmentCandidateIdentityService();
      final changedIdentities = [
        for (final candidate in ranking.selectedCandidates)
          service.identifyCandidate(
            request: changedRequest,
            rankedCandidate: candidate,
            scoringProfile: profile,
            catalogVersion: prepared.catalogVersion,
            generatorVersion: _generatorVersion,
          ),
      ];
      final changedSet = service.identifySet(
        request: changedRequest,
        catalogVersion: prepared.catalogVersion,
        generatorVersion: _generatorVersion,
        scoringProfile: profile,
        diversityPolicyVersion: ApartmentCandidateRanker.diversityPolicyVersion,
        orderedCandidates: changedIdentities,
      );

      expect(
        changedSet.candidateSetFingerprint,
        isNot(previousSet.candidateSetFingerprint),
      );
      expect(changedSet.resolveSelection(previousSelection), isNull);
    });

    test('candidate set fingerprint is ordered but candidate identity is not',
        () {
      final profile = _profile('p9.score.identity.v1');
      final ranking = _rank(prepared, profile);
      final identitySet = _identifySet(prepared, ranking, profile);
      expect(identitySet.orderedCandidates.length, greaterThan(1));
      const service = ApartmentCandidateIdentityService();
      final reversed = service.identifySet(
        request: prepared.request,
        catalogVersion: prepared.catalogVersion,
        generatorVersion: _generatorVersion,
        scoringProfile: profile,
        diversityPolicyVersion: ApartmentCandidateRanker.diversityPolicyVersion,
        orderedCandidates: identitySet.orderedCandidates.reversed,
      );

      expect(
        reversed.candidateSetFingerprint,
        isNot(identitySet.candidateSetFingerprint),
      );
      expect(
        reversed.orderedCandidates.first.candidateFingerprint,
        identitySet.orderedCandidates.last.candidateFingerprint,
      );
    });

    test('responsive presentation state never changes candidate identity', () {
      final profile = _profile('p9.score.identity.v1');
      final ranking = _rank(prepared, profile);
      final identitySet = _identifySet(prepared, ranking, profile);
      final fingerprint =
          identitySet.orderedCandidates.first.candidateFingerprint;

      for (final width in <double>[390, 800, 1200, 1600]) {
        final policy = ApartmentPreviewLayoutPolicy.resolve(
          logicalWidth: width,
          textScaleFactor: width == 390 ? 2 : 1,
          animationsDisabled: width == 1200,
        );
        expect(policy.summaryVisible, isTrue);
        expect(
          identitySet.orderedCandidates.first.candidateFingerprint,
          fingerprint,
        );
      }
    });

    test('duplicate exact candidate identity is rejected fail closed', () {
      final profile = _profile('p9.score.identity.v1');
      final ranking = _rank(prepared, profile);
      final identitySet = _identifySet(prepared, ranking, profile);
      final duplicate = identitySet.orderedCandidates.first;
      const service = ApartmentCandidateIdentityService();

      expect(
        () => service.identifySet(
          request: prepared.request,
          catalogVersion: prepared.catalogVersion,
          generatorVersion: _generatorVersion,
          scoringProfile: profile,
          diversityPolicyVersion:
              ApartmentCandidateRanker.diversityPolicyVersion,
          orderedCandidates: [duplicate, duplicate],
        ),
        throwsArgumentError,
      );
    });
  });
}

final class _PreparedIdentityFixture {
  const _PreparedIdentityFixture({
    required this.request,
    required this.catalogVersion,
    required this.inputs,
  });

  final NormalizedApartmentRequest request;
  final int catalogVersion;
  final List<ApartmentCandidateRankingInput> inputs;
}

_PreparedIdentityFixture _prepareIdentityFixture(ApartmentRequestInput input) {
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

  return _PreparedIdentityFixture(
    request: request,
    catalogVersion: catalog.catalogVersion,
    inputs: inputs,
  );
}

ApartmentCandidateRankingResult _rank(
  _PreparedIdentityFixture prepared,
  ApartmentScoringProfile profile,
) =>
    const ApartmentCandidateRanker().rank(
      candidates: prepared.inputs,
      request: prepared.request,
      profile: profile,
    );

ApartmentCandidateSetIdentity _identifySet(
  _PreparedIdentityFixture prepared,
  ApartmentCandidateRankingResult ranking,
  ApartmentScoringProfile profile,
) {
  const service = ApartmentCandidateIdentityService();
  final identities = [
    for (final candidate in ranking.selectedCandidates)
      service.identifyCandidate(
        request: prepared.request,
        rankedCandidate: candidate,
        scoringProfile: profile,
        catalogVersion: prepared.catalogVersion,
        generatorVersion: _generatorVersion,
      ),
  ];
  return service.identifySet(
    request: prepared.request,
    catalogVersion: prepared.catalogVersion,
    generatorVersion: _generatorVersion,
    scoringProfile: profile,
    diversityPolicyVersion: ApartmentCandidateRanker.diversityPolicyVersion,
    orderedCandidates: identities,
  );
}

ApartmentScoringProfile _profile(String version) {
  final base = ApartmentScoringProfile.recommendedV1();
  return ApartmentScoringProfile(
    scoringProfileVersion: version,
    weightBp: base.weightBp,
    selectableFloorBp: 0,
    preferredCandidateCount: base.preferredCandidateCount,
    minimumUsefulCandidateCount: base.minimumUsefulCandidateCount,
    maximumCandidateCount: base.maximumCandidateCount,
  );
}

ApartmentRequestInput _request({
  required int roomCount,
  required int areaDm2,
}) =>
    ApartmentRequestInput(
      habitableRoomCount: roomCount,
      approximateAreaDm2: areaDm2,
      bathroomCount: 1,
      separateWcCount: 0,
      balconyCount: 0,
      balconyKind: ApartmentBalconyKind.none,
      kitchenMode: ApartmentKitchenMode.separate,
      corridorMode: ApartmentCorridorMode.auto,
      exteriorExposurePreference: ApartmentExteriorExposurePreference.any,
    );
