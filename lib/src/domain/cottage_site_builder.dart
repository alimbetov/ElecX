import 'geometry.dart';
import 'project_model.dart';
import 'site_outdoor_model.dart';
import 'site_typology.dart';

abstract final class CottageSiteBuilder {
  static ComposedSite detachedHouse({
    required Building house,
    required MmPolygon lotBoundary,
    List<OutdoorZone> outdoorZones = const [],
  }) {
    final lot = PropertyLot(
      id: 'lot-1',
      name: 'Участок 1',
      kind: PropertyLotKind.detachedHouse,
      boundary: lotBoundary,
      buildingIds: {house.id},
      outdoorZoneIds: outdoorZones.map((zone) => zone.id),
    );
    final site = ProjectSite(
      id: 'site-house',
      name: 'Участок коттеджа',
      buildings: [house],
    );
    return ComposedSite(
      id: 'composed-site-house',
      name: 'Коттедж',
      typology: SiteTypology.detachedHouse,
      site: site,
      outdoorZones: outdoorZones,
      lots: [lot],
    );
  }

  static ComposedSite village({
    required Building typicalHouse,
    required int houseCount,
    required int lotWidthMm,
    required int lotDepthMm,
    int streetGapMm = 12000,
    int columns = 5,
  }) {
    if (houseCount <= 0) {
      throw ArgumentError.value(houseCount, 'houseCount');
    }
    if (lotWidthMm <= 0 || lotDepthMm <= 0) {
      throw ArgumentError('Lot dimensions must be positive.');
    }
    if (columns <= 0) throw ArgumentError.value(columns, 'columns');

    final buildings = <Building>[];
    final lots = <PropertyLot>[];
    for (var i = 0; i < houseCount; i++) {
      final number = i + 1;
      final row = i ~/ columns;
      final column = i % columns;
      final x = column * lotWidthMm;
      final y = row * (lotDepthMm + streetGapMm);
      final building = _cloneBuilding(typicalHouse, number);
      buildings.add(building);
      lots.add(
        PropertyLot(
          id: 'lot-$number',
          name: 'Участок $number',
          kind: PropertyLotKind.detachedHouse,
          boundary: MmPolygon.rectangle(
            MmPoint(x, y),
            MmPoint(x + lotWidthMm, y + lotDepthMm),
          ),
          buildingIds: {building.id},
        ),
      );
    }

    final site = ProjectSite(
      id: 'site-village',
      name: 'Коттеджный городок',
      buildings: buildings,
    );
    final allBuildingIds = buildings.map((building) => building.id).toSet();
    return ComposedSite(
      id: 'composed-site-village',
      name: 'Коттеджный городок',
      typology: SiteTypology.cottageVillage,
      site: site,
      lots: lots,
      networks: [
        SiteNetwork(
          id: 'network-electrical',
          name: 'Общая сеть электроснабжения',
          kind: SiteNetworkKind.electrical,
          servedBuildingIds: allBuildingIds,
        ),
        SiteNetwork(
          id: 'network-lighting',
          name: 'Наружное освещение',
          kind: SiteNetworkKind.lighting,
          servedBuildingIds: allBuildingIds,
        ),
        SiteNetwork(
          id: 'network-data',
          name: 'Слаботочная сеть',
          kind: SiteNetworkKind.data,
          servedBuildingIds: allBuildingIds,
        ),
      ],
    );
  }

  static Building _cloneBuilding(Building source, int number) {
    final levels = <BuildingLevel>[];
    for (final level in source.levels) {
      final prefix = 'H$number:${level.id}';
      levels.add(
        BuildingLevel(
          id: prefix,
          name: level.name,
          elevationMm: level.elevationMm,
          spaces: [
            for (final space in level.spaces)
              EngineeringSpace(
                id: 'H$number:${space.id}',
                name: space.name,
                type: space.type,
                boundary: space.boundary,
                referenceFrame: space.referenceFrame,
                grid: space.grid,
                wallProfiles: space.wallProfiles,
              ),
          ],
        ),
      );
    }
    return Building(
      id: 'house-$number',
      name: '${source.name} $number',
      levels: levels,
    );
  }
}