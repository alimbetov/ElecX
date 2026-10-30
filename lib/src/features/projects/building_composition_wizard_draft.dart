import '../../application/project/wizard/apartment/apartment_wizard_parameters.dart';
import '../../application/project/wizard/building/building_common_core_composition.dart';
import '../../application/project/wizard/building/building_composition_wizard_command.dart';
import '../../application/project/wizard/building/building_composition_wizard_provider.dart';
import '../../application/project/wizard/building/building_generation_parameters.dart';
import '../../application/project/wizard/building/building_level_stack_generator.dart';
import '../../application/project/wizard/building/building_shell_composition.dart';
import '../../application/project/wizard/building/residential_tower_composition.dart';
import '../../application/project/wizard/building/site_composition.dart';
import '../../domain/boundary_topology.dart';
import '../../domain/project_aggregate.dart';
import '../../domain/project_identity.dart';
import '../../domain/project_orientation.dart';
import '../../domain/project_service_anchor.dart';
import '../../domain/project_space_semantics.dart';
import '../../domain/project_site_layout.dart';

/// Presentation draft only. Strings may be temporarily invalid; Generate
/// converts them into the existing immutable domain-backed request contracts.
final class BuildingCompositionFormDraft {
  BuildingCompositionFormDraft(SiteBuildingSlot slot)
      : key = slot.key,
        tower =
            slot.parameters.kind == BuildingCompositionKind.residentialTower,
        source = slot {
    final p = slot.parameters, c = p.commonCore, l = slot.layout.commonCore;
    fields.addAll({
      'name': p.displayName,
      'x': '${p.placement.xMm}',
      'y': '${p.placement.yMm}',
      'width': '${slot.layout.footprintWidthMm}',
      'depth': '${slot.layout.footprintDepthMm}',
      'floors':
          '${p.levelStack.levels.where((l) => l.kind == ProjectLevelKind.residential).length}',
      'basements':
          '${p.levelStack.levels.where((l) => l.kind == ProjectLevelKind.basement).length}',
      'height': '${p.levelStack.levels.first.floorToFloorHeightMm}',
      'stairs': '${c.stairCount}',
      'lifts': '${c.liftCount}',
      'shafts': '${c.serviceShaftCount}',
      'electricalRisers': '${c.electricalRiserCount}',
      'telecomRisers': '${c.telecomRiserCount}',
      'corridorWidth': '${c.corridorWidthMm}',
      'originX': '${l.originXmm}',
      'originY': '${l.originYmm}',
      'corridorLength': '${l.corridorLengthMm}'
    });
    quarterTurns =
        p.placement.orientation.milliDegreesClockwiseFromPositiveY ~/ 90000;
    roof = p.levelStack.levels.any((l) => l.kind == ProjectLevelKind.roof);
    technical =
        p.levelStack.levels.any((l) => l.kind == ProjectLevelKind.technical);
    technicalRoom = c.includeTechnicalRoom;
    commonHall = c.serviceSpacePolicy.includeCommonHall;
    apartments.addAll(slot.apartments
        .map((a) => BuildingApartmentFormDraft(a.key, a.displayName, a.input)));
  }
  final String key;
  final bool tower;
  final SiteBuildingSlot source;
  final Map<String, String> fields = {};
  final List<BuildingApartmentFormDraft> apartments = [];
  final Map<ProjectServiceAnchorKind, BuildingAnchorFormDraft> anchors = {};
  int quarterTurns = 0;
  bool roof = true, technical = false, technicalRoom = true, commonHall = true;
  int _nextApartment = 100;
  void addApartment() => apartments.add(BuildingApartmentFormDraft(
      'apartment.${_nextApartment++}',
      'Apartment ${apartments.length + 1}',
      ApartmentRequestInput.productionDefaults));
  SiteBuildingSlot materialize(SiteId site) {
    final old = source.parameters.commonCore.serviceSpacePolicy;
    final core = CommonCoreParameters.v2(
        stairCount: integer(fields, 'stairs'),
        liftCount: integer(fields, 'lifts'),
        serviceShaftCount: integer(fields, 'shafts'),
        electricalRiserCount: integer(fields, 'electricalRisers'),
        telecomRiserCount: integer(fields, 'telecomRisers'),
        corridorWidthMm: integer(fields, 'corridorWidth'),
        includeTechnicalRoom: technicalRoom,
        serviceSpacePolicy: CommonServiceSpacePolicy(
            includeCommonHall: commonHall,
            includeElevatorHall: old.includeElevatorHall,
            includeElectricalRoomCandidate: old.includeElectricalRoomCandidate,
            includeTelecomRoomCandidate: old.includeTelecomRoomCandidate,
            includeFireControlRoomCandidate:
                old.includeFireControlRoomCandidate,
            includeUtilityRoomCandidate: old.includeUtilityRoomCandidate));
    final height = integer(fields, 'height');
    return SiteBuildingSlot(
        key: key,
        parameters: BuildingGenerationParameters(
            kind: tower
                ? BuildingCompositionKind.residentialTower
                : BuildingCompositionKind.detachedHouse,
            siteId: site,
            displayName: fields['name']!,
            placement: BuildingSitePlacement(
                xMm: integer(fields, 'x'),
                yMm: integer(fields, 'y'),
                orientation:
                    ProjectEngineeringNorth.fromDegrees(quarterTurns * 90)),
            levelStack: const BuildingLevelStackGenerator()
                .residentialParameters(
                    upperResidentialLevels: integer(fields, 'floors'),
                    basementLevels: integer(fields, 'basements'),
                    technicalLevels: technical ? 1 : 0,
                    includeRoof: roof,
                    basementHeightMm: height,
                    groundHeightMm: height,
                    residentialHeightMm: height,
                    technicalHeightMm: height,
                    roofHeightMm: height),
            commonCore: core,
            serviceAnchors: ServiceAnchorParameters(
                kinds: anchors.keys.map(
                    (k) => BuildingServiceAnchorKind.values.byName(k.name))),
            template: BuildingTemplateRef(
                id: TemplateId(tower ? 'p10.tower' : 'p10.cottage'),
                templateVersion: 1,
                catalogVersion: 1)),
        layout: BuildingCompositionLayout(
            footprintWidthMm: integer(fields, 'width'),
            footprintDepthMm: integer(fields, 'depth'),
            slabThicknessMm: source.layout.slabThicknessMm,
            slabMaterialId: source.layout.slabMaterialId,
            commonCore: CommonCoreLayoutParameters(
                originXmm: integer(fields, 'originX'),
                originYmm: integer(fields, 'originY'),
                corridorLengthMm: integer(fields, 'corridorLength'),
                coreModuleWidthMm: source.layout.commonCore.coreModuleWidthMm,
                coreDepthMm: source.layout.commonCore.coreDepthMm,
                candidateRoomWidthMm:
                    source.layout.commonCore.candidateRoomWidthMm,
                candidateRoomDepthMm:
                    source.layout.commonCore.candidateRoomDepthMm)),
        apartments: tower ? apartments.map((a) => a.materialize()) : const []);
  }
}

final class BuildingApartmentFormDraft {
  BuildingApartmentFormDraft(this.key, this.name, this.source)
      : fields = {
          'rooms': '${source.habitableRoomCount}',
          'area': '${source.approximateAreaDm2 / 100}',
          'bathrooms': '${source.bathroomCount}'
        };
  final String key;
  final String name;
  final ApartmentRequestInput source;
  final Map<String, String> fields;
  TowerApartmentRequest materialize() {
    final area = double.tryParse(fields['area']!.trim().replaceAll(',', '.'));
    if (area == null || !area.isFinite) {
      throw const FormatException('Invalid area.');
    }
    return TowerApartmentRequest(
        key: key,
        displayName: name,
        input: ApartmentRequestInput(
            habitableRoomCount: integer(fields, 'rooms'),
            approximateAreaDm2: (area * 100).round(),
            bathroomCount: integer(fields, 'bathrooms'),
            separateWcCount: source.separateWcCount,
            balconyCount: source.balconyCount,
            balconyKind: source.balconyKind,
            kitchenMode: source.kitchenMode,
            corridorMode: source.corridorMode,
            exteriorExposurePreference: source.exteriorExposurePreference,
            areaBasis: source.areaBasis,
            preferredFamily: source.preferredFamily,
            preferDayNightSeparation: source.preferDayNightSeparation));
  }
}

final class BuildingAnchorFormDraft {
  BuildingAnchorFormDraft()
      : fields = {
          'name': '',
          'x': '',
          'y': '',
          'offset': '300',
          'height': '1200'
        };
  final Map<String, String> fields;
  BuildingWizardWallSide side = BuildingWizardWallSide.left;
  String? key;
  String levelKey = 'ground';
  SpaceUsage spaceUsage = SpaceUsage.corridor;
  BuildingWizardServiceAnchorInput materialize(
          String building, ProjectServiceAnchorKind kind, String name) =>
      BuildingWizardServiceAnchorInput(
          key: key ?? '$building.${kind.name.toLowerCase()}',
          name: fields['name']!.trim().isEmpty ? name : fields['name']!,
          kind: kind,
          buildingKey: building,
          levelKey: levelKey,
          spaceUsage: spaceUsage,
          side: side,
          offsetMm: isServiceEntryKind(kind) ? integer(fields, 'offset') : 0,
          heightMm: isServiceEntryKind(kind) ? integer(fields, 'height') : 0,
          sitePoint: isServiceEntryKind(kind)
              ? null
              : BoundaryPointMm(
                  xMm: integer(fields, 'x'), yMm: integer(fields, 'y')));
}

final class ExistingBuildingPlacementFormDraft {
  ExistingBuildingPlacementFormDraft(this.id, this.name);
  final BuildingId id;
  final String name;
  final Map<String, String> fields = {
    'x': '',
    'y': '',
    'width': '',
    'depth': ''
  };
  int quarterTurns = 0;
  ProjectBuildingSitePlacement materialize() => ProjectBuildingSitePlacement(
      xMm: integer(fields, 'x'),
      yMm: integer(fields, 'y'),
      widthMm: integer(fields, 'width'),
      depthMm: integer(fields, 'depth'),
      orientation: ProjectEngineeringNorth.fromDegrees(quarterTurns * 90));
}

int integer(Map<String, String> fields, String key) {
  final value = int.tryParse(fields[key]!.trim());
  if (value == null) {
    throw const FormatException('An integer value is required.');
  }
  return value;
}

SiteBuildingSlot buildingWizardPreset(SiteId site,
    {required String key, bool tower = false, int x = 0, int y = 0}) {
  if (!tower) {
    final defaults =
        const BuildingCompositionWizardProvider().defaultsForSite(site);
    final p = defaults.buildingParameters!;
    return SiteBuildingSlot(
        key: key,
        parameters: BuildingGenerationParameters(
            kind: p.kind,
            siteId: site,
            displayName: p.displayName,
            placement: BuildingSitePlacement(
                xMm: x,
                yMm: y,
                orientation: ProjectEngineeringNorth.fromDegrees(0)),
            levelStack: p.levelStack,
            commonCore: p.commonCore,
            serviceAnchors: p.serviceAnchors,
            template: p.template),
        layout: defaults.layout!);
  }
  return SiteBuildingSlot(
      key: key,
      parameters: BuildingGenerationParameters(
          kind: BuildingCompositionKind.residentialTower,
          siteId: site,
          displayName: 'Residential tower',
          placement: BuildingSitePlacement(
              xMm: x,
              yMm: y,
              orientation: ProjectEngineeringNorth.fromDegrees(0)),
          levelStack: const BuildingLevelStackGenerator()
              .residentialParameters(upperResidentialLevels: 2),
          commonCore: CommonCoreParameters.v2(
              stairCount: 1,
              liftCount: 1,
              serviceShaftCount: 1,
              electricalRiserCount: 1,
              telecomRiserCount: 1,
              corridorWidthMm: 2000,
              includeTechnicalRoom: true),
          serviceAnchors: ServiceAnchorParameters(),
          template: BuildingTemplateRef(
              id: TemplateId('p10.tower'),
              templateVersion: 1,
              catalogVersion: 1)),
      layout: BuildingCompositionLayout(
          footprintWidthMm: 80000,
          footprintDepthMm: 40000,
          commonCore: CommonCoreLayoutParameters(
              originXmm: 1000, originYmm: 30000, corridorLengthMm: 76000)),
      apartments: [
        for (var i = 0; i < 2; i++)
          TowerApartmentRequest(
              key: 'apartment.$i',
              displayName: 'Apartment ${i + 1}',
              input: ApartmentRequestInput.productionDefaults)
      ]);
}
