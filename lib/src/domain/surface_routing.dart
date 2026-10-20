import 'dart:math' as math;

import 'geometry.dart';
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
  }) {
    if (from.spaceId != space.id || to.spaceId != space.id) return null;
    if (from == to) return point;

    if (from.type == SurfacePlaneType.wall) {
      final fromWall = RoomSurfaceResolver.wall(space, from.wallIndex!);
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
          toWallIndex: to.wallIndex!,
          toleranceMm: toleranceMm,
        );
      }
      return null;
    }

    if (to.type == SurfacePlaneType.wall) {
      final planPoint = _horizontalToPlan(space, point);
      final toWall = RoomSurfaceResolver.wall(space, to.wallIndex!);
      final x = _distanceAlongWallIfOnSegment(
        toWall,
        planPoint,
        toleranceMm: toleranceMm,
      );
      if (x == null) return null;
      final y = from.type == SurfacePlaneType.ceiling ? roomHeightMm : 0;
      return SurfacePointMm(x, y);
    }

    // Floor and ceiling do not directly touch each other.
    return null;
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
    required int toWallIndex,
    required int toleranceMm,
  }) {
    final fromLength = fromWall.lengthMm.round();
    final atStart = fromPoint.xMm.abs() <= toleranceMm;
    final atEnd = (fromPoint.xMm - fromLength).abs() <= toleranceMm;
    if (!atStart && !atEnd) return null;

    final worldVertex = atStart ? fromWall.start : fromWall.end;
    final toWall = RoomSurfaceResolver.wall(space, toWallIndex);
    final atToStart = worldVertex.distanceTo(toWall.start) <= toleranceMm;
    final atToEnd = worldVertex.distanceTo(toWall.end) <= toleranceMm;
    if (!atToStart && !atToEnd) return null;

    return SurfacePointMm(
      atToStart ? 0 : toWall.lengthMm.round(),
      fromPoint.yMm,
    );
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
}
