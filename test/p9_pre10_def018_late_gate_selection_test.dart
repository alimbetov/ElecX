import 'package:elecx/src/application/project/wizard/apartment/apartment_candidate_set_service.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_canonical_projection.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_normative_evidence.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_wizard_parameters.dart';
import 'package:elecx/src/application/project/wizard/apartment/p9_failure.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PRE10-CQ18 late production eligibility selection', () {
    test('promotes the next qualified candidate when the rank winner is blocked',
        () {
      final fixture = _projectFixture();
      final baseline = const ApartmentCandidateSetService().generate(
        input: _request(),
        target: fixture.target,
        project: fixture.project,
      );

      expect(baseline.accepted, isTrue);
      expect(baseline.candidateSet!.candidates.length, greaterThan(1));
      final originalWinner =
          baseline.candidateSet!.recommendedCandidate.candidateFingerprint;

      final remediated = ApartmentCandidateSetService(
        normativeEvaluator: _SelectiveBlockingNormativeEvaluator(
          blockedCandidateFingerprint: originalWinner,
        ),
      ).generate(
        input: _request(),
        target: fixture.target,
        project: fixture.project,
      );

      expect(remediated.accepted, isTrue);
      final promoted = remediated.candidateSet!.recommendedCandidate;
      expect(promoted.candidateFingerprint, isNot(originalWinner));
      expect(
        remediated.candidateSet!.engineeringProjection
            .selectedCandidateFingerprint,
        promoted.candidateFingerprint,
      );
      expect(
        remediated.diagnostics!.selectedEntries.single.candidateFingerprint,
        promoted.candidateFingerprint,
      );

      final rejectedWinner = remediated.diagnostics!.entries.singleWhere(
        (entry) => entry.candidateFingerprint == originalWinner,
      );
      expect(rejectedWinner.rejected, isTrue);
      expect(rejectedWinner.blockerCodes, contains('NORMATIVE_BLOCKED'));
      expect(
        remediated.failures
            .where((failure) => failure.code == 'NORMATIVE_BLOCKED')
            .every((failure) => !failure.isBlocker),
        isTrue,
      );
    });

    test('promotion is deterministic across repeated production generation', () {
      final fixture = _projectFixture();
      final baseline = const ApartmentCandidateSetService().generate(
        input: _request(),
        target: fixture.target,
        project: fixture.project,
      );
      expect(baseline.accepted, isTrue);
      final originalWinner =
          baseline.candidateSet!.recommendedCandidate.candidateFingerprint;
      final service = ApartmentCandidateSetService(
        normativeEvaluator: _SelectiveBlockingNormativeEvaluator(
          blockedCandidateFingerprint: originalWinner,
        ),
      );

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
        second.candidateSet!.recommendedCandidate.candidateFingerprint,
        first.candidateSet!.recommendedCandidate.candidateFingerprint,
      );
      expect(
        second.candidateSet!.candidateSetFingerprint,
        first.candidateSet!.candidateSetFingerprint,
      );
      expect(
        second.diagnostics!.diagnosticsFingerprint,
        first.diagnostics!.diagnosticsFingerprint,
      );
    });

    test('fails closed only when every selectable candidate fails late gates',
        () {
      final fixture = _projectFixture();
      final result = const ApartmentCandidateSetService(
        normativeEvaluator: _BlockingNormativeEvaluator(),
      ).generate(
        input: _request(),
        target: fixture.target,
        project: fixture.project,
      );

      expect(result.accepted, isFalse);
      expect(result.candidateSet, isNull);
      final codes = result.failures.map((failure) => failure.code).toSet();
      expect(codes, contains('NORMATIVE_BLOCKED'));
      expect(codes, contains('NO_VALID_TOPOLOGY_CANDIDATE'));
      expect(result.diagnostics!.selectedEntries, isEmpty);
    });
  });
}

final class _SelectiveBlockingNormativeEvaluator
    implements ApartmentNormativeEvidencePort {
  const _SelectiveBlockingNormativeEvaluator({
    required this.blockedCandidateFingerprint,
  });

  final String blockedCandidateFingerprint;

  @override
  ApartmentNormativeEvidenceEvaluationResult evaluate({
    required ApartmentEngineeringProjection projection,
  }) {
    if (projection.selectedCandidateFingerprint ==
        blockedCandidateFingerprint) {
      return _blocked(projection);
    }
    return const ApartmentNormativeEvidenceEvaluator().evaluate(
      projection: projection,
    );
  }
}

final class _BlockingNormativeEvaluator
    implements ApartmentNormativeEvidencePort {
  const _BlockingNormativeEvaluator();

  @override
  ApartmentNormativeEvidenceEvaluationResult evaluate({
    required ApartmentEngineeringProjection projection,
  }) =>
      _blocked(projection);
}

ApartmentNormativeEvidenceEvaluationResult _blocked(
  ApartmentEngineeringProjection projection,
) =>
    ApartmentNormativeEvidenceEvaluationResult(
      evidence: null,
      failures: [
        P9Failure(
          code: 'NORMATIVE_BLOCKED',
          stage: P9FailureStage.normative,
          severity: P9FailureSeverity.blocker,
          facts: {
            'reason': 'pre10-cq18-selective-late-gate',
            'candidateFingerprint': projection.selectedCandidateFingerprint,
            'projectionFingerprint': projection.projectionFingerprint,
          },
        ),
      ],
    );

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

_ProjectFixture _projectFixture() {
  final projectId = ProjectId('pre10-def018-project');
  final siteId = SiteId('pre10-def018-site');
  final buildingId = BuildingId('pre10-def018-building');
  final levelId = LevelId('pre10-def018-level');
  final version = LocalProjectVersion(18);
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

final class _ProjectFixture {
  const _ProjectFixture({
    required this.project,
    required this.target,
  });

  final ProjectAggregateRoot project;
  final LevelWizardTarget target;
}
