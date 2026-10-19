import 'package:elecx/src/domain/building_composition.dart';
import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/project_model.dart';
import 'package:elecx/src/domain/residential_tower_builder.dart';
import 'package:flutter_test/flutter_test.dart';

EngineeringSpace _space(
  String id,
  String name,
  int left,
  int bottom,
  int right,
  int top, {
  SpaceType type = SpaceType.room,
}) {
  final boundary = MmPolygon.rectangle(
    MmPoint(left, bottom),
    MmPoint(right, top),
  );
  return EngineeringSpace(
    id: id,
    name: name,
    type: type,
    boundary: boundary,
    referenceFrame: RoomReferenceFrame(origin: boundary.bounds.center),
  );
}

ComposedBuildingLevel _residentialTemplate() {
  final spaces = [
    _space('a1-living', 'Кухня-гостиная', 0, 0, 5000, 4000),
    _space('a1-bedroom', 'Спальня', 0, 4000, 3500, 7000),
    _space('a1-bathroom', 'Санузел', 3500, 4000, 5000, 6000),
    _space('a2-living', 'Кухня-гостиная', 7000, 0, 12000, 4000),
    _space('a2-bedroom', 'Спальня', 8500, 4000, 12000, 7000),
    _space('a2-bathroom', 'Санузел', 7000, 4000, 8500, 6000),
    _space(
      'common-corridor',
      'Общий коридор',
      5000,
      0,
      7000,
      7000,
      type: SpaceType.corridor,
    ),
  ];
  final level = BuildingLevel(
    id: 'residential-template',
    name: 'Типовой жилой этаж',
    elevationMm: 0,
    spaces: spaces,
  );
  return ComposedBuildingLevel(
    level: level,
    levelNumber: 1,
    kind: BuildingLevelKind.residential,
    zones: [
      BuildingZone(
        id: 'apt-a1',
        name: 'Квартира A1',
        kind: BuildingZoneKind.apartment,
        apartmentNumber: '01',
        spaceIds: const {'a1-living', 'a1-bedroom', 'a1-bathroom'},
      ),
      BuildingZone(
        id: 'apt-a2',
        name: 'Квартира A2',
        kind: BuildingZoneKind.apartment,
        apartmentNumber: '02',
        spaceIds: const {'a2-living', 'a2-bedroom', 'a2-bathroom'},
      ),
      BuildingZone(
        id: 'common',
        name: 'МОП',
        kind: BuildingZoneKind.common,
        spaceIds: const {'common-corridor'},
      ),
    ],
  );
}

ComposedBuildingLevel _basementTemplate() {
  final spaces = [
    _space(
      'parking',
      'Паркинг',
      0,
      0,
      12000,
      8000,
      type: SpaceType.hall,
    ),
    _space(
      'electrical-room',
      'Электрощитовая',
      12000,
      0,
      15000,
      3500,
      type: SpaceType.technicalRoom,
    ),
  ];
  final level = BuildingLevel(
    id: 'basement-template',
    name: 'Типовой подземный этаж',
    elevationMm: -3300,
    spaces: spaces,
  );
  return ComposedBuildingLevel(
    level: level,
    levelNumber: -1,
    kind: BuildingLevelKind.basement,
    floorToFloorHeightMm: 3300,
    zones: [
      BuildingZone(
        id: 'parking-zone',
        name: 'Паркинг',
        kind: BuildingZoneKind.parking,
        spaceIds: const {'parking'},
      ),
      BuildingZone(
        id: 'technical-zone',
        name: 'Технические помещения',
        kind: BuildingZoneKind.technical,
        spaceIds: const {'electrical-room'},
      ),
    ],
  );
}

void main() {
  test('tower supports B30 through residential floor 16', () {
    final tower = ResidentialTowerBuilder.build(
      buildingId: 'tower-a',
      buildingName: '16-этажный дом',
      residentialTemplate: _residentialTemplate(),
      basementTemplate: _basementTemplate(),
    );

    expect(tower.levels, hasLength(46));
    expect(tower.orderedLevels.first.levelNumber, -30);
    expect(tower.orderedLevels.last.levelNumber, 16);
    expect(tower.levelByNumber(-30)!.displayName, 'B30');
    expect(tower.levelByNumber(-1)!.displayName, 'B1');
    expect(tower.levelByNumber(16)!.displayName, '16');

    expect(tower.levelByNumber(-30)!.level.elevationMm, -99000);
    expect(tower.levelByNumber(-1)!.level.elevationMm, -3300);
    expect(tower.levelByNumber(1)!.level.elevationMm, 0);
    expect(tower.levelByNumber(16)!.level.elevationMm, 45000);
  });

  test('every residential floor owns independent apartments and room ids', () {
    final tower = ResidentialTowerBuilder.build(
      buildingId: 'tower-a',
      buildingName: '16-этажный дом',
      residentialTemplate: _residentialTemplate(),
      basementTemplate: _basementTemplate(),
    );

    final floor7 = tower.levelByNumber(7)!;
    final floor8 = tower.levelByNumber(8)!;

    expect(floor7.apartments, hasLength(2));
    expect(floor8.apartments, hasLength(2));
    expect(
      floor7.apartments.first.apartmentNumber,
      isNot(floor8.apartments.first.apartmentNumber),
    );

    final floor7Ids = floor7.level.spaces.map((space) => space.id).toSet();
    final floor8Ids = floor8.level.spaces.map((space) => space.id).toSet();
    expect(floor7Ids.intersection(floor8Ids), isEmpty);

    final apartment = floor7.apartments.first;
    expect(apartment.spaceIds, hasLength(3));
    expect(apartment.spaceIds.every(floor7Ids.contains), isTrue);
  });

  test('vertical cores span every level from B30 to 16', () {
    final tower = ResidentialTowerBuilder.build(
      buildingId: 'tower-a',
      buildingName: '16-этажный дом',
      residentialTemplate: _residentialTemplate(),
      basementTemplate: _basementTemplate(),
    );

    expect(tower.verticalCores, hasLength(4));
    for (final core in tower.verticalCores) {
      expect(core.servedLevelNumbers, hasLength(46));
      expect(core.servedLevelNumbers.contains(-30), isTrue);
      expect(core.servedLevelNumbers.contains(16), isTrue);
    }
  });

  test('one space cannot belong to two apartment/common zones', () {
    final room = _space('room-1', 'Комната', 0, 0, 3000, 3000);
    final level = BuildingLevel(
      id: 'level-1',
      name: 'Этаж 1',
      elevationMm: 0,
      spaces: [room],
    );

    expect(
      () => ComposedBuildingLevel(
        level: level,
        levelNumber: 1,
        kind: BuildingLevelKind.residential,
        zones: [
          BuildingZone(
            id: 'apt-1',
            name: 'Квартира 1',
            kind: BuildingZoneKind.apartment,
            apartmentNumber: '1',
            spaceIds: const {'room-1'},
          ),
          BuildingZone(
            id: 'common',
            name: 'МОП',
            kind: BuildingZoneKind.common,
            spaceIds: const {'room-1'},
          ),
        ],
      ),
      throwsArgumentError,
    );
  });
}
