import 'dart:math' as math;

import '../../domain/geometry.dart';
import '../../domain/project_model.dart';
import '../../domain/surfaces.dart';
import '../../engine/plan_geometry_editing.dart';
import 'editor_controller.dart';

extension PlanGeometryEditorActions on EditorController {
  bool commitSelectedBoundary(MmPolygon candidate) {
    final current = selectedSpace;
    if (current == null || !PlanGeometryEditing.isValid(candidate)) return false;

    final candidateSpace = current.copyWith(
      boundary: candidate,
      referenceFrame: RoomReferenceFrame(origin: candidate.bounds.center),
    );

    final walls = RoomSurfaceResolver.walls(candidateSpace);
    for (final entry in current.wallProfiles.entries) {
      final index = entry.key;
      if (index < 0 || index >= walls.length) return false;
      if (entry.value.maxX != walls[index].lengthMm.round()) return false;
    }

    for (final opening in openings) {
      if (opening.hostWall.spaceId != current.id) continue;
      final index = opening.hostWall.wallIndex;
      if (index == null || index < 0 || index >= walls.length) return false;
      if (!RoomSurfaceResolver.openingFitsWall(
        opening: opening,
        wall: walls[index],
      )) {
        return false;
      }
    }

    level = level.copyWith(
      spaces: [
        for (final space in level.spaces)
          if (space.id == current.id) candidateSpace else space,
      ],
    );

    // Draft routes use surface-local coordinates based on the old geometry.
    // Clearing the draft is safer than silently keeping stale coordinates.
    routeSegments.clear();
    selectSpace(current.id);
    return true;
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
    if (opening == null || wall == null) return false;
    final offset = targetCenterMm - opening.widthMm ~/ 2;
    return updateSelectedOpening(offsetFromStartMm: offset);
  }

  bool resizeSelectedOpeningFromStart(int newStartMm) {
    final opening = selectedOpening;
    if (opening == null) return false;
    final end = opening.offsetFromStartMm + opening.widthMm;
    final width = end - newStartMm;
    if (width < 300) return false;
    return updateSelectedOpening(
      offsetFromStartMm: newStartMm,
      widthMm: width,
    );
  }

  bool resizeSelectedOpeningFromEnd(int newEndMm) {
    final opening = selectedOpening;
    if (opening == null) return false;
    final width = newEndMm - opening.offsetFromStartMm;
    if (width < 300) return false;
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

double _distanceToSegment(MmPoint p, MmPoint a, MmPoint b) {
  final dx = (b.x - a.x).toDouble();
  final dy = (b.y - a.y).toDouble();
  if (dx == 0 && dy == 0) return p.distanceTo(a);
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
