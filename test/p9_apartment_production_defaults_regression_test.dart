import 'package:elecx/src/application/project/wizard/apartment/apartment_candidate_set_service.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_wizard_parameters.dart';
import 'package:elecx/src/application/project/wizard/wizard_contracts.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'P9 production defaults always yield selectable candidates on empty Level',
      () {
    final projectId = ProjectId('p9-default-project');
    final siteId = SiteId('p9-default-site');
    final buildingId = BuildingId('p9-default-building');
    final levelId = LevelId('p9-default-level');
    final version = LocalProjectVersion(1);
    final project = ProjectAggregateRoot(
      id: projectId,
      siteId: siteId,
      version: version,
      stores: ProjectEntityStores(
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
            elevationMm: 0,
          ),
        },
      ),
    );
    final target = LevelWizardTarget(
      projectId: projectId,
      siteId: siteId,
      baseVersion: version,
      buildingId: buildingId,
      levelId: levelId,
    );

    final result = const ApartmentCandidateSetService().generate(
      input: ApartmentRequestInput.productionDefaults,
      target: target,
      project: project,
    );

    expect(result.accepted, isTrue, reason: '${result.failures}');
    expect(result.candidateSet, isNotNull);
    expect(result.candidateSet!.candidates, isNotEmpty);
  });
}
