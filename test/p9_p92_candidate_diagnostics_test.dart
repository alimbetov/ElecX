import 'package:elecx/src/application/project/wizard/apartment/apartment_candidate_set_service.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_generation_diagnostics.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_wizard_parameters.dart';
import 'package:elecx/src/application/project/wizard/wizard_contracts.dart';
import 'package:elecx/src/domain/apartment_topology.dart';
import 'package:elecx/src/domain/apartment_topology/apartment_candidate_ranking.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P9.2 production candidate diagnostics', () {
    test('P9.2-Q01 production result explains the exact selected winner', () {
      final fixture = _projectFixture();
      final originalVersion = fixture.project.version;
      final originalStores = fixture.project.stores;
      final result = const ApartmentCandidateSetService().generate(
        input: _request(),
        target: fixture.target,
        project: fixture.project,
      );

      expect(result.accepted, isTrue);
      final set = result.candidateSet!;
      final diagnostics = result.diagnostics!;

      expect(set.diagnostics, same(diagnostics));
      expect(diagnostics.diagnosticsVersion, apartmentDiagnosticsVersion);
      expect(diagnostics.generatorVersion, apartmentGeneratorVersion);
      expect(diagnostics.selectedEntries, hasLength(1));

      final selected = diagnostics.selectedEntries.single;
      expect(selected.status, ApartmentCandidateDiagnosticStatus.selected);
      expect(selected.rank, 1);
      expect(
        selected.rationaleCode,
        'p9.diagnostics.selected.frozen-comparator',
      );
      expect(selected.blockerCodes, isEmpty);
      expect(
        selected.candidateFingerprint,
        set.recommendedCandidate.candidateFingerprint,
      );
      expect(
        selected.geometryFingerprint,
        set.recommendedCandidate.rankedCandidate.candidate.geometryFingerprint,
      );
      expect(
        selected.scoreBreakdown!.finalScoreBp,
        set.recommendedCandidate.rankedCandidate.finalScoreBp,
      );
      expect(
        selected.scoreBreakdown!.scoringProfileVersion,
        set.scoringProfile.scoringProfileVersion,
      );
      expect(
        selected.normativeState,
        ApartmentDiagnosticEvidenceState.notApplicable,
      );
      expect(
        selected.equipmentState,
        ApartmentDiagnosticEvidenceState.notEvaluated,
      );

      expect(fixture.project.version, same(originalVersion));
      expect(fixture.project.stores, same(originalStores));
    });

    test('P9.2-Q02 repeated generation has identical diagnostics fingerprint',
        () {
      final fixture = _projectFixture();
      const service = ApartmentCandidateSetService();

      final first = service.generate(
        input: _request(),
        target: fixture.target,
        project: fixture.project,
      );
      final second = service.generate(
        input: _request(),
        target: fixture.target,
        project: fixture.project,
      );

      expect(first.accepted, isTrue);
      expect(second.accepted, isTrue);
      expect(
        second.diagnostics!.diagnosticsFingerprint,
        first.diagnostics!.diagnosticsFingerprint,
      );
      expect(
        second.diagnostics!.stableSummary,
        first.diagnostics!.stableSummary,
      );
      expect(
        second.diagnostics!.selectedEntries.single.candidateFingerprint,
        first.diagnostics!.selectedEntries.single.candidateFingerprint,
      );
    });

    test('P9.2-Q03 selected and rejected states are mutually exclusive', () {
      final fixture = _projectFixture();
      final result = const ApartmentCandidateSetService().generate(
        input: _request(),
        target: fixture.target,
        project: fixture.project,
      );
      final diagnostics = result.diagnostics!;

      for (final entry in diagnostics.entries) {
        if (entry.selected) {
          expect(entry.rejected, isFalse);
          expect(entry.blockerCodes, isEmpty);
        }
        if (entry.rejected) {
          expect(entry.selected, isFalse);
          expect(entry.rationaleCode, isNotNull);
        }
      }
    });

    test('P9.2-Q04 score explanation is deterministic and metric based', () {
      final fixture = _projectFixture();
      final result = const ApartmentCandidateSetService().generate(
        input: _request(),
        target: fixture.target,
        project: fixture.project,
      );
      final selected = result.diagnostics!.selectedEntries.single;
      final score = selected.scoreBreakdown!;

      expect(
        score.metricScoreBp.keys.toSet(),
        ApartmentScoreMetric.values.toSet(),
      );
      expect(
        score.weightedContributionBp.keys.toSet(),
        ApartmentScoreMetric.values.toSet(),
      );
      expect(score.finalScoreBp, inInclusiveRange(0, 10000));
      expect(result.diagnostics!.stableSummary, contains('scoreBp='));
      expect(result.diagnostics!.stableSummary, contains('metrics='));
    });

    test('P9.2-Q05 report collections and code ordering are immutable', () {
      final entry = ApartmentGenerationDiagnosticEntry(
        templateId: 'tpl',
        templateVersion: 1,
        family: ApartmentTopologyFamily.compact,
        variantSeedId: 'seed',
        draftFingerprint: 'draft',
        stage: ApartmentGenerationDiagnosticStage.semantic,
        codes: const ['z', 'a', 'a'],
        blockerCodes: const ['z.blocker', 'a.blocker', 'z.blocker'],
        warningCodes: const ['z.warning', 'a.warning', 'z.warning'],
        rationaleCode: 'p9.diagnostics.rejected.semantic',
      );

      expect(entry.codes, ['a', 'z']);
      expect(entry.blockerCodes, ['a.blocker', 'z.blocker']);
      expect(entry.warningCodes, ['a.warning', 'z.warning']);
      expect(() => entry.blockerCodes.add('x'), throwsUnsupportedError);
      expect(() => entry.warningCodes.clear(), throwsUnsupportedError);
    });

    test('P9.2-Q06 no valid candidate retains candidate diagnostics', () {
      final fixture = _projectFixture();
      final base = ApartmentScoringProfile.recommendedV1();
      final strict = ApartmentScoringProfile(
        scoringProfileVersion: 'p9.score.p92-strict',
        weightBp: base.weightBp,
        selectableFloorBp: 10000,
        minimumUsefulCandidateCount: base.minimumUsefulCandidateCount,
        preferredCandidateCount: base.preferredCandidateCount,
        maximumCandidateCount: base.maximumCandidateCount,
      );

      final result = const ApartmentCandidateSetService().generate(
        input: _request(),
        target: fixture.target,
        project: fixture.project,
        scoringProfile: strict,
      );

      expect(result.accepted, isFalse);
      expect(result.candidateSet, isNull);
      expect(
        result.failures.map((failure) => failure.code),
        contains('NO_VALID_TOPOLOGY_CANDIDATE'),
      );
      final diagnostics = result.diagnostics!;
      expect(diagnostics.entries, isNotEmpty);
      expect(diagnostics.selectedEntries, isEmpty);
      expect(diagnostics.rejectedEntries, isNotEmpty);
      expect(
        diagnostics.rejectedEntries
            .expand((entry) => entry.blockerCodes)
            .toSet(),
        contains('p9.score.below-selectable-floor'),
      );
      expect(
        diagnostics.rejectedEntries
            .where((entry) => entry.scoreBreakdown != null),
        isNotEmpty,
      );
    });
  });
}

ApartmentRequestInput _request() => const ApartmentRequestInput(
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

final class _ProjectFixture {
  const _ProjectFixture({
    required this.project,
    required this.target,
  });

  final ProjectAggregateRoot project;
  final LevelWizardTarget target;
}

_ProjectFixture _projectFixture() {
  final projectId = ProjectId('p92-diagnostics-project');
  final siteId = SiteId('p92-diagnostics-site');
  final buildingId = BuildingId('p92-diagnostics-building');
  final levelId = LevelId('p92-diagnostics-level');
  final version = LocalProjectVersion(7);

  final stores = ProjectEntityStores(
    sites: {
      siteId: ProjectSiteEntity(
        id: siteId,
        name: 'Site',
        buildingIds: {buildingId},
      ),
    },
    buildings: {
      buildingId: ProjectBuildingEntity(
        id: buildingId,
        siteId: siteId,
        name: 'Building',
        levelIds: {levelId},
      ),
    },
    levels: {
      levelId: ProjectLevelEntity(
        id: levelId,
        buildingId: buildingId,
        name: 'Level 1',
        levelNumber: 1,
        elevationMm: 3000,
        kind: ProjectLevelKind.residential,
      ),
    },
  );
  final project = ProjectAggregateRoot(
    id: projectId,
    siteId: siteId,
    version: version,
    stores: stores,
  );

  return _ProjectFixture(
    project: project,
    target: LevelWizardTarget(
      projectId: projectId,
      siteId: siteId,
      baseVersion: version,
      buildingId: buildingId,
      levelId: levelId,
    ),
  );
}
