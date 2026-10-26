import 'package:elecx/src/application/project/wizard/apartment/apartment_candidate_set_service.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_wizard_parameters.dart';
import 'package:elecx/src/application/project/wizard/wizard_contracts.dart';
import 'package:elecx/src/domain/apartment_topology.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_space_semantics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P9.1 production runtime integration', () {
    test('production generation publishes one deterministic recommended winner',
        () {
      final fixture = _projectFixture();
      final originalVersion = fixture.project.version;
      final originalStores = fixture.project.stores;
      const service = ApartmentCandidateSetService();
      final request = _request();

      final first = service.generate(
        input: request,
        target: fixture.target,
        project: fixture.project,
      );
      final second = service.generate(
        input: request,
        target: fixture.target,
        project: fixture.project,
      );

      expect(first.accepted, isTrue);
      expect(second.accepted, isTrue);
      final firstSet = first.candidateSet!;
      final secondSet = second.candidateSet!;

      expect(firstSet.generatorVersion, 'p9.generator.v3');
      expect(firstSet.candidates, isNotEmpty);
      expect(
        firstSet.recommendedCandidate.candidateFingerprint,
        firstSet.candidates.first.candidateFingerprint,
      );
      expect(
        firstSet.candidates
            .where(
              (candidate) =>
                  candidate.candidateFingerprint ==
                  firstSet.recommendedCandidate.candidateFingerprint,
            )
            .length,
        1,
      );
      expect(
        firstSet.recommendedCandidate.rankedCandidate.candidate.validation
            .accepted,
        isTrue,
      );

      expect(
        secondSet.recommendedCandidate.candidateFingerprint,
        firstSet.recommendedCandidate.candidateFingerprint,
      );
      expect(secondSet.candidateSetFingerprint, firstSet.candidateSetFingerprint);
      expect(fixture.project.version, same(originalVersion));
      expect(fixture.project.stores, same(originalStores));
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
  final projectId = ProjectId('p91-production-project');
  final siteId = SiteId('p91-production-site');
  final buildingId = BuildingId('p91-production-building');
  final levelId = LevelId('p91-production-level');
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
