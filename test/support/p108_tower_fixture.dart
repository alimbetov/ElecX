import 'package:elecx/src/application/project/project_snapshot.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_wizard_parameters.dart';
import 'package:elecx/src/application/project/wizard/building/building_common_core_composition.dart';
import 'package:elecx/src/application/project/wizard/building/building_generation_parameters.dart';
import 'package:elecx/src/application/project/wizard/building/building_level_stack_generator.dart';
import 'package:elecx/src/application/project/wizard/building/building_shell_composition.dart';
import 'package:elecx/src/application/project/wizard/building/residential_tower_composition.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_orientation.dart';

final class P108TowerFixture {
  P108TowerFixture();
  final projectId = ProjectId('p108-project');
  final siteId = SiteId('p108-site');
  ProjectAggregateRoot get project => ProjectAggregateRoot(
      id: projectId,
      siteId: siteId,
      version: LocalProjectVersion(0),
      stores: ProjectEntityStores(sites: {
        siteId: ProjectSiteEntity(
            id: siteId, name: 'Tower Site', buildingIds: const []),
      }));
  BuildingGenerationParameters parameters(
          {int residentialLevels = 2,
          int basements = 1,
          int technicalLevels = 1,
          bool roof = true,
          CommonCoreParameters? core,
          BuildingSitePlacement? placement,
          TypicalFloorSelection? typicalFloor,
          BuildingTemplateRef? template}) =>
      BuildingGenerationParameters(
          kind: BuildingCompositionKind.residentialTower,
          siteId: siteId,
          displayName: 'Production Tower',
          placement: placement ??
              BuildingSitePlacement(
                  xMm: 0,
                  yMm: 0,
                  orientation: ProjectEngineeringNorth.fromDegrees(0)),
          levelStack: const BuildingLevelStackGenerator().residentialParameters(
              basementLevels: basements,
              upperResidentialLevels: residentialLevels,
              technicalLevels: technicalLevels,
              includeRoof: roof),
          commonCore: core ??
              CommonCoreParameters.v2(
                  stairCount: 1,
                  liftCount: 1,
                  serviceShaftCount: 1,
                  electricalRiserCount: 1,
                  telecomRiserCount: 1,
                  corridorWidthMm: 2000,
                  includeTechnicalRoom: true),
          serviceAnchors: ServiceAnchorParameters(kinds: const {
            BuildingServiceAnchorKind.electricalEntry,
            BuildingServiceAnchorKind.telecomEntry
          }),
          typicalFloor: typicalFloor,
          template: template ??
              BuildingTemplateRef(
                  id: TemplateId('p10.tower'),
                  templateVersion: 1,
                  catalogVersion: 1));
  BuildingCompositionLayout layout(
          {int width = 80000,
          int depth = 40000,
          int corridorLength = 76000,
          int originY = 30000}) =>
      BuildingCompositionLayout(
          footprintWidthMm: width,
          footprintDepthMm: depth,
          commonCore: CommonCoreLayoutParameters(
              originXmm: 1000,
              originYmm: originY,
              corridorLengthMm: corridorLength));
  List<TowerApartmentRequest> get requests => [
        TowerApartmentRequest(
            key: 'a',
            displayName: 'Apartment A',
            input: ApartmentRequestInput.productionDefaults),
        TowerApartmentRequest(
            key: 'b',
            displayName: 'Apartment B',
            input: ApartmentRequestInput.productionDefaults),
      ];
  ResidentialTowerCompositionCommand command(
          {ProjectAggregateRoot? project,
          BuildingGenerationParameters? parameters,
          BuildingCompositionLayout? layout,
          Iterable<TowerApartmentRequest>? requests}) =>
      ResidentialTowerCompositionCommand.create(
          project: project ?? this.project,
          compositionKey: 'tower.main',
          parameters: parameters ?? this.parameters(),
          layout: layout ?? this.layout(),
          requests: requests ?? this.requests);
}

ProjectSnapshot p108Snapshot(ProjectAggregateRoot project) => ProjectSnapshot(
    aggregate: project,
    name: 'P10.8 Tower',
    createdAt: DateTime.utc(2026, 10, 29),
    updatedAt: DateTime.utc(2026, 10, 29));
