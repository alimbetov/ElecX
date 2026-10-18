import 'dart:math' as math;

import '../../domain/geometry.dart';
import '../../domain/project_model.dart';
import '../../domain/surfaces.dart';
import '../../engine/plan_geometry_editing.dart';
import 'editor_controller.dart';

extension PlanGeometryEditorActions on EditorController {
  bool commitSelectedBoundary(MmPolygon candidate) {
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
      if (neighbor.id == current.id) {
        continue;
      }
      final propagated = _propagateSharedEdges(
        source: current,
        editedSource: candidateSpace,
        neighbor: neighbor,
      );
      if (propagated == null) {
        return false;
      }
      if (propagated != neighbor) {
        replacements[neighbor.id] = propagated;
      }
    }

    for (final replacement in replacements.values) {
      if (!_spaceGeometryIsCompatible(replacement)) {
        return false;
      }
    }

    level = level.copyWith(
      spaces: [
        for (final space in level.spaces) replacements[space.id] ?? space,
      ],
    );

    // Draft routes use surface-local coordinates based on the old geometry.
    // Clearing the draft is safer than silently keeping stale coordinates.
    routeSegments.clear();
    selectSpace(current.id);
    return true;
  }

  bool _spaceGeometryIsCompatible(EngineeringSpace candidateSpace) {
    final walls = RoomSurfaceResolver.walls(candidateSpace);
    for (final entry in candidateSpace.wallProfiles.entries) {
      final index = entry.key;
      if (index < 0 || index >= walls.length) {
        return false;
      }
      if (entry.value.maxX != walls[index].lengthMm.round()) {
        return false;
      }
    }

    for (final opening in openings) {
      if (opening.hostWall.spaceId != candidateSpace.id) {
        continue;
      }
      final index = opening.hostWall.wallIndex;
      if (index == null || index < 0 || index >= walls.length) {
        return false;
      }
      if (!RoomSurfaceResolver.openingFitsWall(
        opening: opening,
        wall: walls[index],
      )) {
        return false;
      }
    }
    return true;
  }

  /// Moves the active wall parallel to itself by [distanceMm].
  ///
  /// Positive and negative values select the two opposite wall-normal
  /// directions. Shared room boundaries are propagated atomically by
  /// [commitSelectedBoundary].
  bool nudgeActiveWallNormal(int distanceMm) {
    final space = selectedSpace;
    final wallIndex = activeSurface?.wallIndex;
    if (space == null || wallIndex == null || distanceMm == 0) {
      return false;
    }
    final vertices = space.boundary.vertices;
    if (wallIndex < 0 || wallIndex >= vertices.length) {
      return false;
    }
    final a = vertices[wallIndex];
    final b = vertices[(wallIndex + 1) % vertices.length];
    final dx = (b.x - a.x).toDouble();
    final dy = (b.y - a.y).toDouble();
    final length = math.sqrt(dx * dx + dy * dy);
    if (length == 0) {
      return false;
    }
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

  void selectOpeningForPlan(ArchitecturalOpening opening) {
    selectOpening(opening.id);
    // selectOpening establishes the host wall needed by opening validation.
    // Keep the Plan projection active so direct manipulation stays in place.
    viewMode = EditorViewMode.plan;
    activeSurface = opening.hostWall;
  }

  bool moveSelectedOpeningAlongWall(int targetCenterMm) {
    final opening = selectedOpening;
    final wall = activeWall;
    if (opening == null || wall == null) {
      return false;
    }
    final offset = targetCenterMm - opening.widthMm ~/ 2;
    return updateSelectedOpening(offsetFromStartMm: offset);
  }

  /// Moves the selected window/door along its host wall.
  bool nudgeSelectedOpening(int deltaMm) {
    final opening = selectedOpening;
    if (opening == null || deltaMm == 0) {
      return false;
    }
    return updateSelectedOpening(
      offsetFromStartMm: opening.offsetFromStartMm + deltaMm,
    );
  }

  bool resizeSelectedOpeningFromStart(int newStartMm) {
    final opening = selectedOpening;
    if (opening == null) {
      return false;
    }
    final end = opening.offsetFromStartMm + opening.widthMm;
    final width = end - newStartMm;
    if (width < 300) {
      return false;
    }
    return updateSelectedOpening(
      offsetFromStartMm: newStartMm,
      widthMm: width,
    );
  }

  bool resizeSelectedOpeningFromEnd(int newEndMm) {
    final opening = selectedOpening;
    if (opening == null) {
      return false;
    }
    final width = newEndMm - opening.offsetFromStartMm;
    if (width < 300) {
      return false;
    }
    return updateSelectedOpening(widthMm: width);
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
      if (space == null || wallIndex == null) {
        continue;
      }
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
    if (wall == null) {
      return null;
    }
    final dx = (wall.end.x - wall.start.x).toDouble();
    final dy = (wall.end.y - wall.start.y).toDouble();
    final length = wall.lengthMm;
    if (length <= 0) {
      return null;
    }
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
    if (oldA == newA && oldB == newB) {
      continue;
    }

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

  if (!changed) {
    return neighbor;
  }
  final boundary = MmPolygon(neighborVertices);
  if (!PlanGeometryEditing.isValid(boundary)) {
    return null;
  }
  return neighbor.copyWith(
    boundary: boundary,
    referenceFrame: RoomReferenceFrame(origin: boundary.bounds.center),
  );
}

double _distanceToSegment(MmPoint p, MmPoint a, MmPoint b) {
  final dx = (b.x - a.x).toDouble();
  final dy = (b.y - a.y).toDouble();
  if (dx == 0 && dy == 0) {
    return p.distanceTo(a);
  }
  final t = (((p.x - a.x) * dx + (p.y - a.y) * dy) /
          (dx * dx + dy * dy))
      .clamp(0.0, 1.0);
  final x = a.x + t * dx;
  final y = a.y + t * dy;
  final ex = p.x - x;
  final ey = p.y - y;
  return math.sqrt(ex * ex + ey * ey);
}

extension _NullableFirst<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
