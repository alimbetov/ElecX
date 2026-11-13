import '../domain/electrical_routing.dart';
import '../domain/geometry.dart';
import '../domain/project_identity.dart';
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
    Map<String, List<BoundaryEdgeId>> boundaryEdgeOrderBySpace = const {},
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
        final points = <MmPoint>[];
        for (final point in segment.points) {
          final projected = projectPoint(
            space: space,
            surface: segment.surface,
            point: point,
            orderedEdgeIds: boundaryEdgeOrderBySpace[space.id],
          );
          if (projected == null) break;
          points.add(projected);
        }
        if (points.length != segment.points.length) {
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

  /// Projects equipment and route geometry through one surface transform.
  /// Canonical walls require the authoritative, geometry-verified edge order.
  static MmPoint? projectPoint({
    required EngineeringSpace space,
    required RoomSurfaceRef surface,
    required SurfacePointMm point,
    List<BoundaryEdgeId>? orderedEdgeIds,
  }) {
    if (surface.spaceId != space.id) return null;
    switch (surface.type) {
      case SurfacePlaneType.floor:
      case SurfacePlaneType.ceiling:
        final bounds = space.boundary.bounds;
        return MmPoint(bounds.left + point.xMm, bounds.bottom + point.yMm);
      case SurfacePlaneType.wall:
        RoomWallSurface wall;
        try {
          if (surface.boundaryEdgeId != null) {
            if (orderedEdgeIds == null ||
                orderedEdgeIds.toSet().length != orderedEdgeIds.length) {
              return null;
            }
            wall = RoomSurfaceResolver.wallByBoundaryEdge(
              space,
              orderedEdgeIds,
              surface.boundaryEdgeId!,
            );
          } else {
            final ordinal = surface.wallIndex;
            if (ordinal == null) return null;
            wall = RoomSurfaceResolver.wall(space, ordinal);
          }
        } on RangeError {
          return null;
        } on ArgumentError {
          return null;
        } on StateError {
          return null;
        }
        return RoomSurfaceResolver.wallLocalToPlan(wall, point.xMm);
    }
  }
}
