import 'geometry.dart';
import 'project_model.dart';

enum OutdoorZoneKind {
  yard,
  driveway,
  pedestrian,
  parking,
  playground,
  landscape,
  technical,
  transformerArea,
  generatorArea,
  solarArea,
}

enum SiteConnectionKind {
  buildingEntrance,
  electricalServiceEntry,
  cableEntry,
  externalPowerSource,
  lightingFeed,
}

/// A physical outdoor area at site level.
///
/// Outdoor zones intentionally reuse millimetre geometry so the same camera,
/// snapping, component placement and routing primitives can later operate on
/// yard plans without introducing another coordinate system.
final class OutdoorZone {
  OutdoorZone({
    required this.id,
    required this.name,
    required this.kind,
    required this.boundary,
    this.grid = const GridDefinition(minorStepMm: 500, majorEvery: 10),
  }) {
    if (id.isEmpty) throw ArgumentError('Outdoor zone id must be non-empty.');
    if (name.isEmpty) throw ArgumentError('Outdoor zone name must be non-empty.');
  }

  final String id;
  final String name;
  final OutdoorZoneKind kind;
  final MmPolygon boundary;
  final GridDefinition grid;
}

/// Explicit topology between a site/outdoor point and a building/level.
///
/// This becomes the legal bridge for routes such as:
/// yard lighting -> cable entry -> B1 switchboard -> electrical riser -> flat.
final class SiteBuildingConnection {
  SiteBuildingConnection({
    required this.id,
    required this.kind,
    required this.outdoorZoneId,
    required this.buildingId,
    required this.levelNumber,
    required this.sitePoint,
    required this.levelPoint,
    this.targetSpaceId,
  }) {
    if (id.isEmpty) throw ArgumentError('Connection id must be non-empty.');
    if (levelNumber < -30 || levelNumber > 200) {
      throw RangeError.range(levelNumber, -30, 200, 'levelNumber');
    }
  }

  final String id;
  final SiteConnectionKind kind;
  final String outdoorZoneId;
  final String buildingId;
  final int levelNumber;
  final MmPoint sitePoint;
  final MmPoint levelPoint;
  final String? targetSpaceId;
}

final class ComposedProjectSite {
  ComposedProjectSite({
    required this.site,
    this.outdoorZones = const [],
    this.connections = const [],
  }) {
    final zoneIds = <String>{};
    for (final zone in outdoorZones) {
      if (!zoneIds.add(zone.id)) {
        throw ArgumentError('Duplicate outdoor zone id ${zone.id}.');
      }
    }
    final buildingIds = site.buildings.map((building) => building.id).toSet();
    final connectionIds = <String>{};
    for (final connection in connections) {
      if (!connectionIds.add(connection.id)) {
        throw ArgumentError('Duplicate site connection id ${connection.id}.');
      }
      if (!zoneIds.contains(connection.outdoorZoneId)) {
        throw ArgumentError(
          'Connection ${connection.id} references unknown outdoor zone '
          '${connection.outdoorZoneId}.',
        );
      }
      if (!buildingIds.contains(connection.buildingId)) {
        throw ArgumentError(
          'Connection ${connection.id} references unknown building '
          '${connection.buildingId}.',
        );
      }
    }
  }

  final ProjectSite site;
  final List<OutdoorZone> outdoorZones;
  final List<SiteBuildingConnection> connections;
}
