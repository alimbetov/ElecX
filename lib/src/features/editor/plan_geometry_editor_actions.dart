import 'dart:math' as math;

import '../../domain/geometry.dart';
import '../../domain/project_model.dart';
import '../../domain/surfaces.dart';
import '../../engine/normative_route_engine.dart';
import '../../engine/plan_geometry_editing.dart';
import 'canonical_boundary_topology_editing_runtime.dart';
import 'editor_controller.dart';
import 'electrical_host_geometry_guard.dart';
import 'editor_p2_session.dart';

extension PlanGeometryEditorActions on EditorController {
  bool commitSelectedBoundary(MmPolygon candidate) {
    if (CanonicalBoundaryTopologyEditingRuntime.hasCanonicalRuntime(this)) {
      return CanonicalBoundaryTopologyEditingRuntime.commitCandidate(
        this,
        candidate,
        materializeLegacy: () => _commitSelectedBoundaryLegacy(candidate),
      );
    }
    return _commitSelectedBoundaryLegacy(candidate);
  }

  /// Transitional materialization path. Canonical runtime may call this only
  /// after the P3 topology mutation has committed successfully. Legacy-only
  /// workspaces continue to use it directly until their cutover is complete.
  bool _commitSelectedBoundaryLegacy(MmPolygon candidate) {
    final current = selectedSpace;
    if (current == null || !PlanGeometryEditing.isValid(candidate)) {
      return false;
    }

    final candidateSpace = current.copyWith(
      boundary: candidate,
      referenceFrame: RoomReferenceFrame(origin: candidate.bounds.center),
    );

    final replacements = <String, EngineeringSpace>{current.id: candidateSpace};
    for (final neighbor in level.spaces) {
      if (neighbor.id == current.id) continue;
      final propagated = _propagateSharedEdges(
        source: current,
        editedSource: candidateSpace,
        neighbor: neighbor,
      );
      if (propagated == null) return false;
      if (propagated != neighbor) replacements[neighbor.id] = propagated;
    }

    for (final replacement in replacements.values) {
      if (!_spaceGeometryIsCompatible(replacement) ||
          !_spaceElectricalModelIsCompatible(replacement)) {
        return false;
      }
    }

    level = level.copyWith(
      spaces: [
        for (final space in level.spaces) replacements[space.id] ?? space,
      ],
    );
    routeSegments.clear();
    selectSpace(current.id);
    return true;
  }

  bool _spaceGeometryIsCompatible(EngineeringSpace candidateSpace) {
    final walls = RoomSurfaceResolver.walls(candidateSpace);
    for (final entry in candidateSpace.wallProfiles.entries) {
      final index = entry.key;
      if (index < 0 || index >= walls.length) return false;
      if (entry.value.maxX != walls[index].lengthMm.round()) return false;
    }

    for (final opening in openings) {
      if (opening.hostWall.spaceId != candidateSpace.id) continue;
      final index = opening.hostWall.wallIndex;
      if (index == null || index < 0 || index >= walls.length) return false;
      if (!RoomSurfaceResolver.openingFitsWall(
        opening: opening,
        wall: walls[index],
      )) {
        return false;
      }
    }
    return true;
  }

  bool _spaceElectricalModelIsCompatible(EngineeringSpace candidateSpace) {
    RouteNormativeContext? contextFor(RoomSurfaceRef surface) {
      if (surface.spaceId != candidateSpace.id) return null;
      if (surface.type == SurfacePlaneType.wall) {
        final wallIndex = surface.wallIndex;
        final walls = RoomSurfaceResolver.walls(candidateSpace);
        if (wallIndex == null || wallIndex < 0 || wallIndex >= walls.length) {
          return null;
        }
        final wall = walls[wallIndex];
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
      }
      final bounds = candidateSpace.boundary.bounds;
      return RouteNormativeContext(
        surface: surface,
        widthMm: bounds.width,
        heightMm: bounds.height,
        edgeClearanceMm: 0,
        boundary: [
          for (final point in candidateSpace.boundary.vertices)
            SurfacePointMm(point.x - bounds.left, point.y - bounds.bottom),
        ],
      );
    }

    bool containsPoint(SurfacePointMm point, RouteNormativeContext context) {
      if (point.xMm < 0 ||
          point.yMm < 0 ||
          point.xMm > context.widthMm ||
          point.yMm > context.heightMm) {
        return false;
      }
      final polygon = context.boundary;
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

    for (final component in p2.components) {
      if (component.surface.spaceId != candidateSpace.id) continue;
      final context = contextFor(component.surface);
      if (context == null || !containsPoint(component.position, context)) {
        return false;
      }
    }
    for (final route in p2.routes) {
      for (final segment in route.segments) {
        if (segment.surface.spaceId != candidateSpace.id) continue;
        final context = contextFor(segment.surface);
        if (context == null ||
            !NormativeRouteEngine.validate(
              points: segment.points,
              context: context,
            ).isValid) {
          return false;
        }
      }
    }
    return true;
  }

  bool isSelectedWallExternal(int wallIndex) {
    final space = selectedSpace;
    if (space == null ||
        wallIndex < 0 ||
        wallIndex >= space.boundary.vertices.length) {
      return false;
    }
    final vertices = space.boundary.vertices;
    final a = vertices[wallIndex];
    final b = vertices[(wallIndex + 1) % vertices.length];

    for (final neighbor in level.spaces) {
      if (neighbor.id == space.id) continue;
      final other = neighbor.boundary.vertices;
      for (var i = 0; i < other.length; i++) {
        final c = other[i];
        final d = other[(i + 1) % other.length];
        if (_collinearOverlap(a, b, c, d)) return false;
      }
    }
    return true;
  }

  bool get activeWallIsExternal {
    final index = activeSurface?.wallIndex;
    return index != null && isSelectedWallExternal(index);
  }

  int? selectedWallIndexAtPlanPoint(MmPoint point, {required double radiusMm}) {
    final space = selectedSpace;
    if (space == null) return null;
    final vertices = space.boundary.vertices;
    int? bestIndex;
    var bestDistance = double.infinity;
    for (var i = 0; i < vertices.length; i++) {
      final distance = _distanceToSegment(
        point,
        vertices[i],
        vertices[(i + 1) % vertices.length],
      );
      if (distance <= radiusMm && distance < bestDistance) {
        bestIndex = i;
        bestDistance = distance;
      }
    }
    return bestIndex;
  }

  bool nudgeSelectedBoundaryEdgeNormal(int wallIndex, int distanceMm) {
    final space = selectedSpace;
    if (space == null ||
        distanceMm == 0 ||
        wallIndex < 0 ||
        wallIndex >= space.boundary.vertices.length ||
        !isSelectedWallExternal(wallIndex)) {
      return false;
    }
    final vertices = space.boundary.vertices;
    final a = vertices[wallIndex];
    final b = vertices[(wallIndex + 1) % vertices.length];
    final dx = (b.x - a.x).toDouble();
    final dy = (b.y - a.y).toDouble();
    final length = math.sqrt(dx * dx + dy * dy);
    if (length == 0) return false;
    final midpoint = MmPoint((a.x + b.x) ~/ 2, (a.y + b.y) ~/ 2);
    final target = MmPoint(
      (midpoint.x - dy / length * distanceMm).round(),
      (midpoint.y + dx / length * distanceMm).round(),
    );
    final candidate = PlanGeometryEditing.moveEdge(
      boundary: space.boundary,
      edgeIndex: wallIndex,
      dragStart: midpoint,
      dragCurrent: target,
    );
    return candidate != null && commitSelectedBoundary(candidate);
  }

  bool nudgeActiveWallNormal(int distanceMm) {
    final wallIndex = activeSurface?.wallIndex;
    if (wallIndex == null) return false;
    return nudgeSelectedBoundaryEdgeNormal(wallIndex, distanceMm);
  }

  void selectOpeningForPlan(ArchitecturalOpening opening) {
    selectOpening(opening.id);
    viewMode = EditorViewMode.plan;
    activeSurface = opening.hostWall;
  }

  bool moveSelectedOpeningAlongWall(int targetCenterMm) {
    final opening = selectedOpening;
    final wall = activeWall;
    if (opening == null || wall == null) return false;
    final offset = targetCenterMm - opening.widthMm ~/ 2;
    return updateSelectedOpeningGuarded(offsetFromStartMm: offset);
  }

  bool nudgeSelectedOpening(int deltaMm) {
    final opening = selectedOpening;
    if (opening == null || deltaMm == 0) return false;
    return updateSelectedOpeningGuarded(
      offsetFromStartMm: opening.offsetFromStartMm + deltaMm,
    );
  }

  bool resizeSelectedOpeningFromStart(int newStartMm) {
    final opening = selectedOpening;
    if (opening == null) return false;
    final end = opening.offsetFromStartMm + opening.widthMm;
    final width = end - newStartMm;
    if (width < 300) return false;
    return updateSelectedOpeningGuarded(
      offsetFromStartMm: newStartMm,
      widthMm: width,
    );
  }

  bool resizeSelectedOpeningFromEnd(int newEndMm) {
    final opening = selectedOpening;
    if (opening == null) return false;
    final width = newEndMm - opening.offsetFromStartMm;
    if (width < 300) return false;
    return updateSelectedOpeningGuarded(widthMm: width);
  }

  ArchitecturalOpening? openingAtPlanPoint(
    MmPoint point, {
    required double radiusMm,
  }) {
    ArchitecturalOpening? best;
    var bestDistance = double.infinity;
    for (final opening in openings.reversed) {
      final space = level.spaces
          .where((item) => item.id == opening.hostWall.spaceId)
          .firstOrNull;
      final wallIndex = opening.hostWall.wallIndex;
      if (space == null || wallIndex == null) continue;
      final wall = RoomSurfaceResolver.wall(space, wallIndex);
      final a = RoomSurfaceResolver.wallLocalToPlan(
        wall,
        opening.offsetFromStartMm,
      );
      final b = RoomSurfaceResolver.wallLocalToPlan(
        wall,
        opening.offsetFromStartMm + opening.widthMm,
      );
      final distance = _distanceToSegment(point, a, b);
      if (distance <= radiusMm && distance < bestDistance) {
        best = opening;
        bestDistance = distance;
      }
    }
    return best;
  }

  int? planPointToActiveWallOffset(MmPoint point) {
    final wall = activeWall;
    if (wall == null) return null;
    final dx = (wall.end.x - wall.start.x).toDouble();
    final dy = (wall.end.y - wall.start.y).toDouble();
    final length = wall.lengthMm;
    if (length <= 0) return null;
    final px = (point.x - wall.start.x).toDouble();
    final py = (point.y - wall.start.y).toDouble();
    final projected = (px * dx + py * dy) / length;
    return projected.round();
  }
}

EngineeringSpace? _propagateSharedEdges({
  required EngineeringSpace source,
  required EngineeringSpace editedSource,
  required EngineeringSpace neighbor,
}) {
  final sourceVertices = source.boundary.vertices;
  final editedVertices = editedSource.boundary.vertices;
  final neighborVertices = [...neighbor.boundary.vertices];
  var changed = false;

  for (var i = 0; i < sourceVertices.length; i++) {
    final nextI = (i + 1) % sourceVertices.length;
    final oldA = sourceVertices[i];
    final oldB = sourceVertices[nextI];
    final newA = editedVertices[i];
    final newB = editedVertices[nextI];
    if (oldA == newA && oldB == newB) continue;

    for (var j = 0; j < neighborVertices.length; j++) {
      final nextJ = (j + 1) % neighborVertices.length;
      final neighborA = neighborVertices[j];
      final neighborB = neighborVertices[nextJ];
      if (neighborA == oldA && neighborB == oldB) {
        neighborVertices[j] = newA;
        neighborVertices[nextJ] = newB;
        changed = true;
      } else if (neighborA == oldB && neighborB == oldA) {
        neighborVertices[j] = newB;
        neighborVertices[nextJ] = newA;
        changed = true;
      }
    }
  }

  if (!changed) return neighbor;
  final boundary = MmPolygon(neighborVertices);
  if (!PlanGeometryEditing.isValid(boundary)) return null;
  return neighbor.copyWith(
    boundary: boundary,
    referenceFrame: RoomReferenceFrame(origin: boundary.bounds.center),
  );
}

bool _collinearOverlap(MmPoint a, MmPoint b, MmPoint c, MmPoint d) {
  int cross(MmPoint p, MmPoint q, MmPoint r) =>
      (q.x - p.x) * (r.y - p.y) - (q.y - p.y) * (r.x - p.x);
  if (cross(a, b, c) != 0 || cross(a, b, d) != 0) return false;
  final useX = (b.x - a.x).abs() >= (b.y - a.y).abs();
  int axis(MmPoint p) => useX ? p.x : p.y;
  final aMin = math.min(axis(a), axis(b));
  final aMax = math.max(axis(a), axis(b));
  final bMin = math.min(axis(c), axis(d));
  final bMax = math.max(axis(c), axis(d));
  return math.min(aMax, bMax) > math.max(aMin, bMin);
}

double _distanceToSegment(MmPoint p, MmPoint a, MmPoint b) {
  final dx = (b.x - a.x).toDouble();
  final dy = (b.y - a.y).toDouble();
  if (dx == 0 && dy == 0) return p.distanceTo(a);
  final t = (((p.x - a.x) * dx + (p.y - a.y) * dy) / (dx * dx + dy * dy)).clamp(
    0.0,
    1.0,
  );
  final x = a.x + t * dx;
  final y = a.y + t * dy;
  final ex = p.x - x;
  final ey = p.y - y;
  return math.sqrt(ex * ex + ey * ey);
}

extension _NullableFirst<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
