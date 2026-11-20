import 'dart:math' as math;

import '../../domain/geometry.dart';

/// Temporary plan dimensions measured from an explicitly identified anchor.
/// No component footprint is implied by these values.
enum WallGuideDirection { left, right, down, up }

final class WallDistanceGuide {
  const WallDistanceGuide({
    required this.direction,
    required this.start,
    required this.end,
    required this.distanceMm,
  });

  final WallGuideDirection direction;
  final MmPoint start;
  final MmPoint end;
  final double distanceMm;
}

/// Computes first ray/room-boundary hits in model millimetres.
///
/// Only positive intersections on the selected room boundary are accepted.
/// This is deliberately independent of UI pixels and ignores adjacent rooms.
abstract final class WallDistanceGuideCalculator {
  static List<WallDistanceGuide> fromAnchor({
    required MmPolygon room,
    required MmPoint anchor,
    double epsilonMm = 0.001,
    bool Function(int edgeIndex, double edgeFraction)? acceptWallHit,
  }) {
    if (!room.contains(anchor) && !_onBoundary(room, anchor)) {
      return const [];
    }
    final guides = <WallDistanceGuide>[];
    for (final direction in WallGuideDirection.values) {
      final directionVector = switch (direction) {
        WallGuideDirection.left => (-1.0, 0.0),
        WallGuideDirection.right => (1.0, 0.0),
        WallGuideDirection.down => (0.0, -1.0),
        WallGuideDirection.up => (0.0, 1.0),
      };
      final dx = directionVector.$1;
      final dy = directionVector.$2;
      double? nearest;
      int? nearestEdge;
      double? nearestFraction;
      final points = room.vertices;
      for (var i = 0; i < points.length; i++) {
        final a = points[i];
        final b = points[(i + 1) % points.length];
        final ex = (b.x - a.x).toDouble();
        final ey = (b.y - a.y).toDouble();
        final den = dx * ey - dy * ex;
        if (den.abs() <= epsilonMm) continue;
        final rx = (a.x - anchor.x).toDouble();
        final ry = (a.y - anchor.y).toDouble();
        final t = (rx * ey - ry * ex) / den;
        final u = (rx * dy - ry * dx) / den;
        if (t <= epsilonMm || u < -epsilonMm || u > 1 + epsilonMm) {
          continue;
        }
        if (nearest == null || t < nearest) {
          nearest = t;
          nearestEdge = i;
          nearestFraction = u;
        }
      }
      if (nearest == null || !nearest.isFinite) continue;
      if (acceptWallHit != null &&
          !acceptWallHit(nearestEdge!, nearestFraction!)) {
        // An opening is not a physical wall. Never jump through it to a
        // farther boundary and label that distance as a wall clearance.
        continue;
      }
      final target = MmPoint(
        (anchor.x + dx * nearest).round(),
        (anchor.y + dy * nearest).round(),
      );
      if (anchor == target) continue;
      guides.add(WallDistanceGuide(
        direction: direction,
        start: anchor,
        end: target,
        distanceMm: nearest,
      ));
    }
    return List.unmodifiable(guides);
  }

  static bool _onBoundary(MmPolygon room, MmPoint point) {
    final vertices = room.vertices;
    for (var i = 0; i < vertices.length; i++) {
      final a = vertices[i];
      final b = vertices[(i + 1) % vertices.length];
      final vx = (b.x - a.x).toDouble();
      final vy = (b.y - a.y).toDouble();
      final px = (point.x - a.x).toDouble();
      final py = (point.y - a.y).toDouble();
      final cross = (vx * py - vy * px).abs();
      if (cross > 0.001) continue;
      final dot = px * vx + py * vy;
      if (dot >= 0 && dot <= math.pow(vx, 2) + math.pow(vy, 2)) {
        return true;
      }
    }
    return false;
  }
}
