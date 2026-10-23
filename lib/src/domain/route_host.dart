import 'geometry.dart';
import 'project_identity.dart';
import 'site_outdoor_model.dart';
import 'surfaces.dart';

export 'surfaces.dart' show RoomSurfaceRef, SurfacePlaneType;

enum RouteHostKind { indoorSurface, outdoorZone }

/// Stable reference to any 2D host on which a wired route may be drawn.
///
/// Indoor hosts use room-local surface coordinates. Outdoor hosts use site
/// millimetre coordinates directly. The route engine can therefore preserve
/// one logical route while crossing building surfaces, facade/service entries
/// and outdoor zones.
final class RouteHostRef {
  const RouteHostRef._({
    required this.kind,
    required this.id,
    this.surface,
    this.outdoorZoneId,
  });

  factory RouteHostRef.indoor(RoomSurfaceRef surface) => RouteHostRef._(
        kind: RouteHostKind.indoorSurface,
        id: 'indoor:${surface.id}',
        surface: surface,
      );

  factory RouteHostRef.outdoor(String outdoorZoneId) {
    if (outdoorZoneId.isEmpty) {
      throw ArgumentError('Outdoor zone id must be non-empty.');
    }
    return RouteHostRef._(
      kind: RouteHostKind.outdoorZone,
      id: 'outdoor:$outdoorZoneId',
      outdoorZoneId: outdoorZoneId,
    );
  }

  final RouteHostKind kind;
  final String id;
  final RoomSurfaceRef? surface;
  final String? outdoorZoneId;

  @override
  bool operator ==(Object other) => other is RouteHostRef && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

enum RouteHostTransitionKind {
  surfaceAdjacency,
  roomPenetration,
  levelPenetration,
  buildingServiceEntry,
  cableEntry,
  externalPowerSource,
  lightingFeed,
}

/// One physical route-continuation point represented on two route hosts.
final class RouteHostTransition {
  const RouteHostTransition({
    required this.id,
    required this.kind,
    required this.fromHost,
    required this.fromPoint,
    required this.toHost,
    required this.toPoint,
    this.requiresPenetration = false,
    this.siteConnectionId,
    this.slabId,
  }) : assert(
          kind == RouteHostTransitionKind.levelPenetration
              ? slabId != null
              : slabId == null,
          'Only levelPenetration transitions may carry a SlabId, and they '
          'must carry one.',
        );

  final String id;
  final RouteHostTransitionKind kind;
  final RouteHostRef fromHost;
  final MmPoint fromPoint;
  final RouteHostRef toHost;
  final MmPoint toPoint;
  final bool requiresPenetration;
  final String? siteConnectionId;

  /// Stable physical slab ownership for an inter-level continuation marker.
  /// Wall penetrations and outdoor transitions intentionally keep this null.
  final SlabId? slabId;
}

abstract final class SiteRouteTransitionResolver {
  /// Converts declared [SiteBuildingConnection] records into canonical route
  /// transitions between an outdoor zone and the target building surface.
  ///
  /// [resolveIndoorHost] deliberately stays injectable: the project may route
  /// an entry onto a floor, wall, technical room or dedicated service surface.
  static List<RouteHostTransition> fromConnections({
    required ComposedProjectSite project,
    required RouteHostRef Function(SiteBuildingConnection connection)
        resolveIndoorHost,
  }) {
    final zoneIds = project.outdoorZones.map((zone) => zone.id).toSet();
    final result = <RouteHostTransition>[];
    for (final connection in project.connections) {
      if (!zoneIds.contains(connection.outdoorZoneId)) continue;
      final outdoor = RouteHostRef.outdoor(connection.outdoorZoneId);
      final indoor = resolveIndoorHost(connection);
      final kind = switch (connection.kind) {
        SiteConnectionKind.buildingEntrance =>
          RouteHostTransitionKind.buildingServiceEntry,
        SiteConnectionKind.electricalServiceEntry =>
          RouteHostTransitionKind.buildingServiceEntry,
        SiteConnectionKind.cableEntry => RouteHostTransitionKind.cableEntry,
        SiteConnectionKind.externalPowerSource =>
          RouteHostTransitionKind.externalPowerSource,
        SiteConnectionKind.lightingFeed => RouteHostTransitionKind.lightingFeed,
      };
      result.add(
        RouteHostTransition(
          id: 'site:${connection.id}',
          kind: kind,
          fromHost: outdoor,
          fromPoint: connection.sitePoint,
          toHost: indoor,
          toPoint: connection.levelPoint,
          siteConnectionId: connection.id,
        ),
      );
    }
    return List.unmodifiable(result);
  }
}
