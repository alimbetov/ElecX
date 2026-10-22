import 'dart:math' as math;

import '../../domain/project_model.dart';
import '../../domain/surfaces.dart';
import '../../engine/normative_route_engine.dart';
import 'editor_controller.dart';
import 'editor_p2_session.dart';

abstract final class ElectricalHostGeometryGuard {
  static bool openingCandidateAllowed(
    EditorController controller,
    ArchitecturalOpening candidate,
  ) {
    final surface = candidate.hostWall;
    final space = _space(controller, surface.spaceId);
    final wallIndex = surface.wallIndex;
    if (space == null || wallIndex == null) return false;
    final walls = RoomSurfaceResolver.walls(space);
    if (wallIndex < 0 || wallIndex >= walls.length) return false;
    final wall = walls[wallIndex];
    if (!RoomSurfaceResolver.openingFitsWall(opening: candidate, wall: wall)) {
      return false;
    }
    final openings = <ArchitecturalOpening>[
      for (final opening in controller.openings)
        if (opening.id == candidate.id) candidate else opening,
    ];
    if (!openings.any((opening) => opening.id == candidate.id)) {
      openings.add(candidate);
    }
    return _surfaceAllowed(
      controller,
      surface,
      RouteNormativeContext(
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
      ),
    );
  }

  static bool wallProfileCandidateAllowed(
    EditorController controller,
    EngineeringSpace candidateSpace,
    int wallIndex,
  ) {
    final walls = RoomSurfaceResolver.walls(candidateSpace);
    if (wallIndex < 0 || wallIndex >= walls.length) return false;
    final wall = walls[wallIndex];
    final surface = RoomSurfaceRef.wall(candidateSpace.id, wallIndex);
    for (final opening in controller.openings) {
      if (opening.hostWall == surface &&
          !RoomSurfaceResolver.openingFitsWall(opening: opening, wall: wall)) {
        return false;
      }
    }
    return _surfaceAllowed(
      controller,
      surface,
      RouteNormativeContext(
        surface: surface,
        widthMm: wall.lengthMm.round(),
        heightMm: wall.heightMm,
        edgeClearanceMm: 0,
        boundary: [
          for (final point in wall.profile.vertices)
            SurfacePointMm(point.xMm, point.yMm),
        ],
        obstacles: [
          for (final opening in controller.openings)
            if (opening.hostWall == surface)
              RouteObstacleMm(
                id: opening.id,
                leftMm: opening.offsetFromStartMm,
                topMm: opening.sillHeightMm,
                rightMm: opening.endOffsetMm,
                bottomMm: opening.topMm,
              ),
        ],
      ),
    );
  }

  static EngineeringSpace? _space(EditorController controller, String id) {
    for (final space in controller.level.spaces) {
      if (space.id == id) return space;
    }
    return null;
  }

  static bool _surfaceAllowed(
    EditorController controller,
    RoomSurfaceRef surface,
    RouteNormativeContext context,
  ) {
    for (final component in controller.p2.components) {
      if (component.surface != surface) continue;
      if (!_insideOrBoundary(component.position, context.boundary)) {
        return false;
      }
      for (final obstacle in context.obstacles) {
        if (_insideObstacle(component.position, obstacle)) return false;
      }
    }
    for (final route in controller.p2.routes) {
      for (final segment in route.segments) {
        if (segment.surface != surface) continue;
        if (!NormativeRouteEngine.validate(
          points: segment.points,
          context: context,
        ).isValid) {
          return false;
        }
      }
    }
    return true;
  }

  static bool _insideObstacle(SurfacePointMm point, RouteObstacleMm obstacle) =>
      point.xMm > math.min(obstacle.leftMm, obstacle.rightMm) &&
      point.xMm < math.max(obstacle.leftMm, obstacle.rightMm) &&
      point.yMm > math.min(obstacle.topMm, obstacle.bottomMm) &&
      point.yMm < math.max(obstacle.topMm, obstacle.bottomMm);

  static bool _insideOrBoundary(
    SurfacePointMm point,
    List<SurfacePointMm> polygon,
  ) {
    if (polygon.isEmpty) return true;
    var inside = false;
    for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final a = polygon[j];
      final b = polygon[i];
      final cross = (b.xMm - a.xMm) * (point.yMm - a.yMm) -
          (b.yMm - a.yMm) * (point.xMm - a.xMm);
      if (cross == 0 &&
          point.xMm >= math.min(a.xMm, b.xMm) &&
          point.xMm <= math.max(a.xMm, b.xMm) &&
          point.yMm >= math.min(a.yMm, b.yMm) &&
          point.yMm <= math.max(a.yMm, b.yMm)) {
        return true;
      }
      final crosses = (a.yMm > point.yMm) != (b.yMm > point.yMm);
      if (!crosses) continue;
      final crossingX =
          (b.xMm - a.xMm) * (point.yMm - a.yMm) / (b.yMm - a.yMm) + a.xMm;
      if (point.xMm < crossingX) inside = !inside;
    }
    return inside;
  }
}

extension ElectricalHostGeometryGuardedMutations on EditorController {
  bool updateSelectedOpeningGuarded({
    ArchitecturalOpeningType? type,
    int? offsetFromStartMm,
    int? widthMm,
    int? heightMm,
    int? sillHeightMm,
    bool Function(ArchitecturalOpening candidate)? canCommit,
  }) =>
      updateSelectedOpening(
        type: type,
        offsetFromStartMm: offsetFromStartMm,
        widthMm: widthMm,
        heightMm: heightMm,
        sillHeightMm: sillHeightMm,
        canCommit: canCommit ??
            (candidate) => ElectricalHostGeometryGuard.openingCandidateAllowed(
                  this,
                  candidate,
                ),
      );

  bool addOpeningGuarded(
    ArchitecturalOpeningType type, {
    bool Function(ArchitecturalOpening candidate)? canCommit,
  }) =>
      addOpening(
        type,
        canCommit: canCommit ??
            (candidate) => ElectricalHostGeometryGuard.openingCandidateAllowed(
                  this,
                  candidate,
                ),
      );
}
