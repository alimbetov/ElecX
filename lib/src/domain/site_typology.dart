import 'geometry.dart';
import 'project_model.dart';
import 'site_outdoor_model.dart';

enum SiteTypology {
  apartmentTower,
  detachedHouse,
  townhouseRow,
  cottageVillage,
  mixedUse,
}

enum PropertyLotKind { detachedHouse, townhouseUnit, commonFacility, technical }

/// One legal/functional parcel inside a site. Geometry is expressed in the
/// same integer-millimetre site coordinate system as outdoor zones/buildings.
final class PropertyLot {
  PropertyLot({
    required this.id,
    required this.name,
    required this.kind,
    required this.boundary,
    required Iterable<String> buildingIds,
    Iterable<String> outdoorZoneIds = const {},
  })  : buildingIds = Set.unmodifiable(buildingIds),
        outdoorZoneIds = Set.unmodifiable(outdoorZoneIds) {
    if (id.isEmpty) {
      throw ArgumentError('Lot id must be non-empty.');
    }
    if (name.isEmpty) {
      throw ArgumentError('Lot name must be non-empty.');
    }
    if (this.buildingIds.isEmpty && kind != PropertyLotKind.technical) {
      throw ArgumentError('Non-technical lot must reference a building.');
    }
  }

  final String id;
  final String name;
  final PropertyLotKind kind;
  final MmPolygon boundary;
  final Set<String> buildingIds;
  final Set<String> outdoorZoneIds;
}

enum SiteNetworkKind {
  electrical,
  lighting,
  lowVoltage,
  data,
  fireAlarm,
  accessControl,
}

/// Shared infrastructure connecting multiple lots/buildings across one site.
final class SiteNetwork {
  SiteNetwork({
    required this.id,
    required this.name,
    required this.kind,
    required Iterable<String> servedBuildingIds,
    this.sourceOutdoorZoneId,
  }) : servedBuildingIds = Set.unmodifiable(servedBuildingIds) {
    if (id.isEmpty) {
      throw ArgumentError('Network id must be non-empty.');
    }
    if (this.servedBuildingIds.isEmpty) {
      throw ArgumentError('Network must serve at least one building.');
    }
  }

  final String id;
  final String name;
  final SiteNetworkKind kind;
  final Set<String> servedBuildingIds;
  final String? sourceOutdoorZoneId;
}

/// Semantic composition for a whole site: tower, one cottage, townhouse row,
/// or a complete cottage village. It intentionally reuses [Building],
/// [OutdoorZone] and the same spatial coordinate system.
final class ComposedSite {
  ComposedSite({
    required this.id,
    required this.name,
    required this.typology,
    required this.site,
    this.outdoorZones = const [],
    this.lots = const [],
    this.networks = const [],
  }) {
    if (id.isEmpty) {
      throw ArgumentError('Site id must be non-empty.');
    }
    final buildingIds = site.buildings.map((b) => b.id).toSet();
    final zoneIds = outdoorZones.map((z) => z.id).toSet();
    final lotIds = <String>{};
    for (final lot in lots) {
      if (!lotIds.add(lot.id)) {
        throw ArgumentError('Duplicate lot id ${lot.id}.');
      }
      if (!lot.buildingIds.every(buildingIds.contains)) {
        throw ArgumentError('Lot ${lot.id} references unknown building.');
      }
      if (!lot.outdoorZoneIds.every(zoneIds.contains)) {
        throw ArgumentError('Lot ${lot.id} references unknown outdoor zone.');
      }
    }
    for (final network in networks) {
      if (!network.servedBuildingIds.every(buildingIds.contains)) {
        throw ArgumentError(
          'Network ${network.id} references unknown building.',
        );
      }
      final source = network.sourceOutdoorZoneId;
      if (source != null && !zoneIds.contains(source)) {
        throw ArgumentError(
          'Network ${network.id} references unknown source zone.',
        );
      }
    }
  }

  final String id;
  final String name;
  final SiteTypology typology;
  final ProjectSite site;
  final List<OutdoorZone> outdoorZones;
  final List<PropertyLot> lots;
  final List<SiteNetwork> networks;
}
