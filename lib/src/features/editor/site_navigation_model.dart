import '../../domain/building_composition.dart';
import '../../domain/project_model.dart';
import '../../domain/site_outdoor_model.dart';
import '../../domain/site_typology.dart';

enum NavigatorNodeKind {
  site,
  outdoorZone,
  lot,
  building,
  level,
  zone,
  room,
  surface,
  network,
}

final class NavigatorNode {
  const NavigatorNode({
    required this.id,
    required this.label,
    required this.kind,
    this.subtitle,
    this.children = const [],
    this.levelNumber,
    this.targetId,
  });

  final String id;
  final String label;
  final NavigatorNodeKind kind;
  final String? subtitle;
  final List<NavigatorNode> children;
  final int? levelNumber;
  final String? targetId;

  NavigatorNode? find(String nodeId) {
    if (id == nodeId) return this;
    for (final child in children) {
      final found = child.find(nodeId);
      if (found != null) return found;
    }
    return null;
  }

  List<NavigatorNode> pathTo(String nodeId) {
    if (id == nodeId) return [this];
    for (final child in children) {
      final path = child.pathTo(nodeId);
      if (path.isNotEmpty) return [this, ...path];
    }
    return const [];
  }
}

abstract final class SiteNavigationProjection {
  static NavigatorNode apartmentTower({
    required String siteName,
    required ComposedBuilding building,
    required List<OutdoorZone> outdoorZones,
  }) {
    return NavigatorNode(
      id: 'site',
      label: siteName,
      kind: NavigatorNodeKind.site,
      children: [
        for (final outdoor in outdoorZones)
          NavigatorNode(
            id: 'outdoor:${outdoor.id}',
            label: outdoor.name,
            kind: NavigatorNodeKind.outdoorZone,
            targetId: outdoor.id,
            subtitle: _outdoorLabel(outdoor.kind),
          ),
        NavigatorNode(
          id: 'building:${building.building.id}',
          label: building.building.name,
          kind: NavigatorNodeKind.building,
          targetId: building.building.id,
          children: [
            for (final level in building.orderedLevels.reversed)
              _levelNode(level),
          ],
        ),
      ],
    );
  }

  static NavigatorNode cottageSite(ComposedSite site) {
    final buildings = {for (final building in site.site.buildings) building.id: building};
    return NavigatorNode(
      id: 'site:${site.id}',
      label: site.name,
      kind: NavigatorNodeKind.site,
      children: [
        for (final outdoor in site.outdoorZones)
          NavigatorNode(
            id: 'outdoor:${outdoor.id}',
            label: outdoor.name,
            kind: NavigatorNodeKind.outdoorZone,
            targetId: outdoor.id,
            subtitle: _outdoorLabel(outdoor.kind),
          ),
        for (final lot in site.lots)
          NavigatorNode(
            id: 'lot:${lot.id}',
            label: lot.name,
            kind: NavigatorNodeKind.lot,
            targetId: lot.id,
            subtitle: _lotLabel(lot.kind),
            children: [
              for (final buildingId in lot.buildingIds)
                if (buildings[buildingId] case final building?)
                  _simpleBuildingNode(building),
            ],
          ),
        if (site.networks.isNotEmpty)
          NavigatorNode(
            id: 'site-networks',
            label: 'Общие сети',
            kind: NavigatorNodeKind.network,
            children: [
              for (final network in site.networks)
                NavigatorNode(
                  id: 'network:${network.id}',
                  label: network.name,
                  kind: NavigatorNodeKind.network,
                  targetId: network.id,
                  subtitle: network.kind.name,
                ),
            ],
          ),
      ],
    );
  }

  static NavigatorNode _levelNode(ComposedBuildingLevel level) {
    final spaces = {for (final space in level.level.spaces) space.id: space};
    final claimed = <String>{};
    final zoneNodes = <NavigatorNode>[];

    for (final zone in level.zones) {
      claimed.addAll(zone.spaceIds);
      zoneNodes.add(
        NavigatorNode(
          id: 'level:${level.levelNumber}:zone:${zone.id}',
          label: zone.kind == BuildingZoneKind.apartment
              ? 'Квартира ${zone.apartmentNumber}'
              : zone.name,
          kind: NavigatorNodeKind.zone,
          targetId: zone.id,
          subtitle: _zoneLabel(zone.kind),
          children: [
            for (final spaceId in zone.spaceIds)
              if (spaces[spaceId] case final space?) _roomNode(space),
          ],
        ),
      );
    }

    final ungrouped = level.level.spaces.where((space) => !claimed.contains(space.id));
    return NavigatorNode(
      id: 'level:${level.levelNumber}',
      label: level.displayName,
      kind: NavigatorNodeKind.level,
      levelNumber: level.levelNumber,
      targetId: level.level.id,
      subtitle: '${level.level.elevationMm} mm',
      children: [
        ...zoneNodes,
        for (final space in ungrouped) _roomNode(space),
      ],
    );
  }

  static NavigatorNode _simpleBuildingNode(Building building) => NavigatorNode(
        id: 'building:${building.id}',
        label: building.name,
        kind: NavigatorNodeKind.building,
        targetId: building.id,
        children: [
          for (var i = 0; i < building.levels.length; i++)
            NavigatorNode(
              id: 'building:${building.id}:level:${building.levels[i].id}',
              label: building.levels[i].name,
              kind: NavigatorNodeKind.level,
              targetId: building.levels[i].id,
              subtitle: '${building.levels[i].elevationMm} mm',
              children: [
                for (final space in building.levels[i].spaces) _roomNode(space),
              ],
            ),
        ],
      );

  static NavigatorNode _roomNode(EngineeringSpace space) => NavigatorNode(
        id: 'room:${space.id}',
        label: space.name,
        kind: NavigatorNodeKind.room,
        targetId: space.id,
        subtitle: _spaceLabel(space.type),
      );

  static String _zoneLabel(BuildingZoneKind kind) => switch (kind) {
        BuildingZoneKind.apartment => 'Квартира',
        BuildingZoneKind.common => 'Общая зона',
        BuildingZoneKind.technical => 'Техническая зона',
        BuildingZoneKind.parking => 'Паркинг',
        BuildingZoneKind.storage => 'Кладовые',
        BuildingZoneKind.utility => 'Сервисная зона',
      };

  static String _spaceLabel(SpaceType type) => switch (type) {
        SpaceType.room => 'Помещение',
        SpaceType.corridor => 'Коридор',
        SpaceType.hall => 'Холл',
        SpaceType.technicalRoom => 'Техническое помещение',
        SpaceType.stair => 'Лестница',
        SpaceType.shaft => 'Шахта',
        SpaceType.outdoorArea => 'Наружная зона',
      };

  static String _outdoorLabel(OutdoorZoneKind kind) => switch (kind) {
        OutdoorZoneKind.yard => 'Двор',
        OutdoorZoneKind.driveway => 'Проезд',
        OutdoorZoneKind.pedestrian => 'Пешеходная зона',
        OutdoorZoneKind.parking => 'Парковка',
        OutdoorZoneKind.playground => 'Площадка',
        OutdoorZoneKind.landscape => 'Ландшафт',
        OutdoorZoneKind.technical => 'Техническая зона',
        OutdoorZoneKind.transformerArea => 'Трансформаторная зона',
        OutdoorZoneKind.generatorArea => 'Генераторная зона',
        OutdoorZoneKind.solarArea => 'Солнечная генерация',
      };

  static String _lotLabel(PropertyLotKind kind) => switch (kind) {
        PropertyLotKind.detachedHouse => 'Участок коттеджа',
        PropertyLotKind.townhouseUnit => 'Секция таунхауса',
        PropertyLotKind.commonFacility => 'Общий объект',
        PropertyLotKind.technical => 'Технический участок',
      };
}