import 'package:elecx/src/application/project/wizard/apartment/apartment_candidate_set_service.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_engineering_requirements.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_engineering_requirements_adapter.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_load_calculation_evidence.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_wizard_parameters.dart';
import 'package:elecx/src/application/project/wizard/wizard_contracts.dart';
import 'package:elecx/src/domain/apartment_topology.dart';
import 'package:elecx/src/domain/electrical_load_calculation.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/engine/load_calculation_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P9.5-B calculated load evidence', () {
    test('calculated load resolves only load requirement', () {
      final fixture = _projectFixture();
      final generated = const ApartmentCandidateSetService().generate(
        input: _request(),
        target: fixture.target,
        project: fixture.project,
      );
      expect(generated.accepted, isTrue);
      final original = generated.candidateSet!.engineeringRequirements;
      expect(original.blockingUnresolvedRequirements, hasLength(4));

      final request = _loadRequest();
      final calculation = LoadCalculationEngine.calculate(request);
      final updated = ApartmentLoadCalculationEvidenceService.apply(
        requirements: original,
        request: request,
        calculation: calculation,
      );

      final load = updated.requirements.singleWhere(
        (item) => item.domain == ApartmentEngineeringRequirementDomain.load,
      );
      expect(
        load.evidenceState,
        ApartmentEngineeringRequirementEvidenceState.proven,
      );
      expect(load.establishedFacts['load.connectedPowerW'], '3500 W');
      expect(load.establishedFacts['load.designPowerW'], isNotNull);
      expect(load.establishedFacts['load.designCurrentA'], isNotNull);
      expect(
        load.establishedFacts['load.diversityPolicy'],
        'residential-general-0.80 code',
      );
      expect(updated.blockingUnresolvedRequirements, hasLength(3));
      expect(updated.readyForEquipmentConfiguration, isFalse);
    });

    test('evidence binding rejects a result from another request', () {
      final fixture = _projectFixture();
      final generated = const ApartmentCandidateSetService().generate(
        input: _request(),
        target: fixture.target,
        project: fixture.project,
      );
      final requirements = generated.candidateSet!.engineeringRequirements;
      final firstRequest = _loadRequest();
      final calculation = LoadCalculationEngine.calculate(firstRequest);
      final otherRequest = ElectricalLoadCalculationRequest(
        phaseSystem: ElectricalLoadPhaseSystem.singlePhaseAc,
        nominalVoltageV: 230,
        loads: const [
          ElectricalLoadInput(
            id: 'other-load',
            ratedPowerW: 1000,
            quantity: 1,
            utilizationFactor: 1,
            powerFactor: 1,
            reactivePowerKind: ElectricalReactivePowerKind.lagging,
            sourceId: 'catalog',
            sourceRevision: '1',
          ),
        ],
        diversityPolicy: const ElectricalDiversityPolicy(
          id: 'residential-general-0.80',
          factor: 0.80,
          sourceId: 'project-diversity-policy',
          sourceRevision: '1',
        ),
        reservePolicy: const ElectricalReservePolicy(
          id: 'project-reserve-20',
          reserveRatio: 0.20,
          sourceId: 'project-reserve-policy',
          sourceRevision: '1',
        ),
      );

      expect(
        () => ApartmentLoadCalculationEvidenceService.apply(
          requirements: requirements,
          request: otherRequest,
          calculation: calculation,
        ),
        throwsArgumentError,
      );
    });
  });
}

ElectricalLoadCalculationRequest _loadRequest() =>
    ElectricalLoadCalculationRequest(
      phaseSystem: ElectricalLoadPhaseSystem.singlePhaseAc,
      nominalVoltageV: 230,
      loads: const [
        ElectricalLoadInput(
          id: 'sockets',
          ratedPowerW: 3000,
          quantity: 1,
          utilizationFactor: 0.70,
          powerFactor: 0.95,
          reactivePowerKind: ElectricalReactivePowerKind.lagging,
          sourceId: 'project-load-schedule',
          sourceRevision: '1',
        ),
        ElectricalLoadInput(
          id: 'lighting',
          ratedPowerW: 500,
          quantity: 1,
          utilizationFactor: 0.80,
          powerFactor: 0.90,
          reactivePowerKind: ElectricalReactivePowerKind.lagging,
          sourceId: 'project-load-schedule',
          sourceRevision: '1',
        ),
      ],
      diversityPolicy: const ElectricalDiversityPolicy(
        id: 'residential-general-0.80',
        factor: 0.80,
        sourceId: 'project-diversity-policy',
        sourceRevision: '1',
      ),
      reservePolicy: const ElectricalReservePolicy(
        id: 'project-reserve-20',
        reserveRatio: 0.20,
        sourceId: 'project-reserve-policy',
        sourceRevision: '1',
      ),
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
  final projectId = ProjectId('p95b-load-project');
  final siteId = SiteId('p95b-load-site');
  final buildingId = BuildingId('p95b-load-building');
  final levelId = LevelId('p95b-load-level');
  final version = LocalProjectVersion(12);
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
