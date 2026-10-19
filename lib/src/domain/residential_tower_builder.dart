import 'building_composition.dart';
import 'project_model.dart';

final class ResidentialTowerSpec {
  const ResidentialTowerSpec({
    this.lowestBasementLevel = -30,
    this.highestResidentialLevel = 16,
    this.residentialFloorToFloorMm = 3000,
    this.basementFloorToFloorMm = 3300,
    this.groundElevationMm = 0,
  })  : assert(lowestBasementLevel >= -30),
        assert(lowestBasementLevel <= -1),
        assert(highestResidentialLevel >= 1),
        assert(residentialFloorToFloorMm > 0),
        assert(basementFloorToFloorMm > 0);

  final int lowestBasementLevel;
  final int highestResidentialLevel;
  final int residentialFloorToFloorMm;
  final int basementFloorToFloorMm;
  final int groundElevationMm;
}

/// Builds a multi-apartment tower from two semantic/geometric templates.
///
/// The residential template describes one typical apartment floor. The
/// basement template describes one underground service/parking floor. Each
/// output level is a deep domain clone with stable unique ids.
abstract final class ResidentialTowerBuilder {
  static ComposedBuilding build({
    required String buildingId,
    required String buildingName,
    required ComposedBuildingLevel residentialTemplate,
    required ComposedBuildingLevel basementTemplate,
    ResidentialTowerSpec spec = const ResidentialTowerSpec(),
    bool includeStairCore = true,
    bool includeElevatorCore = true,
    bool includeElectricalRiser = true,
    bool includeCableRiser = true,
  }) {
    final basementLevels = BuildingLevelRepeater.repeat(
      source: basementTemplate,
      fromLevel: spec.lowestBasementLevel,
      toLevel: -1,
      baseElevationMm: spec.groundElevationMm +
          spec.lowestBasementLevel * spec.basementFloorToFloorMm,
      floorToFloorHeightMm: spec.basementFloorToFloorMm,
    );

    final residentialLevels = BuildingLevelRepeater.repeat(
      source: residentialTemplate,
      fromLevel: 1,
      toLevel: spec.highestResidentialLevel,
      baseElevationMm: spec.groundElevationMm,
      floorToFloorHeightMm: spec.residentialFloorToFloorMm,
    );

    final levels = [...basementLevels, ...residentialLevels];
    final building = Building(
      id: buildingId,
      name: buildingName,
      levels: [for (final item in levels) item.level],
    );

    final served = levels.map((level) => level.levelNumber).toSet();
    final cores = <VerticalCore>[
      if (includeStairCore)
        VerticalCore(
          id: '$buildingId:stair-core-1',
          name: 'Лестничная клетка 1',
          kind: VerticalCoreKind.stair,
          servedLevelNumbers: served,
        ),
      if (includeElevatorCore)
        VerticalCore(
          id: '$buildingId:elevator-core-1',
          name: 'Лифтовая шахта 1',
          kind: VerticalCoreKind.elevator,
          servedLevelNumbers: served,
        ),
      if (includeElectricalRiser)
        VerticalCore(
          id: '$buildingId:electrical-riser-1',
          name: 'Электрический стояк 1',
          kind: VerticalCoreKind.electricalRiser,
          servedLevelNumbers: served,
        ),
      if (includeCableRiser)
        VerticalCore(
          id: '$buildingId:cable-riser-1',
          name: 'Слаботочный стояк 1',
          kind: VerticalCoreKind.cableRiser,
          servedLevelNumbers: served,
        ),
    ];

    return ComposedBuilding(
      building: building,
      levels: levels,
      verticalCores: cores,
    );
  }
}
