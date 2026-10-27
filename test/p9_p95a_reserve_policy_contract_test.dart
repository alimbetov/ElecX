import 'package:elecx/src/application/project/wizard/apartment/apartment_candidate_set_service.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_engineering_requirements.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_wizard_parameters.dart';
import 'package:elecx/src/application/project/wizard/wizard_contracts.dart';
import 'package:elecx/src/domain/apartment_topology.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('P9.5-A v3 makes reserve policy explicit load evidence', () {
    final fixture = _projectFixture();
    final generated = const ApartmentCandidateSetService().generate(
      input: _request(),
      target: fixture.target,
      project: fixture.project,
    );

    expect(generated.accepted, isTrue);
    final requirements = generated.candidateSet!.engineeringRequirements;
    expect(requirements.requirementsVersion, 'p9.requirements.v3');
    final load = requirements.requirements.singleWhere(
      (item) => item.domain == ApartmentEngineeringRequirementDomain.load,
    );
    expect(load.requiredFactKeys, contains('load.reservePolicy'));
    expect(
      load.evidenceState,
      ApartmentEngineeringRequirementEvidenceState.notEvaluated,
    );
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
  final projectId = ProjectId('p95a-reserve-project');
  final siteId = SiteId('p95a-reserve-site');
  final buildingId = BuildingId('p95a-reserve-building');
  final levelId = LevelId('p95a-reserve-level');
  final version = LocalProjectVersion(14);
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
