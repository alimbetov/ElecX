import 'boundary_construction_registry.dart';
import 'boundary_host_migration.dart';
import 'project_identity.dart';
import 'project_model.dart';
import 'surface_transition_graph.dart';
import 'surfaces.dart';

typedef CanonicalSpaceIdResolver = SpaceId? Function(String legacySpaceId);

/// Resolves route transitions using canonical physical construction metadata.
///
/// Shared-wall penetration is permitted only when both wall faces resolve to
/// the same thickness and material. This prevents one physical wall from being
/// interpreted differently depending on which room the engineer is viewing.
abstract final class BoundaryConstructionTransitionResolver {
  static SurfaceTransitionCandidate? resolve({
    required BuildingLevel level,
    required EngineeringSpace fromSpace,
    required RoomSurfaceRef fromSurface,
    required SurfacePointMm fromPoint,
    required RoomSurfaceRef toSurface,
    required SurfacePointMm toPoint,
    required BoundaryConstructionRegistry constructions,
    required List<BoundaryEdgeId>? Function(String spaceId) edgeOrderResolver,
    required CanonicalSpaceIdResolver canonicalSpaceIdResolver,
    int roomHeightMm = 3000,
    int toleranceMm = 2,
  }) {
    final candidates = SurfaceTransitionGraph.candidates(
      level: level,
      fromSpace: fromSpace,
      fromSurface: fromSurface,
      point: fromPoint,
      roomHeightMm: roomHeightMm,
      toleranceMm: toleranceMm,
      boundaryEdgeOrderResolver: edgeOrderResolver,
      thicknessResolver: (from, to) => _sharedWallProfile(
        constructions,
        from,
        to,
        edgeOrderResolver,
        canonicalSpaceIdResolver,
      )?.thicknessMm,
      materialResolver: (from, to) => _sharedWallProfile(
        constructions,
        from,
        to,
        edgeOrderResolver,
        canonicalSpaceIdResolver,
      )?.materialId,
    );
    for (final candidate in candidates) {
      if (candidate.toSurface == toSurface && candidate.toPoint == toPoint) {
        if (candidate.kind == SurfaceTransitionKind.roomPenetration &&
            candidate.penetrationRequirement?.hostThicknessMm == null) {
          return null;
        }
        return candidate;
      }
    }
    return null;
  }

  static BoundaryConstructionProfile? _sharedWallProfile(
    BoundaryConstructionRegistry registry,
    RoomSurfaceRef from,
    RoomSurfaceRef to,
    List<BoundaryEdgeId>? Function(String spaceId) edgeOrderResolver,
    CanonicalSpaceIdResolver canonicalSpaceIdResolver,
  ) {
    if (from.type != SurfacePlaneType.wall ||
        to.type != SurfacePlaneType.wall ||
        from.spaceId == to.spaceId) {
      return null;
    }
    final fromHost = _hostFor(
      from,
      edgeOrderResolver,
      canonicalSpaceIdResolver,
    );
    final toHost = _hostFor(
      to,
      edgeOrderResolver,
      canonicalSpaceIdResolver,
    );
    if (fromHost == null || toHost == null) return null;
    final left = registry[fromHost];
    final right = registry[toHost];
    if (left == null || right == null) return null;
    if (left.kind != BoundaryConstructionKind.wall ||
        right.kind != BoundaryConstructionKind.wall ||
        left.thicknessMm != right.thicknessMm ||
        left.materialId != right.materialId ||
        left.fireRatingId != right.fireRatingId) {
      return null;
    }
    return left;
  }

  static BoundaryEdgeHostRef? _hostFor(
    RoomSurfaceRef surface,
    List<BoundaryEdgeId>? Function(String spaceId) edgeOrderResolver,
    CanonicalSpaceIdResolver canonicalSpaceIdResolver,
  ) {
    final canonicalSpaceId = canonicalSpaceIdResolver(surface.spaceId);
    if (canonicalSpaceId == null) return null;
    final direct = surface.boundaryEdgeId;
    if (direct != null) {
      return BoundaryEdgeHostRef(
        spaceId: canonicalSpaceId,
        edgeId: direct,
      );
    }
    final ordinal = surface.wallIndex;
    final ordered = edgeOrderResolver(surface.spaceId);
    if (ordinal == null ||
        ordered == null ||
        ordinal < 0 ||
        ordinal >= ordered.length) {
      return null;
    }
    return BoundaryEdgeHostRef(
      spaceId: canonicalSpaceId,
      edgeId: ordered[ordinal],
    );
  }
}
