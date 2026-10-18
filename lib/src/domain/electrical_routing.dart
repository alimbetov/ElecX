import 'dart:math' as math;

import 'electrical_placement.dart';
import 'surfaces.dart';

final class ElectricalEndpointRef {
  const ElectricalEndpointRef({required this.componentId, required this.portId});

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

/// A physical cable path from one component port to another.
/// The route may span multiple wall/floor/ceiling surfaces, but endpoints stay
/// bound to engineering components rather than anonymous drawing points.
final class ElectricalCableRoute {
  ElectricalCableRoute({
    required this.id,
    required this.source,
    required this.target,
    required this.segments,
    this.cableType,
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
  final int reservePercent;

  double get geometricLengthMm =>
      segments.fold(0.0, (sum, segment) => sum + segment.lengthMm);

  double get installationLengthMm => geometricLengthMm * (1 + reservePercent / 100);
}

abstract final class ElectricalConnectivityValidator {
  static bool endpointExists({
    required ElectricalEndpointRef endpoint,
    required Iterable<ElectricalComponentPlacement> components,
  }) {
    for (final component in components) {
      if (component.id != endpoint.componentId) continue;
      return component.ports.any((port) => port.id == endpoint.portId);
    }
    return false;
  }

  static bool routeIsConnected({
    required ElectricalCableRoute route,
    required Iterable<ElectricalComponentPlacement> components,
  }) =>
      route.segments.isNotEmpty &&
      endpointExists(endpoint: route.source, components: components) &&
      endpointExists(endpoint: route.target, components: components);
}
