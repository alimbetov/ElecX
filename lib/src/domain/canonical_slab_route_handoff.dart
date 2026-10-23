import 'project_aggregate.dart';
import 'project_identity.dart';
import 'slab_topology.dart';
import 'surfaces.dart';

enum CanonicalSlabRouteHandoffDirection {
  upward,
  downward,
}

/// Identity-only plan for continuing one route between two canonical spaces
/// through one physical inter-level slab.
///
/// Geometry is intentionally not inferred here. [CanonicalSlabTransitionResolver]
/// remains responsible for proving that a concrete XY point can physically
/// cross the slab. This planner owns the stable identity contract used before
/// the editor switches levels and loses its transient route draft projection.
final class CanonicalSlabRouteHandoffPlan {
  const CanonicalSlabRouteHandoffPlan({
    required this.slab,
    required this.direction,
    required this.fromSpaceId,
    required this.toSpaceId,
    required this.fromLevelId,
    required this.toLevelId,
    required this.fromSurface,
    required this.toSurface,
    required this.entryFace,
    required this.exitFace,
  });

  final ProjectSlab slab;
  final CanonicalSlabRouteHandoffDirection direction;
  final SpaceId fromSpaceId;
  final SpaceId toSpaceId;
  final LevelId fromLevelId;
  final LevelId toLevelId;
  final RoomSurfaceRef fromSurface;
  final RoomSurfaceRef toSurface;
  final SlabFaceRef entryFace;
  final SlabFaceRef exitFace;

  SlabId get slabId => slab.id;

  bool get isUpward => direction == CanonicalSlabRouteHandoffDirection.upward;
}

/// Resolves stable vertical route identity before any legacy workspace level
/// switch is allowed to clear transient editor state.
///
/// The plan is produced only when both spaces exist, belong to different
/// levels of one canonical building, and exactly one inter-level [ProjectSlab]
/// owns the ordered lower/upper level pair. No fallback by level number,
/// display order or geometry label is permitted.
abstract final class CanonicalSlabRouteHandoffPlanner {
  static CanonicalSlabRouteHandoffPlan? resolve({
    required ProjectAggregateRoot project,
    required SpaceId fromSpaceId,
    required SpaceId toSpaceId,
  }) {
    if (fromSpaceId == toSpaceId) return null;

    final fromSpace = project.index.space(fromSpaceId);
    final toSpace = project.index.space(toSpaceId);
    if (fromSpace == null || toSpace == null) return null;
    if (fromSpace.levelId == toSpace.levelId) return null;

    final fromLevel = project.index.level(fromSpace.levelId);
    final toLevel = project.index.level(toSpace.levelId);
    if (fromLevel == null || toLevel == null) return null;
    if (fromLevel.buildingId != toLevel.buildingId) return null;
    if (fromLevel.elevationMm == toLevel.elevationMm) return null;

    final fromIsLower = fromLevel.elevationMm < toLevel.elevationMm;
    final lowerLevel = fromIsLower ? fromLevel : toLevel;
    final upperLevel = fromIsLower ? toLevel : fromLevel;

    ProjectSlab? slab;
    for (final slabId in project.index.slabsForLevel(lowerLevel.id)) {
      final candidate = project.index.slab(slabId);
      if (candidate == null ||
          candidate.kind != SlabKind.interLevel ||
          candidate.buildingId != lowerLevel.buildingId ||
          candidate.belowLevelId != lowerLevel.id ||
          candidate.aboveLevelId != upperLevel.id) {
        continue;
      }
      if (slab != null) {
        // Never select one physical host by map/index ordering.
        return null;
      }
      slab = candidate;
    }
    if (slab == null) return null;

    final direction = fromIsLower
        ? CanonicalSlabRouteHandoffDirection.upward
        : CanonicalSlabRouteHandoffDirection.downward;
    final entryFace = fromIsLower ? slab.belowFace : slab.aboveFace;
    final exitFace = fromIsLower ? slab.aboveFace : slab.belowFace;
    if (slab.levelForFace(entryFace) != fromLevel.id ||
        slab.levelForFace(exitFace) != toLevel.id) {
      return null;
    }

    return CanonicalSlabRouteHandoffPlan(
      slab: slab,
      direction: direction,
      fromSpaceId: fromSpaceId,
      toSpaceId: toSpaceId,
      fromLevelId: fromLevel.id,
      toLevelId: toLevel.id,
      fromSurface: fromIsLower
          ? RoomSurfaceRef.ceiling(fromSpaceId.value)
          : RoomSurfaceRef.floor(fromSpaceId.value),
      toSurface: fromIsLower
          ? RoomSurfaceRef.floor(toSpaceId.value)
          : RoomSurfaceRef.ceiling(toSpaceId.value),
      entryFace: entryFace,
      exitFace: exitFace,
    );
  }
}
