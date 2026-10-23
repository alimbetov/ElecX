import '../../domain/project_model.dart';
import '../../domain/surfaces.dart';
import '../../engine/normative_route_engine.dart';
import 'canonical_room_surface_runtime_registry.dart';
import 'editor_controller.dart';

/// Resolves route geometry against the materialized legacy level that owns the
/// requested surface instead of assuming every segment belongs to the currently
/// active canvas level.
///
/// This is required after a ceiling↔floor handoff: the editor is already on the
/// target level while the same durable cable route still contains segments on
/// the source level. Identity lookup is exact and ambiguity fails closed.
abstract final class MultiLevelRouteNormativeContext {
  static RouteNormativeContext? resolve(
    EditorController controller,
    RoomSurfaceRef surface,
  ) {
    final active = controller.routeNormativeContextFor(surface);
    if (active != null) return active;

    final coordinator =
        CanonicalRoomSurfaceRuntimeRegistry.coordinatorFor(controller);
    if (coordinator == null) return null;
    final workspace = coordinator.adapter.workspace;

    ({int levelNumber, EngineeringSpace space})? owner;
    for (final composed in workspace.building.levels) {
      for (final candidate in composed.level.spaces) {
        if (candidate.id != surface.spaceId) continue;
        if (owner != null) return null;
        owner = (levelNumber: composed.levelNumber, space: candidate);
      }
    }
    if (owner == null) return null;

    final space = owner.space;
    if (surface.type == SurfacePlaneType.wall) {
      final wallIndex = surface.wallIndex;
      if (wallIndex == null) return null;
      try {
        final wall = RoomSurfaceResolver.wall(space, wallIndex);
        final openings =
            workspace.openingsByLevel[owner.levelNumber] ?? const [];
        return RouteNormativeContext(
          surface: surface,
          widthMm: wall.lengthMm.round(),
          heightMm: wall.heightMm,
          edgeClearanceMm: 0,
          boundary: [
            for (final point in wall.profile.vertices)
              SurfacePointMm(point.xMm, point.yMm),
          ],
          obstacles: [
            for (final opening in openings)
              if (opening.hostWall == surface)
                RouteObstacleMm(
                  id: opening.id,
                  leftMm: opening.offsetFromStartMm,
                  topMm: opening.sillHeightMm,
                  rightMm: opening.endOffsetMm,
                  bottomMm: opening.topMm,
                ),
          ],
        );
      } on ArgumentError {
        return null;
      } on StateError {
        return null;
      }
    }

    final bounds = space.boundary.bounds;
    return RouteNormativeContext(
      surface: surface,
      widthMm: bounds.width,
      heightMm: bounds.height,
      edgeClearanceMm: 0,
      boundary: [
        for (final point in space.boundary.vertices)
          SurfacePointMm(point.x - bounds.left, point.y - bounds.bottom),
      ],
    );
  }
}
