import 'boundary_topology.dart';
import 'project_aggregate.dart';
import 'project_identity.dart';
import 'slab_topology.dart';
import 'vertical_core.dart';

enum VerticalCoreCrossingDirection { up, down }

/// Canonical proof that one vertical core crosses one concrete inter-level slab.
final class VerticalCoreSlabCrossing {
  const VerticalCoreSlabCrossing({
    required this.verticalCoreId,
    required this.slabId,
    required this.fromLevelId,
    required this.toLevelId,
    required this.planPoint,
    required this.direction,
  });

  final VerticalCoreId verticalCoreId;
  final SlabId slabId;
  final LevelId fromLevelId;
  final LevelId toLevelId;
  final BoundaryPointMm planPoint;
  final VerticalCoreCrossingDirection direction;
}

/// Resolves one physical inter-level crossing through a stable vertical core.
///
/// The resolver deliberately returns null on any missing or ambiguous physical
/// evidence. It never invents a slab from elevation alone and never treats the
/// vertical core itself as a penetration host: the returned [SlabId] remains
/// the physical ceiling↔floor boundary that routing must penetrate.
abstract final class VerticalCoreSlabCrossingResolver {
  static VerticalCoreSlabCrossing? resolve({
    required ProjectAggregateRoot project,
    required ProjectVerticalCore core,
    required LevelId fromLevelId,
    required LevelId toLevelId,
    required BoundaryPointMm planPoint,
  }) {
    if (fromLevelId == toLevelId) return null;
    if (!core.servesLevel(fromLevelId) || !core.servesLevel(toLevelId)) {
      return null;
    }
    if (!_containsPoint(core.footprint, planPoint)) return null;

    final fromLevel = project.index.level(fromLevelId);
    final toLevel = project.index.level(toLevelId);
    if (fromLevel == null || toLevel == null) return null;
    if (fromLevel.buildingId != core.buildingId ||
        toLevel.buildingId != core.buildingId) {
      return null;
    }

    final lower = fromLevel.elevationMm < toLevel.elevationMm
        ? fromLevel
        : toLevel;
    final upper = identical(lower, fromLevel) ? toLevel : fromLevel;

    ProjectSlab? matched;
    for (final slabId in project.index.slabsForLevel(lower.id)) {
      final slab = project.index.slab(slabId);
      if (slab == null ||
          slab.kind != SlabKind.interLevel ||
          slab.buildingId != core.buildingId ||
          slab.belowLevelId != lower.id ||
          slab.aboveLevelId != upper.id ||
          !_containsPoint(slab.footprint, planPoint)) {
        continue;
      }
      if (matched != null) {
        // Never choose one physical slab by map/order when ownership is
        // ambiguous at the requested plan point.
        return null;
      }
      matched = slab;
    }
    if (matched == null) return null;

    return VerticalCoreSlabCrossing(
      verticalCoreId: core.id,
      slabId: matched.id,
      fromLevelId: fromLevelId,
      toLevelId: toLevelId,
      planPoint: planPoint,
      direction: fromLevel.elevationMm < toLevel.elevationMm
          ? VerticalCoreCrossingDirection.up
          : VerticalCoreCrossingDirection.down,
    );
  }
}

bool _containsPoint(List<BoundaryPointMm> polygon, BoundaryPointMm point) {
  var inside = false;
  for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    final a = polygon[j];
    final b = polygon[i];
    if (_pointOnSegment(point, a, b)) return true;

    final crosses = (a.yMm > point.yMm) != (b.yMm > point.yMm);
    if (!crosses) continue;
    final intersectionX = a.xMm +
        (point.yMm - a.yMm) * (b.xMm - a.xMm) /
            (b.yMm - a.yMm);
    if (point.xMm < intersectionX) inside = !inside;
  }
  return inside;
}

bool _pointOnSegment(
  BoundaryPointMm point,
  BoundaryPointMm a,
  BoundaryPointMm b,
) {
  final cross = (point.yMm - a.yMm) * (b.xMm - a.xMm) -
      (point.xMm - a.xMm) * (b.yMm - a.yMm);
  if (cross != 0) return false;
  final minX = a.xMm < b.xMm ? a.xMm : b.xMm;
  final maxX = a.xMm > b.xMm ? a.xMm : b.xMm;
  final minY = a.yMm < b.yMm ? a.yMm : b.yMm;
  final maxY = a.yMm > b.yMm ? a.yMm : b.yMm;
  return point.xMm >= minX &&
      point.xMm <= maxX &&
      point.yMm >= minY &&
      point.yMm <= maxY;
}
