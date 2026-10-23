import 'boundary_construction_registry.dart';
import 'boundary_host_migration.dart';
import 'project_identity.dart';
import 'project_model.dart';
import 'surface_transition_graph.dart';
import 'surfaces.dart';

typedef CanonicalSpaceIdResolver = SpaceId? Function(String surfaceSpaceId);

/// Resolves route transitions using canonical physical construction metadata.
///
/// Shared-wall penetration is permitted only when both wall faces resolve to
/// the same thickness and material. Canonical route surfaces are projected
/// through the legacy geometry model only for transition calculation; the
/// returned candidate always preserves the caller's original surface identity.
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
    final graphFromSurface = _legacyGeometryAlias(
      level: level,
      surface: fromSurface,
      edgeOrderResolver: edgeOrderResolver,
      canonicalSpaceIdResolver: canonicalSpaceIdResolver,
    );
    final graphToSurface = _legacyGeometryAlias(
      level: level,
      surface: toSurface,
      edgeOrderResolver: edgeOrderResolver,
      canonicalSpaceIdResolver: canonicalSpaceIdResolver,
    );
    if (graphFromSurface == null ||
        graphToSurface == null ||
        graphFromSurface.spaceId != fromSpace.id) {
      return null;
    }

    final candidates = SurfaceTransitionGraph.candidates(
      level: level,
      fromSpace: fromSpace,
      fromSurface: graphFromSurface,
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
      if (!_sameSurfaceIdentity(
            candidate.toSurface,
            graphToSurface,
            edgeOrderResolver,
            canonicalSpaceIdResolver,
          ) ||
          candidate.toPoint != toPoint) {
        continue;
      }
      if (candidate.kind == SurfaceTransitionKind.roomPenetration &&
          candidate.penetrationRequirement?.hostThicknessMm == null) {
        return null;
      }

      // Geometry may be materialized by legacy space ids/ordinals, but the
      // route aggregate must retain the identity regime supplied by its caller.
      return SurfaceTransitionCandidate(
        id: candidate.id,
        kind: candidate.kind,
        fromSurface: fromSurface,
        fromPoint: fromPoint,
        toSurface: toSurface,
        toPoint: toPoint,
        penetrationRequirement: candidate.penetrationRequirement,
      );
    }
    return null;
  }

  static RoomSurfaceRef? _legacyGeometryAlias({
    required BuildingLevel level,
    required RoomSurfaceRef surface,
    required List<BoundaryEdgeId>? Function(String spaceId) edgeOrderResolver,
    required CanonicalSpaceIdResolver canonicalSpaceIdResolver,
  }) {
    EngineeringSpace? legacySpace;
    for (final candidate in level.spaces) {
      if (candidate.id == surface.spaceId) {
        legacySpace = candidate;
        break;
      }
      final canonicalId = canonicalSpaceIdResolver(candidate.id);
      if (canonicalId?.value == surface.spaceId) {
        legacySpace = candidate;
        break;
      }
    }
    if (legacySpace == null) return null;

    return switch (surface.type) {
      SurfacePlaneType.floor => RoomSurfaceRef.floor(legacySpace.id),
      SurfacePlaneType.ceiling => RoomSurfaceRef.ceiling(legacySpace.id),
      SurfacePlaneType.wall => _legacyWallAlias(
          legacySpace.id,
          surface,
          edgeOrderResolver,
        ),
    };
  }

  static RoomSurfaceRef? _legacyWallAlias(
    String legacySpaceId,
    RoomSurfaceRef surface,
    List<BoundaryEdgeId>? Function(String spaceId) edgeOrderResolver,
  ) {
    final edgeId = surface.boundaryEdgeId;
    if (edgeId != null) {
      final ordered = edgeOrderResolver(legacySpaceId);
      if (ordered == null || !ordered.contains(edgeId)) return null;
      return RoomSurfaceRef.wallByBoundaryEdge(legacySpaceId, edgeId);
    }
    final ordinal = surface.wallIndex;
    if (ordinal == null || ordinal < 0) return null;
    return RoomSurfaceRef.wall(legacySpaceId, ordinal);
  }

  static bool _sameSurfaceIdentity(
    RoomSurfaceRef left,
    RoomSurfaceRef right,
    List<BoundaryEdgeId>? Function(String spaceId) edgeOrderResolver,
    CanonicalSpaceIdResolver canonicalSpaceIdResolver,
  ) {
    if (left == right) return true;
    if (left.type != right.type) return false;
    final leftSpace = canonicalSpaceIdResolver(left.spaceId);
    final rightSpace = canonicalSpaceIdResolver(right.spaceId);
    if (leftSpace == null || rightSpace == null || leftSpace != rightSpace) {
      return false;
    }
    if (left.type != SurfacePlaneType.wall) return true;

    final leftHost = _hostFor(
      left,
      edgeOrderResolver,
      canonicalSpaceIdResolver,
    );
    final rightHost = _hostFor(
      right,
      edgeOrderResolver,
      canonicalSpaceIdResolver,
    );
    return leftHost != null && leftHost == rightHost;
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
