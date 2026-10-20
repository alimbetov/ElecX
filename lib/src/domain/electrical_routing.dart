import 'dart:math' as math;

import 'electrical_placement.dart';
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
  const ElectricalRouteSegment({required this.surface, required this.points});

  final RoomSurfaceRef surface;
  final List<SurfacePointMm> points;

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
final class ElectricalCableRoute {
  ElectricalCableRoute({
    required this.id,
    required this.source,
    required this.target,
    required this.segments,
    this.cableType,
    this.medium = RouteMediumProfile.generic,
    this.reservePercent = 5,
  }) {
    if (id.isEmpty) throw ArgumentError('Route id must be non-empty.');
    if (reservePercent < 0) {
      throw ArgumentError.value(reservePercent, 'reservePercent');
    }
  }

  final String id;
  final ElectricalEndpointRef source;
  final ElectricalEndpointRef target;
  final List<ElectricalRouteSegment> segments;
  final String? cableType;
  final RouteMediumProfile medium;
  final int reservePercent;

  double get geometricLengthMm =>
      segments.fold(0.0, (sum, segment) => sum + segment.lengthMm);

  double get installationLengthMm =>
      geometricLengthMm * (1 + reservePercent / 100);
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
