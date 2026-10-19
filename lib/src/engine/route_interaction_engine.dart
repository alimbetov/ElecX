import 'dart:math' as math;

import '../domain/electrical_routing.dart';
import '../domain/hosted_routing.dart';
import '../domain/route_host.dart';
import '../domain/route_medium.dart';
import '../domain/surfaces.dart';
import 'route_flow_visualization.dart';

final class RouteHit {
  const RouteHit({
    required this.routeId,
    required this.segmentIndex,
    required this.distanceMm,
  });

  final String routeId;
  final int segmentIndex;
  final double distanceMm;
}

final class RouteFlowSample {
  const RouteFlowSample({
    required this.hostId,
    required this.xMm,
    required this.yMm,
    required this.reverse,
  });

  final String hostId;
  final double xMm;
  final double yMm;
  final bool reverse;
}

/// Pure geometry/visual interaction logic shared by desktop, tablet and mobile
/// canvases. Rendering is intentionally kept outside this engine.
abstract final class RouteInteractionEngine {
  static RouteHit? hitTestIndoor({
    required Iterable<ElectricalCableRoute> routes,
    required RoomSurfaceRef surface,
    required SurfacePointMm point,
    required double radiusMm,
  }) {
    RouteHit? best;
    for (final route in routes) {
      for (var i = 0; i < route.segments.length; i++) {
        final segment = route.segments[i];
        if (segment.surface != surface || segment.points.length < 2) continue;
        for (var p = 1; p < segment.points.length; p++) {
          final distance = _distanceToSegment(
            point.xMm.toDouble(),
            point.yMm.toDouble(),
            segment.points[p - 1].xMm.toDouble(),
            segment.points[p - 1].yMm.toDouble(),
            segment.points[p].xMm.toDouble(),
            segment.points[p].yMm.toDouble(),
          );
          if (distance <= radiusMm &&
              (best == null || distance < best.distanceMm)) {
            best = RouteHit(
              routeId: route.id,
              segmentIndex: i,
              distanceMm: distance,
            );
          }
        }
      }
    }
    return best;
  }

  /// Host-agnostic hit test used by both room surfaces and outdoor/site maps.
  static RouteHit? hitTestHosted({
    required Iterable<HostedRoutePath> routes,
    required RouteHostRef host,
    required double xMm,
    required double yMm,
    required double radiusMm,
  }) {
    RouteHit? best;
    for (final route in routes) {
      for (var i = 0; i < route.segments.length; i++) {
        final segment = route.segments[i];
        if (segment.host != host || segment.points.length < 2) continue;
        for (var p = 1; p < segment.points.length; p++) {
          final a = segment.points[p - 1];
          final b = segment.points[p];
          final distance = _distanceToSegment(
            xMm,
            yMm,
            a.x.toDouble(),
            a.y.toDouble(),
            b.x.toDouble(),
            b.y.toDouble(),
          );
          if (distance <= radiusMm &&
              (best == null || distance < best.distanceMm)) {
            best = RouteHit(
              routeId: route.routeId,
              segmentIndex: i,
              distanceMm: distance,
            );
          }
        }
      }
    }
    return best;
  }

  static List<RouteHostTransition> transitionsOnHost({
    required HostedRoutePath route,
    required RouteHostRef host,
  }) =>
      List.unmodifiable(
        route.transitions.where(
          (transition) =>
              transition.fromHost == host || transition.toHost == host,
        ),
      );

  static List<RouteFlowSample> flowSamples({
    required HostedRoutePath route,
    required RouteMediumProfile medium,
    required double phase,
  }) {
    final frame = RouteFlowVisualizationPolicy.frame(
      medium: medium,
      phase: phase,
    );
    final lengths = [for (final segment in route.segments) segment.lengthMm];
    final total = lengths.fold(0.0, (a, b) => a + b);
    if (total <= 0) return const [];

    final samples = <RouteFlowSample>[];
    for (final offset in frame.forwardOffsets) {
      final sample = _sampleAt(route, lengths, total * offset, reverse: false);
      if (sample != null) samples.add(sample);
    }
    for (final offset in frame.reverseOffsets) {
      final sample = _sampleAt(route, lengths, total * offset, reverse: true);
      if (sample != null) samples.add(sample);
    }
    return List.unmodifiable(samples);
  }

  static RouteFlowSample? _sampleAt(
    HostedRoutePath route,
    List<double> lengths,
    double target, {
    required bool reverse,
  }) {
    var remaining = target.clamp(0.0, lengths.fold(0.0, (a, b) => a + b));
    for (var i = 0; i < route.segments.length; i++) {
      final segment = route.segments[i];
      final length = lengths[i];
      if (remaining > length && i < route.segments.length - 1) {
        remaining -= length;
        continue;
      }
      if (segment.points.length == 1 || length == 0) {
        final p = segment.points.first;
        return RouteFlowSample(
          hostId: segment.host.id,
          xMm: p.x.toDouble(),
          yMm: p.y.toDouble(),
          reverse: reverse,
        );
      }
      var local = remaining;
      for (var p = 1; p < segment.points.length; p++) {
        final a = segment.points[p - 1];
        final b = segment.points[p];
        final dx = (b.x - a.x).toDouble();
        final dy = (b.y - a.y).toDouble();
        final edge = math.sqrt(dx * dx + dy * dy);
        if (local > edge && p < segment.points.length - 1) {
          local -= edge;
          continue;
        }
        final t = edge == 0 ? 0.0 : (local / edge).clamp(0.0, 1.0);
        return RouteFlowSample(
          hostId: segment.host.id,
          xMm: a.x + dx * t,
          yMm: a.y + dy * t,
          reverse: reverse,
        );
      }
    }
    return null;
  }

  static double _distanceToSegment(
    double px,
    double py,
    double ax,
    double ay,
    double bx,
    double by,
  ) {
    final dx = bx - ax;
    final dy = by - ay;
    final lengthSquared = dx * dx + dy * dy;
    if (lengthSquared == 0) {
      final ox = px - ax;
      final oy = py - ay;
      return math.sqrt(ox * ox + oy * oy);
    }
    final t =
        (((px - ax) * dx + (py - ay) * dy) / lengthSquared).clamp(0.0, 1.0);
    final x = ax + t * dx;
    final y = ay + t * dy;
    final ox = px - x;
    final oy = py - y;
    return math.sqrt(ox * ox + oy * oy);
  }
}
