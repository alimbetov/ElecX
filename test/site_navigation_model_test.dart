import 'package:elecx/src/domain/building_composition.dart';
import 'package:elecx/src/domain/cottage_site_builder.dart';
import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/project_model.dart';
import 'package:elecx/src/domain/residential_tower_builder.dart';
import 'package:elecx/src/domain/site_outdoor_model.dart';
import 'package:elecx/src/features/editor/site_navigation_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tower projection exposes yard levels apartments common and rooms', () {
    final residential = _residentialTemplate();
    final basement = _basementTemplate();
    final tower = ResidentialTowerBuilder.build(
      buildingId: 'tower-a',
      buildingName: 'Tower A',
      residentialTemplate: residential,
      basementTemplate: basement,
      spec: const ResidentialTowerSpec(
        lowestBasementLevel: -30,
        highestResidentialLevel: 16,
      ),
    );
    final yard = OutdoorZone(
      id: 'yard',
      name: 'Двор',
      kind: OutdoorZoneKind.yard,
      boundary: MmPolygon.rectangle(
        const MmPoint(-10000, -10000),
        const MmPoint(40000, 30000),
      ),
    );

    final root = SiteNavigationProjection.apartmentTower(
      siteName: 'Площадка',
      building: tower,
      outdoorZones: [yard],
    );

    expect(root.find('outdoor:yard'), isNotNull);
    expect(root.find('level:16'), isNotNull);
    expect(root.find('level:-30'), isNotNull);
    final level7 = root.find('level:7')!;
    expect(
      level7.children.any((node) => node.label.contains('Квартира')),
      isTrue,
    );
    expect(level7.children.any((node) => node.label == 'МОП'), isTrue);
    expect(root.pathTo('room:L7:apt01-room').map((node) => node.kind), [
      NavigatorNodeKind.site,
      NavigatorNodeKind.building,
      NavigatorNodeKind.level,
      NavigatorNodeKind.zone,
      NavigatorNodeKind.room,
    ]);
  });

  test(
    'cottage village projection exposes lots houses levels rooms and networks',
    () {
      final house = Building(
        id: 'template-house',
        name: 'Дом',
        levels: [
          BuildingLevel(
            id: 'floor-1',
            name: 'Этаж 1',
            elevationMm: 0,
            spaces: [_space('living', 'Гостиная', 0, 0, 5000, 4000)],
          ),
        ],
      );
      final site = CottageSiteBuilder.village(
        typicalHouse: house,
        houseCount: 12,
        lotWidthMm: 20000,
        lotDepthMm: 30000,
      );

      final root = SiteNavigationProjection.cottageSite(site);

      expect(root.find('lot:lot-1'), isNotNull);
      expect(root.find('building:house-12'), isNotNull);
      expect(root.find('room:H7:living'), isNotNull);
      expect(root.find('network:network-electrical'), isNotNull);
      expect(root.pathTo('room:H7:living').map((node) => node.kind), [
        NavigatorNodeKind.site,
        NavigatorNodeKind.lot,
        NavigatorNodeKind.building,
        NavigatorNodeKind.level,
        NavigatorNodeKind.room,
      ]);
    },
  );
}

ComposedBuildingLevel _residentialTemplate() {
  final room = _space('apt01-room', 'Комната 01', 0, 0, 5000, 4000);
  final corridor = _space(
    'common-corridor',
    'Общий коридор',
    5000,
    0,
    7000,
    4000,
    type: SpaceType.corridor,
  );
  return ComposedBuildingLevel(
    level: BuildingLevel(
      id: 'residential',
      name: 'Типовой этаж',
      elevationMm: 0,
      spaces: [room, corridor],
    ),
    levelNumber: 1,
    kind: BuildingLevelKind.residential,
    zones: [
      BuildingZone(
        id: 'apt01',
        name: 'Квартира 01',
        kind: BuildingZoneKind.apartment,
        apartmentNumber: '01',
        spaceIds: const {'apt01-room'},
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
  final technical = _space(
    'technical',
    'Технический коридор',
    0,
    0,
    7000,
    3000,
    type: SpaceType.corridor,
  );
  return ComposedBuildingLevel(
    level: BuildingLevel(
      id: 'basement',
      name: 'Подвал',
      elevationMm: -3300,
      spaces: [technical],
    ),
    levelNumber: -1,
    kind: BuildingLevelKind.basement,
    zones: [
      BuildingZone(
        id: 'technical-zone',
        name: 'Техническая зона',
        kind: BuildingZoneKind.technical,
        spaceIds: const {'technical'},
      ),
    ],
  );
}

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
