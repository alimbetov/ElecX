import 'dart:math' as math;

import 'electrical_routing.dart';
import 'geometry.dart';
import 'route_host.dart';
import 'route_medium.dart';

final class HostedRouteSegment {
  HostedRouteSegment({required this.host, required Iterable<MmPoint> points})
      : points = List.unmodifiable(points) {
    if (this.points.isEmpty) {
      throw ArgumentError('Hosted route segment requires at least one point.');
    }
  }

  final RouteHostRef host;
  final List<MmPoint> points;

  double get lengthMm {
    var result = 0.0;
    for (var i = 1; i < points.length; i++) {
      final dx = (points[i].x - points[i - 1].x).toDouble();
      final dy = (points[i].y - points[i - 1].y).toDouble();
      result += math.sqrt(dx * dx + dy * dy);
    }
    return result;
  }
}

/// One continuous physical path which may cross room surfaces, building
/// service entries and outdoor/site zones without changing its route identity.
final class HostedRoutePath {
  HostedRoutePath({
    required this.routeId,
    required Iterable<HostedRouteSegment> segments,
    this.transitions = const [],
    this.medium = RouteMediumProfile.generic,
  }) : segments = List.unmodifiable(segments) {
    if (routeId.isEmpty) throw ArgumentError('Route id must be non-empty.');
    if (this.segments.isEmpty) {
      throw ArgumentError('Hosted route path requires at least one segment.');
    }
  }

  final String routeId;
  final List<HostedRouteSegment> segments;
  final List<RouteHostTransition> transitions;
  final RouteMediumProfile medium;

  double get lengthMm =>
      segments.fold(0.0, (sum, segment) => sum + segment.lengthMm);

  bool get crossesBuildingEnvelope => transitions.any(
        (transition) => transition.fromHost.kind != transition.toHost.kind,
      );

  Iterable<RouteHostRef> get hosts sync* {
    final seen = <String>{};
    for (final segment in segments) {
      if (seen.add(segment.host.id)) yield segment.host;
    }
  }
}

/// Compatibility adapter for the current room-surface route model. New route
/// authoring can progressively migrate to [HostedRoutePath] without forcing a
/// flag-day rewrite of topology, simulation and persistence.
abstract final class HostedRouteAdapter {
  static HostedRoutePath fromIndoor(ElectricalCableRoute route) =>
      HostedRoutePath(
        routeId: route.id,
        medium: route.medium,
        segments: [
          for (final segment in route.segments)
            HostedRouteSegment(
              host: RouteHostRef.indoor(segment.surface),
              points: [
                for (final point in segment.points)
                  MmPoint(point.xMm, point.yMm),
              ],
            ),
        ],
        transitions: [
          for (final penetration in route.penetrations)
            RouteHostTransition(
              // Keep the domain penetration identity intact so presentation
              // can correlate the marker with the physical aggregate.
              id: penetration.id,
              kind: RouteHostTransitionKind.roomPenetration,
              fromHost: RouteHostRef.indoor(
                penetration.entryAnchor.surface,
              ),
              fromPoint: MmPoint(
                penetration.entryAnchor.point.xMm,
                penetration.entryAnchor.point.yMm,
              ),
              toHost: RouteHostRef.indoor(
                penetration.exitAnchor.surface,
              ),
              toPoint: MmPoint(
                penetration.exitAnchor.point.xMm,
                penetration.exitAnchor.point.yMm,
              ),
              requiresPenetration: true,
            ),
        ],
      );
}
