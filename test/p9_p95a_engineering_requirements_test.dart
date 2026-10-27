import 'package:elecx/src/application/project/wizard/apartment/apartment_candidate_set_service.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_engineering_requirements.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_engineering_requirements_adapter.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_normative_evidence.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_wizard_parameters.dart';
import 'package:elecx/src/application/project/wizard/wizard_contracts.dart';
import 'package:elecx/src/domain/apartment_topology.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P9.5-A engineering requirements foundation', () {
    test('P9.5-A-Q01 winner requirements bind exact P9.3/P9.4 lineage', () {
      final fixture = _projectFixture();
      final result = const ApartmentCandidateSetService().generate(
        input: _request(),
        target: fixture.target,
        project: fixture.project,
      );

      expect(result.accepted, isTrue);
      final set = result.candidateSet!;
      final requirements = set.engineeringRequirements;

      expect(
        requirements.requirementsVersion,
        apartmentEngineeringRequirementsVersion,
      );
      expect(
        requirements.selectedCandidateFingerprint,
        set.recommendedCandidate.candidateFingerprint,
      );
      expect(
        requirements.projectionFingerprint,
        set.engineeringProjection.projectionFingerprint,
      );
      expect(
        requirements.graphFingerprint,
        set.engineeringProjection.graphFingerprint,
      );
      expect(
        requirements.placementFingerprint,
        set.engineeringProjection.placementFingerprint,
      );
      expect(
        requirements.normativeEvidenceFingerprint,
        set.normativeEvidence.evidenceFingerprint,
      );
      expect(
        requirements.normativeProfileId,
        set.normativeEvidence.normativeProfileId,
      );
      expect(
        requirements.normativeProfileVersion,
        set.normativeEvidence.normativeProfileVersion,
      );
    });

    test('P9.5-A-Q02 every preview card derives requirements from itself', () {
      final fixture = _projectFixture();
      final result = const ApartmentCandidateSetService().generate(
        input: _request(),
        target: fixture.target,
        project: fixture.project,
      );
      final set = result.candidateSet!;

      expect(set.candidates, isNotEmpty);
      for (final card in set.candidates) {
        final derivation = card.deriveEngineeringRequirements();
        expect(derivation.accepted, isTrue);
        final requirements = derivation.requirements!;
        expect(
          requirements.selectedCandidateFingerprint,
          card.candidateFingerprint,
        );
        expect(
          requirements.projectionFingerprint,
          card.engineeringProjection.projectionFingerprint,
        );
        expect(
          requirements.normativeEvidenceFingerprint,
          card.normativeEvidence.evidenceFingerprint,
        );
      }
    });

    test('P9.5-A-Q03 repeated generation is deterministic', () {
      final firstFixture = _projectFixture();
      final secondFixture = _projectFixture();
      final first = const ApartmentCandidateSetService().generate(
        input: _request(),
        target: firstFixture.target,
        project: firstFixture.project,
      );
      final second = const ApartmentCandidateSetService().generate(
        input: _request(),
        target: secondFixture.target,
        project: secondFixture.project,
      );

      final firstRequirements = first.candidateSet!.engineeringRequirements;
      final secondRequirements = second.candidateSet!.engineeringRequirements;
      expect(
        secondRequirements.requirementsFingerprint,
        firstRequirements.requirementsFingerprint,
      );
      expect(
        secondRequirements.requirements
            .map((requirement) => requirement.requirementId)
            .toList(),
        firstRequirements.requirements
            .map((requirement) => requirement.requirementId)
            .toList(),
      );
      expect(
        secondRequirements.stableSerialization,
        firstRequirements.stableSerialization,
      );
    });

    test('P9.5-A-Q04 missing electrical facts stay explicit, never fabricated',
        () {
      final fixture = _projectFixture();
      final result = const ApartmentCandidateSetService().generate(
        input: _request(),
        target: fixture.target,
        project: fixture.project,
      );
      final requirements = result.candidateSet!.engineeringRequirements;

      expect(result.accepted, isTrue);
      expect(requirements.readyForEquipmentConfiguration, isFalse);
      expect(requirements.requirements, hasLength(4));
      expect(requirements.unresolvedRequirements, hasLength(4));
      expect(requirements.blockingUnresolvedRequirements, hasLength(4));
      expect(
        requirements.requirements.map((requirement) => requirement.domain).toSet(),
        ApartmentEngineeringRequirementDomain.values.toSet(),
      );
      for (final requirement in requirements.requirements) {
        expect(
          requirement.evidenceState,
          ApartmentEngineeringRequirementEvidenceState.notEvaluated,
        );
        expect(requirement.establishedFacts, isEmpty);
        expect(requirement.requiredFactKeys, isNotEmpty);
      }
    });

    test('P9.5-A-Q05 derivation cannot mutate P9.3 or P9.4', () {
      final fixture = _projectFixture();
      final result = const ApartmentCandidateSetService().generate(
        input: _request(),
        target: fixture.target,
        project: fixture.project,
      );
      final card = result.candidateSet!.recommendedCandidate;
      final projection = card.engineeringProjection;
      final normative = card.normativeEvidence;
      final graphFingerprint = projection.graphFingerprint;
      final placementFingerprint = projection.placementFingerprint;
      final projectionFingerprint = projection.projectionFingerprint;
      final normativeFingerprint = normative.evidenceFingerprint;
      final normativeSerialization = normative.stableSerialization;

      final derivation = card.deriveEngineeringRequirements();

      expect(derivation.accepted, isTrue);
      expect(projection.graphFingerprint, graphFingerprint);
      expect(projection.placementFingerprint, placementFingerprint);
      expect(projection.projectionFingerprint, projectionFingerprint);
      expect(normative.evidenceFingerprint, normativeFingerprint);
      expect(normative.stableSerialization, normativeSerialization);
    });

    test('P9.5-A-Q06 generation remains project-aggregate immutable', () {
      final fixture = _projectFixture();
      final version = fixture.project.version;
      final stores = fixture.project.stores;

      final result = const ApartmentCandidateSetService().generate(
        input: _request(),
        target: fixture.target,
        project: fixture.project,
      );
      final requirements = result.candidateSet!.engineeringRequirements;

      expect(requirements.requirements, isNotEmpty);
      expect(fixture.project.version, version);
      expect(identical(fixture.project.stores, stores), isTrue);
    });

    test('P9.5-A-Q07 selected-candidate mismatch fails closed', () {
      final fixture = _projectFixture();
      final generated = const ApartmentCandidateSetService().generate(
        input: _request(),
        target: fixture.target,
        project: fixture.project,
      );
      final card = generated.candidateSet!.recommendedCandidate;

      final result = const ApartmentEngineeringRequirementsService().derive(
        selectedCandidateFingerprint: 'wrong-candidate',
        projection: card.engineeringProjection,
        normativeEvidence: card.normativeEvidence,
      );

      expect(result.accepted, isFalse);
      expect(result.requirements, isNull);
      expect(result.failures.single.code, 'INTERNAL_GENERATION_ERROR');
      expect(
        result.failures.single.facts['reason'],
        'selected-winner-requirements-lineage-mismatch',
      );
    });

    test('P9.5-A-Q08 normative-projection mismatch fails closed', () {
      final fixture = _projectFixture();
      final generated = const ApartmentCandidateSetService().generate(
        input: _request(),
        target: fixture.target,
        project: fixture.project,
      );
      final card = generated.candidateSet!.recommendedCandidate;
      final sourceEvidence = card.normativeEvidence;
      final mismatchedEvidence = ApartmentNormativeEvidenceBundle(
        evaluationVersion: sourceEvidence.evaluationVersion,
        normativeProfileId: sourceEvidence.normativeProfileId,
        normativeProfileVersion: sourceEvidence.normativeProfileVersion,
        selectedCandidateFingerprint: card.candidateFingerprint,
        projectionFingerprint: 'wrong-projection',
        assertions: sourceEvidence.assertions,
      );

      final result = const ApartmentEngineeringRequirementsService().derive(
        selectedCandidateFingerprint: card.candidateFingerprint,
        projection: card.engineeringProjection,
        normativeEvidence: mismatchedEvidence,
      );

      expect(result.accepted, isFalse);
      expect(result.requirements, isNull);
      expect(
        result.failures.single.facts['reason'],
        'selected-winner-requirements-lineage-mismatch',
      );
      expect(
        result.failures.single.facts['mismatches'],
        contains('normative.projection'),
      );
    });

    test('P9.5-A-Q09 requirements collections are immutable', () {
      final fixture = _projectFixture();
      final generated = const ApartmentCandidateSetService().generate(
        input: _request(),
        target: fixture.target,
        project: fixture.project,
      );
      final requirements = generated.candidateSet!.engineeringRequirements;
      final first = requirements.requirements.first;

      expect(() => requirements.requirements.clear(), throwsUnsupportedError);
      expect(() => first.requiredFactKeys.clear(), throwsUnsupportedError);
      expect(
        () => first.establishedFacts['fabricated'] = '1',
        throwsUnsupportedError,
      );
    });

    test('P9.5-A-Q10 baseline fact contract is explicit and stable', () {
      final fixture = _projectFixture();
      final generated = const ApartmentCandidateSetService().generate(
        input: _request(),
        target: fixture.target,
        project: fixture.project,
      );
      final requirements = generated.candidateSet!.engineeringRequirements;
      final byDomain = {
        for (final requirement in requirements.requirements)
          requirement.domain: requirement,
      };

      expect(
        byDomain[ApartmentEngineeringRequirementDomain.supply]!.requiredFactKeys,
        containsAll(<String>[
          'supply.voltageV',
          'supply.phaseCount',
          'supply.frequencyHz',
          'supply.availablePowerW',
          'supply.prospectiveShortCircuitCurrentA',
        ]),
      );
      expect(
        byDomain[ApartmentEngineeringRequirementDomain.load]!.requiredFactKeys,
        containsAll(<String>[
          'load.connectedPowerW',
          'load.designPowerW',
          'load.designCurrentA',
          'load.diversityPolicy',
        ]),
      );
      expect(
        byDomain[ApartmentEngineeringRequirementDomain.circuit]!
            .requiredFactKeys,
        containsAll(<String>[
          'circuit.definition',
          'circuit.loadAssignments',
          'circuit.conductorConstraints',
          'circuit.installationMethod',
        ]),
      );
      expect(
        byDomain[ApartmentEngineeringRequirementDomain.protection]!
            .requiredFactKeys,
        containsAll(<String>[
          'protection.overload',
          'protection.shortCircuit',
          'protection.residualCurrent',
          'protection.disconnection',
        ]),
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

_ProjectFixture _projectFixture() {
  final projectId = ProjectId('p95a-requirements-project');
  final siteId = SiteId('p95a-requirements-site');
  final buildingId = BuildingId('p95a-requirements-building');
  final levelId = LevelId('p95a-requirements-level');
  final version = LocalProjectVersion(10);
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
