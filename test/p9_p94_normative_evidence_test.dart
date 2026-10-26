import 'package:elecx/src/application/project/wizard/apartment/apartment_candidate_set_service.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_normative_evidence.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_wizard_parameters.dart';
import 'package:elecx/src/application/project/wizard/wizard_contracts.dart';
import 'package:elecx/src/domain/apartment_topology.dart';
import 'package:elecx/src/domain/installation_guides.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/engine/kz_installation_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P9.4 normative evidence overlay', () {
    test('P9.4-Q01 spatial production projection is explicitly not applicable',
        () {
      final projection = _projection();
      final evaluation = const ApartmentNormativeEvidenceEvaluator().evaluate(
        projection: projection,
      );

      expect(evaluation.accepted, isTrue);
      final evidence = evaluation.evidence!;
      expect(evidence.evaluationVersion, apartmentNormativeEvaluationVersion);
      expect(evidence.normativeProfileId, apartmentNormativeProfileId);
      expect(evidence.normativeProfileVersion, apartmentNormativeProfileVersion);
      expect(evidence.projectionFingerprint, projection.projectionFingerprint);
      expect(
        evidence.selectedCandidateFingerprint,
        projection.selectedCandidateFingerprint,
      );
      expect(evidence.overallState, InstallationRuleResultKind.notApplicable);
      expect(evidence.blocksEligibility, isFalse);
      expect(evidence.assertions, hasLength(4));
      expect(
        evidence.assertions.map((assertion) => assertion.result.kind).toSet(),
        {InstallationRuleResultKind.notApplicable},
      );
    });

    test('P9.4-Q02 evidence is deterministic and cannot mutate P9.3', () {
      final projection = _projection();
      final graphFingerprint = projection.graphFingerprint;
      final placementFingerprint = projection.placementFingerprint;
      final projectionFingerprint = projection.projectionFingerprint;
      const evaluator = ApartmentNormativeEvidenceEvaluator();

      final first = evaluator.evaluate(projection: projection).evidence!;
      final second = evaluator.evaluate(projection: projection).evidence!;

      expect(second.evidenceFingerprint, first.evidenceFingerprint);
      expect(second.stableSerialization, first.stableSerialization);
      expect(projection.graphFingerprint, graphFingerprint);
      expect(projection.placementFingerprint, placementFingerprint);
      expect(projection.projectionFingerprint, projectionFingerprint);
    });

    test('P9.4-Q03 every production assertion has pinned normative provenance',
        () {
      final evidence = const ApartmentNormativeEvidenceEvaluator()
          .evaluate(projection: _projection())
          .evidence!;

      for (final assertion in evidence.assertions) {
        expect(assertion.result.source, isNotNull);
        expect(assertion.result.source!.isRevisionPinned, isTrue);
        expect(assertion.result.evidence, isNotNull);
        expect(assertion.result.evidence!.source.isRevisionPinned, isTrue);
        expect(
          assertion.result.evidence!.source.authority,
          InstallationGuideAuthority.normative,
        );
      }
    });

    test('P9.4-Q04 PASS plus NOT_APPLICABLE stays eligible PASS', () {
      final bundle = _bundle([
        ApartmentNormativeAssertion(
          result: KzInstallationRules.validateResidentialSocketHeight(300),
          safetyCritical: true,
        ),
        ApartmentNormativeAssertion(
          result: KzInstallationRules.validateChildOccupancyHeight(
            null,
            childOccupancyConfirmed: false,
          ),
          safetyCritical: true,
        ),
      ]);

      expect(bundle.overallState, InstallationRuleResultKind.pass);
      expect(bundle.blocksEligibility, isFalse);
    });

    test('P9.4-Q05 proven FAIL blocks eligibility', () {
      final bundle = _bundle([
        ApartmentNormativeAssertion(
          result: KzInstallationRules.validateResidentialSocketHeight(1200),
          safetyCritical: true,
        ),
      ]);

      expect(bundle.overallState, InstallationRuleResultKind.fail);
      expect(bundle.blocksEligibility, isTrue);
    });

    test('P9.4-Q06 safety-critical INDETERMINATE blocks eligibility', () {
      final bundle = _bundle([
        ApartmentNormativeAssertion(
          result: KzInstallationRules.validateDistanceToGasPipe(null),
          safetyCritical: true,
        ),
      ]);

      expect(bundle.overallState, InstallationRuleResultKind.indeterminate);
      expect(bundle.blocksEligibility, isTrue);
    });

    test('P9.4-Q07 NOT_APPLICABLE carries explicit applicability evidence', () {
      final evidence = const ApartmentNormativeEvidenceEvaluator()
          .evaluate(projection: _projection())
          .evidence!;

      for (final assertion in evidence.assertions) {
        final ruleEvidence = assertion.result.evidence!;
        expect(
          ruleEvidence.applicability,
          NormativeApplicability.notApplicable,
        );
        expect(ruleEvidence.rationale, isNotEmpty);
        expect(ruleEvidence.facts, isNotEmpty);
      }
    });

    test('P9.4-Q08 diagnostics overlay updates only selected candidate', () {
      final fixture = _projectFixture();
      final result = const ApartmentCandidateSetService().generate(
        input: _request(),
        target: fixture.target,
        project: fixture.project,
      );
      final evidence = const ApartmentNormativeEvidenceEvaluator()
          .evaluate(projection: result.candidateSet!.engineeringProjection)
          .evidence!;

      final before = result.diagnostics!;
      final after = before.withNormativeEvidence(evidence);

      expect(
        before.selectedEntries.single.normativeState.name,
        'notEvaluated',
      );
      expect(
        after.selectedEntries.single.normativeState.name,
        'notApplicable',
      );
      for (final entry in after.entries.where((entry) => !entry.selected)) {
        expect(entry.normativeState.name, 'notEvaluated');
      }
    });

    test('P9.4-Q09 unpinned normative source is rejected fail closed', () {
      const source = InstallationGuideSource(
        code: 'UNPINNED',
        title: 'Unpinned test source',
      );
      final result = InstallationRuleResult(
        ruleId: 'test.unpinned',
        kind: InstallationRuleResultKind.pass,
        message: 'test',
        source: source,
        evidence: NormativeEvidence(
          source: source,
          applicability: NormativeApplicability.applicable,
          facts: const ['value=1'],
          rationale: 'test evidence',
        ),
      );

      expect(
        () => ApartmentNormativeAssertion(
          result: result,
          safetyCritical: true,
        ),
        throwsArgumentError,
      );
    });

    test('P9.4-Q10 assertion collection is immutable', () {
      final evidence = const ApartmentNormativeEvidenceEvaluator()
          .evaluate(projection: _projection())
          .evidence!;

      expect(
        () => evidence.assertions.clear(),
        throwsUnsupportedError,
      );
    });
  });
}

ApartmentNormativeEvidenceBundle _bundle(
  List<ApartmentNormativeAssertion> assertions,
) =>
    ApartmentNormativeEvidenceBundle(
      evaluationVersion: apartmentNormativeEvaluationVersion,
      normativeProfileId: apartmentNormativeProfileId,
      normativeProfileVersion: apartmentNormativeProfileVersion,
      selectedCandidateFingerprint: 'candidate-fixture',
      projectionFingerprint: 'projection-fixture',
      assertions: assertions,
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
  final projectId = ProjectId('p94-normative-project');
  final siteId = SiteId('p94-normative-site');
  final buildingId = BuildingId('p94-normative-building');
  final levelId = LevelId('p94-normative-level');
  final version = LocalProjectVersion(9);
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

ApartmentEngineeringProjection _projection() {
  final fixture = _projectFixture();
  final result = const ApartmentCandidateSetService().generate(
    input: _request(),
    target: fixture.target,
    project: fixture.project,
  );
  expect(result.accepted, isTrue);
  return result.candidateSet!.engineeringProjection;
}

final class _ProjectFixture {
  const _ProjectFixture({
    required this.project,
    required this.target,
  });

  final ProjectAggregateRoot project;
  final LevelWizardTarget target;
}
