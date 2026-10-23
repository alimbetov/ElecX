import 'boundary_topology.dart';
import 'project_aggregate.dart';
import 'project_identity.dart';
import 'vertical_core.dart';
import 'vertical_core_slab_crossing_resolver.dart';

/// Ordered physical path through one stable vertical core.
///
/// Each step owns a concrete SlabId through [VerticalCoreSlabCrossing]; there is
/// no direct L1→L3 teleport even when the caller requests a multi-level route.
final class VerticalCorePath {
  VerticalCorePath({
    required this.verticalCoreId,
    required this.fromLevelId,
    required this.toLevelId,
    required Iterable<VerticalCoreSlabCrossing> crossings,
  }) : crossings = List.unmodifiable(crossings) {
    if (this.crossings.isEmpty) {
      throw ArgumentError('Vertical core path requires at least one crossing.');
    }
  }

  final VerticalCoreId verticalCoreId;
  final LevelId fromLevelId;
  final LevelId toLevelId;
  final List<VerticalCoreSlabCrossing> crossings;

  VerticalCoreCrossingDirection get direction => crossings.first.direction;
}

/// Resolves a fail-closed multi-level path through one [ProjectVerticalCore].
///
/// The core's served levels are ordered by canonical elevation. Every adjacent
/// pair between [fromLevelId] and [toLevelId] must have a physical slab crossing
/// at [planPoint]. If one pair cannot be proven, the whole path is rejected.
abstract final class VerticalCorePathResolver {
  static VerticalCorePath? resolve({
    required ProjectAggregateRoot project,
    required ProjectVerticalCore core,
    required LevelId fromLevelId,
    required LevelId toLevelId,
    required BoundaryPointMm planPoint,
  }) {
    if (fromLevelId == toLevelId ||
        !core.servesLevel(fromLevelId) ||
        !core.servesLevel(toLevelId)) {
      return null;
    }

    final levels = <ProjectLevelEntity>[];
    for (final levelId in core.levelIds) {
      final level = project.index.level(levelId);
      if (level == null || level.buildingId != core.buildingId) return null;
      levels.add(level);
    }
    levels.sort((a, b) => a.elevationMm.compareTo(b.elevationMm));

    final fromIndex = levels.indexWhere((level) => level.id == fromLevelId);
    final toIndex = levels.indexWhere((level) => level.id == toLevelId);
    if (fromIndex < 0 || toIndex < 0 || fromIndex == toIndex) return null;

    final step = fromIndex < toIndex ? 1 : -1;
    final crossings = <VerticalCoreSlabCrossing>[];
    var index = fromIndex;
    while (index != toIndex) {
      final nextIndex = index + step;
      final crossing = VerticalCoreSlabCrossingResolver.resolve(
        project: project,
        core: core,
        fromLevelId: levels[index].id,
        toLevelId: levels[nextIndex].id,
        planPoint: planPoint,
      );
      if (crossing == null) return null;
      crossings.add(crossing);
      index = nextIndex;
    }

    return VerticalCorePath(
      verticalCoreId: core.id,
      fromLevelId: fromLevelId,
      toLevelId: toLevelId,
      crossings: crossings,
    );
  }
}
