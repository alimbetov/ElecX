import '../domain/electrical_routing.dart';
import '../domain/geometry.dart';
import '../domain/project_model.dart';
import '../domain/surfaces.dart';

/// Read-only PLAN projection of already committed P2 physical cable routes.
///
/// A wall's vertical run collapses to one plan point, not an invented plan
/// cable segment. Each surface segment projects independently: the projector
/// NEVER draws a connection through an unqualified room boundary.
final class PlanCableProjectedSegment {
  PlanCableProjectedSegment({
    required this.routeId,
    required this.surfaceType,
    required Iterable<MmPoint> points,
  }) : points = List.unmodifiable(points);

  final String routeId;
  final SurfacePlaneType surfaceType;
  final List<MmPoint> points;

  bool get isVerticalPlanMarker =>
      points.length > 1 && points.every((p) => p == points.first);
}

final class PlanCableProjection {
  PlanCableProjection({
    required Iterable<PlanCableProjectedSegment> segments,
    required this.skippedSurfaceSegments,
  }) : segments = List.unmodifiable(segments);

  final List<PlanCableProjectedSegment> segments;
  final int skippedSurfaceSegments;

  bool get hasIncompleteProjection => skippedSurfaceSegments > 0;
}

abstract final class PlanCableRouteProjector {
  static PlanCableProjection project({
    required BuildingLevel level,
    required Iterable<ElectricalCableRoute> routes,
  }) {
    final spaces = {for (final space in level.spaces) space.id: space};
    final projected = <PlanCableProjectedSegment>[];
    var skipped = 0;
    for (final route in routes) {
      for (final segment in route.segments) {
        if (segment.points.length < 2) {
          skipped++;
          continue;
        }
        final space = spaces[segment.surface.spaceId];
        if (space == null) {
          skipped++;
          continue;
        }
        final points = _projectPoints(space, segment);
        if (points == null) {
          skipped++;
          continue;
        }
        projected.add(PlanCableProjectedSegment(
          routeId: route.id,
          surfaceType: segment.surface.type,
          points: points,
        ));
      }
    }
    return PlanCableProjection(
      segments: projected,
      skippedSurfaceSegments: skipped,
    );
  }

  static List<MmPoint>? _projectPoints(
    EngineeringSpace space,
    ElectricalRouteSegment segment,
  ) {
    switch (segment.surface.type) {
      case SurfacePlaneType.floor:
      case SurfacePlaneType.ceiling:
        final bounds = space.boundary.bounds;
        return [
          for (final point in segment.points)
            MmPoint(bounds.left + point.xMm, bounds.bottom + point.yMm),
        ];
      case SurfacePlaneType.wall:
        // A canonical BoundaryEdgeId needs its authoritative edge order.
        // Never substitute a guessed ordinal for that identity.
        final ordinal = segment.surface.wallIndex;
        if (ordinal == null) return null;
        RoomWallSurface wall;
        try {
          wall = RoomSurfaceResolver.wall(space, ordinal);
        } on RangeError {
          return null;
        } on ArgumentError {
          return null;
        }
        return [
          for (final point in segment.points)
            RoomSurfaceResolver.wallLocalToPlan(wall, point.xMm),
        ];
    }
  }
}
