import 'package:elecx/src/application/project/wizard/building/building_generation_parameters.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_orientation.dart';

BuildingLevelParameters p10Level({
  String key = 'ground',
  int ordinal = 0,
  int number = 0,
  String code = 'G',
  ProjectLevelKind kind = ProjectLevelKind.ground,
  int height = 3000,
}) =>
    BuildingLevelParameters(
      generationKey: key,
      ordinal: ordinal,
      levelNumber: number,
      code: code,
      kind: kind,
      floorToFloorHeightMm: height,
    );

List<BuildingLevelParameters> p10Levels() => [
      p10Level(),
      p10Level(
        key: 'residential.1',
        ordinal: 1,
        number: 1,
        code: '01',
        kind: ProjectLevelKind.residential,
      ),
    ];

CommonCoreParameters p10Core({int stairs = 1, int lifts = 1}) =>
    CommonCoreParameters(
      stairCount: stairs,
      liftCount: lifts,
      serviceShaftCount: 1,
      corridorWidthMm: 1800,
    );

BuildingGenerationParameters p10Request({
  String name = 'Tower A',
  String site = 'site-a',
  BuildingCompositionKind kind = BuildingCompositionKind.residentialTower,
  LevelStackParameters? stack,
  BuildingSitePlacement? placement,
  TypicalFloorSelection? typicalFloor,
  CommonCoreParameters? core,
  ServiceAnchorParameters? anchors,
  BuildingTemplateRef? template,
  int schemaVersion = 1,
  String generatorVersion =
      BuildingGenerationParameters.currentGeneratorVersion,
}) =>
    BuildingGenerationParameters(
      kind: kind,
      siteId: SiteId(site),
      displayName: name,
      placement: placement ??
          BuildingSitePlacement(
            xMm: 0,
            yMm: 0,
            orientation: ProjectEngineeringNorth.fromDegrees(0),
          ),
      levelStack: stack ?? LevelStackParameters(levels: p10Levels()),
      commonCore: core ?? p10Core(),
      serviceAnchors: anchors ?? ServiceAnchorParameters(),
      typicalFloor: typicalFloor,
      template: template,
      schemaVersion: schemaVersion,
      generatorVersion: generatorVersion,
    );

BuildingTemplateRef p10TemplateRef({
  String id = 'p10.tower',
  int templateVersion = 1,
  int catalogVersion = 1,
}) =>
    BuildingTemplateRef(
      id: TemplateId(id),
      templateVersion: templateVersion,
      catalogVersion: catalogVersion,
    );
