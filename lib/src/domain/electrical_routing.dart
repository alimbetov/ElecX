import 'dart:math' as math;

import 'boundary_penetration.dart';
import 'electrical_placement.dart';
import 'project_identity.dart';
import 'route_medium.dart';
import 'surfaces.dart';

final class ElectricalEndpointRef {
  const ElectricalEndpointRef({
    required this.componentId,
    required this.portId,
  });

  final String componentId;
  final String portId;
}

final class ElectricalRouteSegment {
  const ElectricalRouteSegment({
    required this.surface,
    required this.points,
    this.anchorIds = const <RouteAnchorId>[],
  }) : assert(anchorIds.length == 0 || anchorIds.length == points.length);

  final RoomSurfaceRef surface;
  final List<SurfacePointMm> points;

  /// Stable identities corresponding 1:1 with [points]. Empty means this is a
  /// legacy route segment that has not yet been migrated to durable anchors.
  /// P7A-5 wall-host persistence must fail closed for interior points in that
  /// state rather than derive identity from segment/point indexes.
  final List<RouteAnchorId> anchorIds;

  bool get hasStableAnchorIdentity =>
      points.isEmpty || anchorIds.length == points.length;

  RouteAnchorId? anchorIdAt(int pointIndex) =>
      anchorIds.isEmpty ? null : anchorIds[pointIndex];

  double get lengthMm {
    var length = 0.0;
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1];
      final b = points[i];
      final dx = (b.xMm - a.xMm).toDouble();
      final dy = (b.yMm - a.yMm).toDouble();
      length += math.sqrt(dx * dx + dy * dy);
    }
    return length;
  }
}

/// A physical routed media path from one engineering port to another.
///
/// Despite the historical class name, the path is not limited to mains power:
/// it can represent AC, DC, Ethernet/PoE, optical fibre, coax, field buses,
/// fire/security loops and project-specific wired media. [medium] carries the
/// engineering/visual semantics while [cableType] keeps the exact conductor or
/// cable specification.
///
/// [penetrations] are part of the physical route aggregate. They carry hidden
/// cable length inside walls/slabs and must therefore survive route mutation,
/// undo/redo and persistence together with the visible surface segments.
final class ElectricalCableRoute {
  ElectricalCableRoute({
    required this.id,
    required this.source,
    required this.target,
    required this.segments,
    this.penetrations = const <BoundaryPenetration>[],
    this.cableType,
    this.medium = RouteMediumProfile.generic,
    this.reservePercent = 5,
  }) {
    if (id.isEmpty) throw ArgumentError('Route id must be non-empty.');
    if (reservePercent < 0) {
      throw ArgumentError.value(reservePercent, 'reservePercent');
    }
    _validatePenetrations();
  }

  final String id;
  final ElectricalEndpointRef source;
  final ElectricalEndpointRef target;
  final List<ElectricalRouteSegment> segments;
  final List<BoundaryPenetration> penetrations;
  final String? cableType;
  final RouteMediumProfile medium;
  final int reservePercent;

  double get visibleLengthMm =>
      segments.fold(0.0, (sum, segment) => sum + segment.lengthMm);

  double get hiddenPenetrationLengthMm => penetrations.fold(
        0.0,
        (sum, penetration) => sum + penetration.routeLengthContributionMm,
      );

  double get geometricLengthMm => visibleLengthMm + hiddenPenetrationLengthMm;

  double get installationLengthMm =>
      geometricLengthMm * (1 + reservePercent / 100);

  ElectricalCableRoute copyWith({
    ElectricalEndpointRef? source,
    ElectricalEndpointRef? target,
    List<ElectricalRouteSegment>? segments,
    List<BoundaryPenetration>? penetrations,
    String? cableType,
    RouteMediumProfile? medium,
    int? reservePercent,
  }) =>
      ElectricalCableRoute(
        id: id,
        source: source ?? this.source,
        target: target ?? this.target,
        segments: segments ?? this.segments,
        penetrations: penetrations ?? this.penetrations,
        cableType: cableType ?? this.cableType,
        medium: medium ?? this.medium,
        reservePercent: reservePercent ?? this.reservePercent,
      );

  void _validatePenetrations() {
    final penetrationIds = <String>{};
    for (final penetration in penetrations) {
      if (penetration.routeId != id) {
        throw ArgumentError(
          'Penetration ${penetration.id} belongs to route '
          '${penetration.routeId}, not $id.',
        );
      }
      if (!penetrationIds.add(penetration.id)) {
        throw ArgumentError('Duplicate penetration id ${penetration.id}.');
      }
      var matchCount = 0;
      for (var index = 0; index + 1 < segments.length; index++) {
        if (_penetrationMatchesTransition(
          penetration,
          segments[index],
          segments[index + 1],
        )) {
          matchCount++;
        }
      }
      if (matchCount != 1) {
        throw ArgumentError(
          'Penetration ${penetration.id} must bind to exactly one adjacent '
          'route-segment transition; found $matchCount.',
        );
      }
    }

    for (var index = 0; index + 1 < segments.length; index++) {
      final before = segments[index];
      final after = segments[index + 1];
      if (before.points.isEmpty || after.points.isEmpty) continue;
      if (before.surface == after.surface) {
        if (before.points.last != after.points.first) {
          throw ArgumentError(
            'Adjacent route segments on the same surface must be contiguous.',
          );
        }
        continue;
      }

      final crossesSpaces = before.surface.spaceId != after.surface.spaceId;
      final floorCeilingPair = (before.surface.type == SurfacePlaneType.floor &&
              after.surface.type == SurfacePlaneType.ceiling) ||
          (before.surface.type == SurfacePlaneType.ceiling &&
              after.surface.type == SurfacePlaneType.floor);
      if (!crossesSpaces && !floorCeilingPair) continue;

      final hasPhysicalTransition = penetrations.any(
        (penetration) =>
            _penetrationMatchesTransition(penetration, before, after),
      );
      if (!hasPhysicalTransition) {
        throw ArgumentError(
          'Route $id crosses a physical boundary without a penetration.',
        );
      }
    }
  }

  static bool _penetrationMatchesTransition(
    BoundaryPenetration penetration,
    ElectricalRouteSegment before,
    ElectricalRouteSegment after,
  ) {
    if (before.points.isEmpty || after.points.isEmpty) return false;
    return penetration.entryAnchor.surface == before.surface &&
        penetration.entryAnchor.point == before.points.last &&
        penetration.exitAnchor.surface == after.surface &&
        penetration.exitAnchor.point == after.points.first;
  }
}

abstract final class ElectricalPortCompatibility {
  static bool areCompatible(
    ElectricalPortKind source,
    ElectricalPortKind target,
  ) =>
      switch (source) {
        ElectricalPortKind.powerOut => target == ElectricalPortKind.powerIn,
        ElectricalPortKind.controlOut => target == ElectricalPortKind.controlIn,
        _ => false,
      };

  static ElectricalPortDefinition? portForEndpoint({
    required ElectricalEndpointRef endpoint,
    required Iterable<ElectricalComponentPlacement> components,
  }) {
    for (final component in components) {
      if (component.id != endpoint.componentId) continue;
      for (final port in component.ports) {
        if (port.id == endpoint.portId) return port;
      }
      return null;
    }
    return null;
  }
}

abstract final class ElectricalConnectivityValidator {
  static bool endpointExists({
    required ElectricalEndpointRef endpoint,
    required Iterable<ElectricalComponentPlacement> components,
  }) =>
      ElectricalPortCompatibility.portForEndpoint(
        endpoint: endpoint,
        components: components,
      ) !=
      null;

  static bool routeIsPhysicallyAnchored({
    required ElectricalCableRoute route,
    required Iterable<ElectricalComponentPlacement> components,
  }) {
    if (route.segments.isEmpty ||
        route.segments.first.points.isEmpty ||
        route.segments.last.points.isEmpty) {
      return false;
    }
    ElectricalComponentPlacement? sourceComponent;
    ElectricalComponentPlacement? targetComponent;
    for (final component in components) {
      if (component.id == route.source.componentId) sourceComponent = component;
      if (component.id == route.target.componentId) targetComponent = component;
    }
    if (sourceComponent == null || targetComponent == null) return false;
    return route.segments.first.surface == sourceComponent.surface &&
        route.segments.first.points.first == sourceComponent.position &&
        route.segments.last.surface == targetComponent.surface &&
        route.segments.last.points.last == targetComponent.position;
  }

  static bool routeIsConnected({
    required ElectricalCableRoute route,
    required Iterable<ElectricalComponentPlacement> components,
  }) {
    if (route.segments.isEmpty) return false;
    final source = ElectricalPortCompatibility.portForEndpoint(
      endpoint: route.source,
      components: components,
    );
    final target = ElectricalPortCompatibility.portForEndpoint(
      endpoint: route.target,
      components: components,
    );
    return source != null &&
        target != null &&
        ElectricalPortCompatibility.areCompatible(source.kind, target.kind);
  }
}
