import 'package:elecx/src/domain/cottage_site_builder.dart';
import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/project_model.dart';
import 'package:elecx/src/domain/site_typology.dart';
import 'package:flutter_test/flutter_test.dart';

Building _typicalHouse() {
  final room = EngineeringSpace(
    id: 'living-room',
    name: 'Гостиная',
    type: SpaceType.room,
    boundary:
        MmPolygon.rectangle(const MmPoint(0, 0), const MmPoint(6000, 5000)),
    referenceFrame: const RoomReferenceFrame(origin: MmPoint(3000, 2500)),
  );
  final corridor = EngineeringSpace(
    id: 'corridor',
    name: 'Коридор',
    type: SpaceType.corridor,
    boundary:
        MmPolygon.rectangle(const MmPoint(6000, 0), const MmPoint(8000, 5000)),
    referenceFrame: const RoomReferenceFrame(origin: MmPoint(7000, 2500)),
  );
  return Building(
    id: 'house-template',
    name: 'Дом',
    levels: [
      BuildingLevel(
        id: 'level-1',
        name: 'Этаж 1',
        elevationMm: 0,
        spaces: [room, corridor],
      ),
    ],
  );
}

void main() {
  test('detached house is represented as one lot and one building', () {
    final site = CottageSiteBuilder.detachedHouse(
      house: _typicalHouse(),
      lotBoundary: MmPolygon.rectangle(
        const MmPoint(0, 0),
        const MmPoint(25000, 40000),
      ),
    );

    expect(site.typology, SiteTypology.detachedHouse);
    expect(site.site.buildings, hasLength(1));
    expect(site.lots, hasLength(1));
  });

  test('village clones houses with unique building level and room ids', () {
    final site = CottageSiteBuilder.village(
      typicalHouse: _typicalHouse(),
      houseCount: 12,
      lotWidthMm: 25000,
      lotDepthMm: 40000,
      columns: 4,
    );

    expect(site.typology, SiteTypology.cottageVillage);
    expect(site.site.buildings, hasLength(12));
    expect(site.lots, hasLength(12));
    expect(site.networks, hasLength(3));

    final buildingIds = site.site.buildings.map((b) => b.id).toSet();
    expect(buildingIds, hasLength(12));

    final roomIds = <String>{};
    for (final building in site.site.buildings) {
      for (final level in building.levels) {
        for (final space in level.spaces) {
          expect(roomIds.add(space.id), isTrue);
        }
      }
    }
  });

  test('shared networks serve every cottage in the village', () {
    final site = CottageSiteBuilder.village(
      typicalHouse: _typicalHouse(),
      houseCount: 8,
      lotWidthMm: 22000,
      lotDepthMm: 35000,
    );
    final buildingIds = site.site.buildings.map((b) => b.id).toSet();

    for (final network in site.networks) {
      expect(network.servedBuildingIds, buildingIds);
    }
  });
}
