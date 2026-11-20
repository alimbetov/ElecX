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
        RoomWallSurface wall;
        try {
          final edgeId = component.surface.boundaryEdgeId;
          if (edgeId != null) {
            if (orderedEdgeIds == null ||
                orderedEdgeIds.toSet().length != orderedEdgeIds.length) {
              return null;
            }
            wall = RoomSurfaceResolver.wallByBoundaryEdge(
              space,
              orderedEdgeIds,
              edgeId,
            );
          } else {
            final index = component.surface.wallIndex;
            if (index == null) return null;
            wall = RoomSurfaceResolver.wall(space, index);
          }
        } on RangeError {
          return null;
        } on ArgumentError {
          return null;
        } on StateError {
          return null;
        }

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
