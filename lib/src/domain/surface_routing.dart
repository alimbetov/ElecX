import 'dart:math' as math;

import 'geometry.dart';
import 'project_identity.dart';
import 'project_model.dart';
import 'surfaces.dart';

final class SurfaceRouteSegmentDraft {
  const SurfaceRouteSegmentDraft({required this.surface, required this.points});

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

  SurfaceRouteSegmentDraft append(SurfacePointMm point) =>
      SurfaceRouteSegmentDraft(surface: surface, points: [...points, point]);
}

/// Maps a route point between room surfaces only when both coordinates
/// represent the same physical point.
abstract final class SurfaceTransitionResolver {
  static SurfacePointMm? mapPoint({
    required EngineeringSpace space,
    required RoomSurfaceRef from,
    required SurfacePointMm point,
    required RoomSurfaceRef to,
    int roomHeightMm = 3000,
    int toleranceMm = 2,
    List<BoundaryEdgeId>? orderedBoundaryEdgeIds,
  }) {
    if (from.spaceId != space.id || to.spaceId != space.id) return null;
    if (from == to) return point;

    if (from.type == SurfacePlaneType.wall) {
      final fromWall = _resolveWall(
        space: space,
        ref: from,
        orderedBoundaryEdgeIds: orderedBoundaryEdgeIds,
        defaultHeightMm: roomHeightMm,
      );
      if (fromWall == null ||
          !fromWall.profile.containsPoint(point.xMm, point.yMm)) {
        return null;
      }
      final planPoint = RoomSurfaceResolver.wallLocalToPlan(
        fromWall,
        point.xMm,
      );

      if (to.type == SurfacePlaneType.floor && point.yMm.abs() <= toleranceMm) {
        return _planToHorizontal(space, planPoint);
      }
      if (to.type == SurfacePlaneType.ceiling &&
          (point.yMm - roomHeightMm).abs() <= toleranceMm) {
        return _planToHorizontal(space, planPoint);
      }
      if (to.type == SurfacePlaneType.wall) {
        return _wallToWall(
          space: space,
          fromWall: fromWall,
          fromPoint: point,
          to: to,
          toleranceMm: toleranceMm,
          roomHeightMm: roomHeightMm,
          orderedBoundaryEdgeIds: orderedBoundaryEdgeIds,
        );
      }
      return null;
    }

    if (point.xMm < 0 || point.yMm < 0) return null;
    final planPoint = _horizontalToPlan(space, point);
    if (!_containsOrTouches(space.boundary, planPoint)) return null;

    if (to.type == SurfacePlaneType.wall) {
      final toWall = _resolveWall(
        space: space,
        ref: to,
        orderedBoundaryEdgeIds: orderedBoundaryEdgeIds,
        defaultHeightMm: roomHeightMm,
      );
      if (toWall == null) return null;
      final x = _distanceAlongWallIfOnSegment(
        toWall,
        planPoint,
        toleranceMm: toleranceMm,
      );
      if (x == null) return null;
      final y = from.type == SurfacePlaneType.ceiling ? roomHeightMm : 0;
      if (!toWall.profile.containsPoint(x, y)) return null;
      return SurfacePointMm(x, y);
    }

    // Floor and ceiling do not directly touch each other.
    return null;
  }

  static RoomWallSurface? _resolveWall({
    required EngineeringSpace space,
    required RoomSurfaceRef ref,
    required int defaultHeightMm,
    required List<BoundaryEdgeId>? orderedBoundaryEdgeIds,
  }) {
    if (ref.type != SurfacePlaneType.wall || ref.spaceId != space.id) {
      return null;
    }
    final edgeId = ref.boundaryEdgeId;
    if (edgeId != null) {
      final edgeIds = orderedBoundaryEdgeIds;
      if (edgeIds == null) return null;
      try {
        return RoomSurfaceResolver.wallByBoundaryEdge(
          space,
          edgeIds,
          edgeId,
          defaultHeightMm: defaultHeightMm,
        );
      } on StateError {
        return null;
      } on ArgumentError {
        return null;
      }
    }
    final wallIndex = ref.wallIndex;
    if (wallIndex == null) return null;
    try {
      return RoomSurfaceResolver.wall(
        space,
        wallIndex,
        defaultHeightMm: defaultHeightMm,
      );
    } on RangeError {
      return null;
    }
  }

  static SurfacePointMm _planToHorizontal(
    EngineeringSpace space,
    MmPoint point,
  ) {
    final bounds = space.boundary.bounds;
    return SurfacePointMm(point.x - bounds.left, point.y - bounds.bottom);
  }

  static MmPoint _horizontalToPlan(
    EngineeringSpace space,
    SurfacePointMm point,
  ) {
    final bounds = space.boundary.bounds;
    return MmPoint(bounds.left + point.xMm, bounds.bottom + point.yMm);
  }

  static SurfacePointMm? _wallToWall({
    required EngineeringSpace space,
    required RoomWallSurface fromWall,
    required SurfacePointMm fromPoint,
    required RoomSurfaceRef to,
    required int toleranceMm,
    required int roomHeightMm,
    required List<BoundaryEdgeId>? orderedBoundaryEdgeIds,
  }) {
    final fromLength = fromWall.lengthMm.round();
    final atStart = fromPoint.xMm.abs() <= toleranceMm;
    final atEnd = (fromPoint.xMm - fromLength).abs() <= toleranceMm;
    if (!atStart && !atEnd) return null;

    final worldVertex = atStart ? fromWall.start : fromWall.end;
    final toWall = _resolveWall(
      space: space,
      ref: to,
      orderedBoundaryEdgeIds: orderedBoundaryEdgeIds,
      defaultHeightMm: roomHeightMm,
    );
    if (toWall == null) return null;
    final atToStart = worldVertex.distanceTo(toWall.start) <= toleranceMm;
    final atToEnd = worldVertex.distanceTo(toWall.end) <= toleranceMm;
    if (!atToStart && !atToEnd) return null;

    final result = SurfacePointMm(
      atToStart ? 0 : toWall.lengthMm.round(),
      fromPoint.yMm,
    );
    return toWall.profile.containsPoint(result.xMm, result.yMm) ? result : null;
  }

  static int? _distanceAlongWallIfOnSegment(
    RoomWallSurface wall,
    MmPoint point, {
    required int toleranceMm,
  }) {
    final ax = wall.start.x.toDouble();
    final ay = wall.start.y.toDouble();
    final bx = wall.end.x.toDouble();
    final by = wall.end.y.toDouble();
    final px = point.x.toDouble();
    final py = point.y.toDouble();
    final dx = bx - ax;
    final dy = by - ay;
    final lengthSquared = dx * dx + dy * dy;
    if (lengthSquared == 0) return null;

    final t = ((px - ax) * dx + (py - ay) * dy) / lengthSquared;
    if (t < 0 || t > 1) return null;
    final projectedX = ax + t * dx;
    final projectedY = ay + t * dy;
    final distance = math.sqrt(
      (px - projectedX) * (px - projectedX) +
          (py - projectedY) * (py - projectedY),
    );
    if (distance > toleranceMm) return null;
    return (math.sqrt(lengthSquared) * t).round();
  }

  static bool _containsOrTouches(MmPolygon polygon, MmPoint point) {
    if (polygon.contains(point)) return true;
    final vertices = polygon.vertices;
    for (var i = 0; i < vertices.length; i++) {
      final a = vertices[i];
      final b = vertices[(i + 1) % vertices.length];
      final cross =
          (point.x - a.x) * (b.y - a.y) - (point.y - a.y) * (b.x - a.x);
      if (cross != 0) continue;
      final minX = math.min(a.x, b.x);
      final maxX = math.max(a.x, b.x);
      final minY = math.min(a.y, b.y);
      final maxY = math.max(a.y, b.y);
      if (point.x >= minX &&
          point.x <= maxX &&
          point.y >= minY &&
          point.y <= maxY) {
        return true;
      }
    }
    return false;
  }
}
