import '../../domain/electrical_placement.dart';
import '../../domain/geometry.dart';
import '../../domain/project_identity.dart';
import '../../domain/project_model.dart';
import '../../domain/surfaces.dart';
import '../../engine/plan_cable_route_projector.dart';

/// Inverts the apartment-plan projection without changing the component host.
///
/// Wall heights are not represented in the plan. Dragging a wall-mounted device
/// therefore changes only its longitudinal coordinate; the height remains
/// unchanged. A missing/stale canonical edge always fails closed.
abstract final class PlanComponentMoveProjection {
  static SurfacePointMm? fromPlan({
    required EngineeringSpace space,
    required ElectricalComponentPlacement component,
    required MmPoint planPoint,
    List<BoundaryEdgeId>? orderedEdgeIds,
    double wallPickToleranceMm = 350,
  }) {
    if (component.surface.spaceId != space.id) return null;
    if (PlanCableRouteProjector.projectPoint(
          space: space,
          surface: component.surface,
          point: component.position,
          orderedEdgeIds: orderedEdgeIds,
        ) ==
        null) {
      return null;
    }

    switch (component.surface.type) {
      case SurfacePlaneType.floor:
      case SurfacePlaneType.ceiling:
        if (!space.boundary.contains(planPoint)) return null;
        final bounds = space.boundary.bounds;
        return SurfacePointMm(
          planPoint.x - bounds.left,
          planPoint.y - bounds.bottom,
        );
      case SurfacePlaneType.wall:
        final wall = _wall(
          space: space,
          surface: component.surface,
          orderedEdgeIds: orderedEdgeIds,
        );
        if (wall == null) return null;
        final dx = wall.end.x - wall.start.x;
        final dy = wall.end.y - wall.start.y;
        final length = wall.lengthMm;
        if (length <= 0) return null;
        final along = ((planPoint.x - wall.start.x) * dx +
                (planPoint.y - wall.start.y) * dy) /
            length;
        final distance = ((planPoint.x - wall.start.x) * dy -
                    (planPoint.y - wall.start.y) * dx)
                .abs() /
            length;
        if (distance > wallPickToleranceMm || along < 0 || along > length) {
          return null;
        }
        final x = along.round();
        final y = component.position.yMm;
        if (!wall.profile.containsPoint(x, y)) return null;
        return SurfacePointMm(x, y);
    }
  }

  /// Re-checks the snapped position; rounding can otherwise escape a short
  /// physical wall or move equipment into a structural opening.
  static bool allowedOnHost({
    required EngineeringSpace space,
    required ElectricalComponentPlacement component,
    required SurfacePointMm position,
    List<BoundaryEdgeId>? orderedEdgeIds,
    Iterable<ArchitecturalOpening> openings = const [],
  }) {
    if (component.surface.spaceId != space.id) return false;
    switch (component.surface.type) {
      case SurfacePlaneType.floor:
      case SurfacePlaneType.ceiling:
        final bounds = space.boundary.bounds;
        return space.boundary.contains(
          MmPoint(bounds.left + position.xMm, bounds.bottom + position.yMm),
        );
      case SurfacePlaneType.wall:
        final wall = _wall(
          space: space,
          surface: component.surface,
          orderedEdgeIds: orderedEdgeIds,
        );
        if (wall == null ||
            position.yMm != component.position.yMm ||
            !wall.profile.containsPoint(position.xMm, position.yMm)) {
          return false;
        }
        final canonicalOrdinal = component.surface.boundaryEdgeId == null
            ? null
            : orderedEdgeIds?.indexOf(component.surface.boundaryEdgeId!);
        for (final opening in openings) {
          final sameHost = opening.hostWall == component.surface ||
              (canonicalOrdinal != null &&
                  canonicalOrdinal >= 0 &&
                  opening.hostWall.spaceId == component.surface.spaceId &&
                  opening.hostWall.wallIndex == canonicalOrdinal);
          if (!sameHost) continue;
          if (position.xMm > opening.offsetFromStartMm &&
              position.xMm < opening.endOffsetMm &&
              position.yMm > opening.sillHeightMm &&
              position.yMm < opening.topMm) {
            return false;
          }
        }
        return true;
    }
  }

  static RoomWallSurface? _wall({
    required EngineeringSpace space,
    required RoomSurfaceRef surface,
    required List<BoundaryEdgeId>? orderedEdgeIds,
  }) {
    try {
      final edgeId = surface.boundaryEdgeId;
      if (edgeId != null) {
        if (orderedEdgeIds == null ||
            orderedEdgeIds.toSet().length != orderedEdgeIds.length) {
          return null;
        }
        return RoomSurfaceResolver.wallByBoundaryEdge(
          space,
          orderedEdgeIds,
          edgeId,
        );
      }
      final index = surface.wallIndex;
      if (index == null) return null;
      return RoomSurfaceResolver.wall(space, index);
    } on RangeError {
      return null;
    } on ArgumentError {
      return null;
    } on StateError {
      return null;
    }
  }

  static MmPoint? planPointFor({
    required EngineeringSpace space,
    required ElectricalComponentPlacement component,
    List<BoundaryEdgeId>? orderedEdgeIds,
  }) =>
      PlanCableRouteProjector.projectPoint(
        space: space,
        surface: component.surface,
        point: component.position,
        orderedEdgeIds: orderedEdgeIds,
      );

  static MmPoint draggedPlanPoint({
    required MmPoint initialPoint,
    required double dxPx,
    required double dyPx,
    required double mmPerPixel,
  }) =>
      MmPoint(
        initialPoint.x + (dxPx * mmPerPixel).round(),
        initialPoint.y - (dyPx * mmPerPixel).round(),
      );
}
