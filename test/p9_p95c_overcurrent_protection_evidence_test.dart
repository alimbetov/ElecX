import 'package:elecx/src/application/project/wizard/apartment/apartment_candidate_set_service.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_engineering_requirements.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_engineering_requirements_adapter.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_overcurrent_protection_evidence.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_wizard_parameters.dart';
import 'package:elecx/src/application/project/wizard/wizard_contracts.dart';
import 'package:elecx/src/domain/apartment_topology.dart';
import 'package:elecx/src/domain/overcurrent_protection.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/engine/overcurrent_protection_selection_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('overcurrent proof stays partial until short-circuit/RCD/disconnection', () {
    final fixture = _projectFixture();
    final generated = const ApartmentCandidateSetService().generate(
      input: _request(),
      target: fixture.target,
      project: fixture.project,
    );
    expect(generated.accepted, isTrue);
    final original = generated.candidateSet!.engineeringRequirements;

    const c16 = OvercurrentProtectiveDeviceSpec(
      id: 'mcb-c16-6ka',
      kind: OvercurrentDeviceKind.mcb,
      ratedCurrentA: 16,
      breakingCapacityKa: 6,
      poleCount: 1,
      tripCurve: OvercurrentTripCurve.c,
      sourceId: 'catalog',
      sourceRevision: '1',
    );
    final request = OvercurrentProtectionRequest(
      designCurrentA: 11.1,
      cableAmpacityA: 21,
      prospectiveShortCircuitCurrentA: 3500,
      candidates: const [c16],
    );
    final selection = OvercurrentProtectionSelectionEngine.select(request);
    final updated = ApartmentOvercurrentProtectionEvidenceService.apply(
      requirements: original,
      request: request,
      selection: selection,
    );

    final protection = updated.requirements.singleWhere(
      (item) =>
          item.domain == ApartmentEngineeringRequirementDomain.protection,
    );
    expect(
      protection.evidenceState,
      ApartmentEngineeringRequirementEvidenceState.indeterminate,
    );
    expect(protection.factEvidence.keys, contains('protection.overload'));
    expect(
      protection.factEvidence.keys,
      isNot(contains('protection.shortCircuit')),
    );
    expect(
      protection.factEvidence.keys,
      isNot(contains('protection.residualCurrent')),
    );
    expect(
      protection.factEvidence.keys,
      isNot(contains('protection.disconnection')),
    );
    expect(protection.blocksEquipmentConfiguration, isTrue);
    expect(updated.readyForEquipmentConfiguration, isFalse);
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
  final projectId = ProjectId('p95c-protection-project');
  final siteId = SiteId('p95c-protection-site');
  final buildingId = BuildingId('p95c-protection-building');
  final levelId = LevelId('p95c-protection-level');
  final version = LocalProjectVersion(13);
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
