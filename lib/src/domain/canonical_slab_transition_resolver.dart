import 'boundary_penetration.dart';
import 'project_aggregate.dart';
import 'project_identity.dart';
import 'project_model.dart';
import 'slab_topology.dart';
import 'surface_transition_graph.dart';
import 'surfaces.dart';

typedef CanonicalSlabSpaceIdResolver = SpaceId? Function(String surfaceSpaceId);

/// Resolves one physical ceiling↔floor crossing through the canonical slab
/// graph while delegating plan/vertical geometry checks to
/// [SurfaceTransitionGraph.levelPenetration].
///
/// The resolver fails closed when the two canonical spaces do not belong to
/// different levels of the same building, when no unique inter-level [SlabId]
/// owns that level pair, or when the legacy/projection geometry does not prove
/// a physically valid penetration at [point].
abstract final class CanonicalSlabTransitionResolver {
  static SurfaceTransitionCandidate? resolve({
    required ProjectAggregateRoot project,
    required Iterable<BuildingLevel> buildingLevels,
    required BuildingLevel fromLevel,
    required EngineeringSpace fromSpace,
    required RoomSurfaceRef fromSurface,
    required SurfacePointMm point,
    required int fromRoomHeightMm,
    required BuildingLevel toLevel,
    required EngineeringSpace toSpace,
    required int toRoomHeightMm,
    required CanonicalSlabSpaceIdResolver canonicalSpaceIdResolver,
    int verticalToleranceMm = 2,
  }) {
    final canonicalFromSpaceId = canonicalSpaceIdResolver(fromSurface.spaceId);
    final canonicalToSpaceId = canonicalSpaceIdResolver(toSpace.id);
    if (canonicalFromSpaceId == null || canonicalToSpaceId == null) return null;

    final canonicalFromSpace = project.index.space(canonicalFromSpaceId);
    final canonicalToSpace = project.index.space(canonicalToSpaceId);
    if (canonicalFromSpace == null || canonicalToSpace == null) return null;
    if (canonicalFromSpace.levelId == canonicalToSpace.levelId) return null;

    final canonicalFromLevel = project.index.level(canonicalFromSpace.levelId);
    final canonicalToLevel = project.index.level(canonicalToSpace.levelId);
    if (canonicalFromLevel == null || canonicalToLevel == null) return null;
    if (canonicalFromLevel.buildingId != canonicalToLevel.buildingId) {
      return null;
    }
    if (!_containsMaterializedLevels(buildingLevels, fromLevel, toLevel)) {
      return null;
    }

    final lowerLevel =
        canonicalFromLevel.elevationMm < canonicalToLevel.elevationMm
            ? canonicalFromLevel
            : canonicalToLevel;
    final upperLevel = identical(lowerLevel, canonicalFromLevel)
        ? canonicalToLevel
        : canonicalFromLevel;

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
        // Ambiguous physical ownership must never select one slab by ordering.
        return null;
      }
      slab = candidate;
    }
    if (slab == null) return null;

    // The editor still materializes legacy BuildingLevel ids, while ProjectSlab
    // owns canonical LevelId references. Projecting the already-proven
    // canonical identities onto the materialized geometry keeps those two
    // identity domains explicit: canonical ids prove topology; legacy objects
    // contribute geometry only. No adjacency or slab ownership is fabricated.
    final projectedFromLevel = _withCanonicalIdentity(
      fromLevel,
      canonicalFromLevel.id,
    );
    final projectedToLevel = _withCanonicalIdentity(
      toLevel,
      canonicalToLevel.id,
    );

    final geometric = SurfaceTransitionGraph.levelPenetration(
      buildingLevels: [projectedFromLevel, projectedToLevel],
      fromLevel: projectedFromLevel,
      fromSpace: fromSpace,
      fromSurface: fromSurface,
      point: point,
      fromRoomHeightMm: fromRoomHeightMm,
      toLevel: projectedToLevel,
      toSpace: toSpace,
      toRoomHeightMm: toRoomHeightMm,
      slabThicknessMm: slab.thicknessMm,
      slab: slab,
      verticalToleranceMm: verticalToleranceMm,
      materialId: slab.materialId,
    );
    if (geometric == null ||
        geometric.kind != SurfaceTransitionKind.levelPenetration) {
      return null;
    }

    return SurfaceTransitionCandidate(
      id: geometric.id,
      kind: geometric.kind,
      fromSurface: geometric.fromSurface,
      fromPoint: geometric.fromPoint,
      toSurface: geometric.toSurface,
      toPoint: geometric.toPoint,
      penetrationRequirement: BoundaryPenetrationRequirement(
        hostKind: BoundaryPenetrationHostKind.slab,
        hostThicknessMm: slab.thicknessMm,
        materialId: slab.materialId,
        slabId: slab.id,
      ),
    );
  }

  static BuildingLevel _withCanonicalIdentity(
    BuildingLevel materialized,
    LevelId canonicalId,
  ) =>
      BuildingLevel(
        id: canonicalId.value,
        name: materialized.name,
        elevationMm: materialized.elevationMm,
        spaces: materialized.spaces,
      );

  static bool _containsMaterializedLevels(
    Iterable<BuildingLevel> levels,
    BuildingLevel fromLevel,
    BuildingLevel toLevel,
  ) {
    var fromMatches = 0;
    var toMatches = 0;
    for (final level in levels) {
      if (level.id == fromLevel.id) fromMatches++;
      if (level.id == toLevel.id) toMatches++;
    }
    return fromMatches == 1 && toMatches == 1;
  }
}
