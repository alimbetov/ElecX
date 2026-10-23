import 'project_identity.dart';
import 'surfaces.dart';

enum BoundaryPenetrationHostKind {
  wall,
  slab,
}

enum PenetrationAnchorSide {
  entry,
  exit,
}

/// One durable continuation point exposed on a visible surface.
///
/// The entry and exit anchors of one penetration are created together and
/// always keep the same typed [penetrationId] and [routeId]. The exit anchor can
/// be rendered on the opposite surface as the start point for continuing the
/// same logical route.
final class BoundaryPenetrationAnchor {
  BoundaryPenetrationAnchor({
    required this.id,
    required String penetrationId,
    required this.side,
    required this.surface,
    required this.point,
    required this.routeId,
  }) : penetrationId = BoundaryPenetrationId(penetrationId) {
    if (id.isEmpty) throw ArgumentError('Penetration anchor id is required.');
    if (this.penetrationId.trim().isEmpty) {
      throw ArgumentError('Penetration id is required.');
    }
    if (routeId.isEmpty) throw ArgumentError('Route id is required.');
    if (point.xMm < 0 || point.yMm < 0) {
      throw ArgumentError(
        'Penetration anchor coordinates must be non-negative.',
      );
    }
  }

  final String id;
  final BoundaryPenetrationId penetrationId;
  final PenetrationAnchorSide side;
  final RoomSurfaceRef surface;
  final SurfacePointMm point;
  final String routeId;

  bool get isContinuationStart => side == PenetrationAnchorSide.exit;
}

/// Physical hole/sleeve through a building boundary.
///
/// A route is not allowed to teleport between non-adjacent surfaces: a
/// physical wall/slab crossing is represented by this entity and two paired
/// anchors. [hostThicknessMm] is the normal thickness of the construction.
/// [pathLengthMm] is the actual cable length through it and therefore may be
/// larger for an angled penetration, but never smaller.
///
/// Canonical slab penetrations additionally own [slabId]. When the penetration
/// is part of a P7B riser/shaft route, [verticalCoreId] binds that concrete slab
/// crossing to the stable multi-level routing volume. Direct slab crossings and
/// legacy records may leave [verticalCoreId] null.
final class BoundaryPenetration {
  /// Compatibility constructor for persisted legacy scalar ids.
  ///
  /// The scalar is immediately promoted to [BoundaryPenetrationId]. New
  /// authoring code should allocate the typed identity before entering this
  /// aggregate; JSON persistence continues to store the exact scalar value.
  BoundaryPenetration({
    required String id,
    required this.hostKind,
    required this.entryAnchor,
    required this.exitAnchor,
    required this.hostThicknessMm,
    required this.pathLengthMm,
    this.materialId,
    this.slabId,
    this.verticalCoreId,
  }) : id = BoundaryPenetrationId(id) {
    if (this.id.trim().isEmpty) {
      throw ArgumentError('Penetration id is required.');
    }
    if (hostThicknessMm <= 0) {
      throw ArgumentError.value(
        hostThicknessMm,
        'hostThicknessMm',
        'Must be positive.',
      );
    }
    if (!pathLengthMm.isFinite || pathLengthMm < hostThicknessMm) {
      throw ArgumentError.value(
        pathLengthMm,
        'pathLengthMm',
        'Must be finite and not shorter than the host thickness.',
      );
    }
    if (materialId != null && materialId!.isEmpty) {
      throw ArgumentError('materialId must be null or non-empty.');
    }
    if (hostKind == BoundaryPenetrationHostKind.wall && slabId != null) {
      throw ArgumentError('Wall penetration cannot reference a SlabId.');
    }
    if (hostKind == BoundaryPenetrationHostKind.wall &&
        verticalCoreId != null) {
      throw ArgumentError(
        'Wall penetration cannot reference a VerticalCoreId.',
      );
    }
    if (verticalCoreId != null && slabId == null) {
      throw ArgumentError(
        'VerticalCore-owned penetration requires a stable SlabId.',
      );
    }
    if (entryAnchor.penetrationId != this.id ||
        exitAnchor.penetrationId != this.id) {
      throw ArgumentError(
          'Both anchors must belong to penetration ${this.id}.');
    }
    if (entryAnchor.id == exitAnchor.id) {
      throw ArgumentError('Penetration anchors must have distinct identities.');
    }
    if (entryAnchor.side != PenetrationAnchorSide.entry ||
        exitAnchor.side != PenetrationAnchorSide.exit) {
      throw ArgumentError('Penetration anchors must be entry then exit.');
    }
    if (entryAnchor.routeId != exitAnchor.routeId) {
      throw ArgumentError('Both penetration anchors must continue one route.');
    }
    if (entryAnchor.surface == exitAnchor.surface) {
      throw ArgumentError(
        'A physical penetration must connect two different surfaces.',
      );
    }
    _validateHostSurfaces();
  }

  /// Low-level compatibility factory. Canonical authoring reaches it through a
  /// typed [BoundaryPenetrationRequirement] or [BoundaryPenetration.slab].
  factory BoundaryPenetration.normal({
    required String id,
    required BoundaryPenetrationHostKind hostKind,
    required RoomSurfaceRef entrySurface,
    required SurfacePointMm entryPoint,
    required RoomSurfaceRef exitSurface,
    required SurfacePointMm exitPoint,
    required int hostThicknessMm,
    required String routeId,
    String? materialId,
    SlabId? slabId,
    VerticalCoreId? verticalCoreId,
  }) {
    final typedId = BoundaryPenetrationId(id);
    return BoundaryPenetration(
      id: typedId,
      hostKind: hostKind,
      entryAnchor: BoundaryPenetrationAnchor(
        id: '${typedId.value}:entry',
        penetrationId: typedId,
        side: PenetrationAnchorSide.entry,
        surface: entrySurface,
        point: entryPoint,
        routeId: routeId,
      ),
      exitAnchor: BoundaryPenetrationAnchor(
        id: '${typedId.value}:exit',
        penetrationId: typedId,
        side: PenetrationAnchorSide.exit,
        surface: exitSurface,
        point: exitPoint,
        routeId: routeId,
      ),
      hostThicknessMm: hostThicknessMm,
      pathLengthMm: hostThicknessMm.toDouble(),
      materialId: materialId,
      slabId: slabId,
      verticalCoreId: verticalCoreId,
    );
  }

  /// Compatibility factory for persisted/legacy scalar ids.
  ///
  /// Canonical authoring should pass a preallocated [BoundaryPenetrationId];
  /// because the extension type implements String, the exact persisted scalar
  /// is preserved without regeneration.
  factory BoundaryPenetration.slab({
    required String id,
    required SlabId slabId,
    required RoomSurfaceRef entrySurface,
    required SurfacePointMm entryPoint,
    required RoomSurfaceRef exitSurface,
    required SurfacePointMm exitPoint,
    required int hostThicknessMm,
    required String routeId,
    String? materialId,
    VerticalCoreId? verticalCoreId,
  }) =>
      BoundaryPenetration.normal(
        id: id,
        hostKind: BoundaryPenetrationHostKind.slab,
        entrySurface: entrySurface,
        entryPoint: entryPoint,
        exitSurface: exitSurface,
        exitPoint: exitPoint,
        hostThicknessMm: hostThicknessMm,
        routeId: routeId,
        materialId: materialId,
        slabId: slabId,
        verticalCoreId: verticalCoreId,
      );

  final BoundaryPenetrationId id;
  final BoundaryPenetrationHostKind hostKind;
  final BoundaryPenetrationAnchor entryAnchor;
  final BoundaryPenetrationAnchor exitAnchor;
  final int hostThicknessMm;
  final double pathLengthMm;
  final String? materialId;

  /// Stable physical host identity for a canonical slab crossing.
  ///
  /// Null is permitted only for legacy slab penetration records that predate
  /// SlabId migration. New canonical slab authoring must populate this field.
  final SlabId? slabId;

  /// Stable P7B routing-volume identity when this slab penetration is part of a
  /// multi-level riser/shaft path. Direct slab crossings intentionally keep it
  /// null.
  final VerticalCoreId? verticalCoreId;

  String get routeId => entryAnchor.routeId;

  bool get hasStableSlabHostIdentity =>
      hostKind != BoundaryPenetrationHostKind.slab || slabId != null;

  /// Physical route length contributed by the hidden part inside the wall/slab.
  double get routeLengthContributionMm => pathLengthMm;

  BoundaryPenetrationAnchor oppositeAnchor(RoomSurfaceRef surface) {
    if (entryAnchor.surface == surface) return exitAnchor;
    if (exitAnchor.surface == surface) return entryAnchor;
    throw StateError(
      'Surface ${surface.id} does not belong to penetration $id.',
    );
  }

  void _validateHostSurfaces() {
    switch (hostKind) {
      case BoundaryPenetrationHostKind.wall:
        if (entryAnchor.surface.type != SurfacePlaneType.wall ||
            exitAnchor.surface.type != SurfacePlaneType.wall) {
          throw ArgumentError('Wall penetrations must connect two wall faces.');
        }
        if (entryAnchor.surface.spaceId == exitAnchor.surface.spaceId) {
          throw ArgumentError(
            'Wall penetrations must connect different spaces.',
          );
        }
      case BoundaryPenetrationHostKind.slab:
        final types = <SurfacePlaneType>{
          entryAnchor.surface.type,
          exitAnchor.surface.type,
        };
        if (!types.contains(SurfacePlaneType.floor) ||
            !types.contains(SurfacePlaneType.ceiling) ||
            types.length != 2) {
          throw ArgumentError(
            'Slab penetrations must connect one ceiling and one floor.',
          );
        }
    }
  }
}

/// Information carried by a transition candidate before the user commits the
/// actual penetration. Thickness may be resolved from a wall/slab construction
/// registry when the candidate is discovered, or supplied explicitly at
/// commit time.
final class BoundaryPenetrationRequirement {
  const BoundaryPenetrationRequirement({
    required this.hostKind,
    this.hostThicknessMm,
    this.materialId,
    this.slabId,
    this.verticalCoreId,
  });

  final BoundaryPenetrationHostKind hostKind;
  final int? hostThicknessMm;
  final String? materialId;
  final SlabId? slabId;
  final VerticalCoreId? verticalCoreId;

  /// Legacy scalar compatibility boundary.
  BoundaryPenetration create({
    required String penetrationId,
    required String routeId,
    required RoomSurfaceRef entrySurface,
    required SurfacePointMm entryPoint,
    required RoomSurfaceRef exitSurface,
    required SurfacePointMm exitPoint,
    int? thicknessMm,
  }) =>
      createTyped(
        penetrationId: BoundaryPenetrationId(penetrationId),
        routeId: routeId,
        entrySurface: entrySurface,
        entryPoint: entryPoint,
        exitSurface: exitSurface,
        exitPoint: exitPoint,
        thicknessMm: thicknessMm,
      );

  /// Canonical authoring boundary. The durable identity must already be
  /// allocated/reserved before the physical penetration is materialized.
  BoundaryPenetration createTyped({
    required BoundaryPenetrationId penetrationId,
    required String routeId,
    required RoomSurfaceRef entrySurface,
    required SurfacePointMm entryPoint,
    required RoomSurfaceRef exitSurface,
    required SurfacePointMm exitPoint,
    int? thicknessMm,
  }) {
    final resolvedThickness = thicknessMm ?? hostThicknessMm;
    if (resolvedThickness == null) {
      throw StateError(
        'Physical thickness is required before committing a penetration.',
      );
    }
    if (hostKind == BoundaryPenetrationHostKind.slab && slabId == null) {
      throw StateError(
        'Stable SlabId is required before committing a new slab penetration.',
      );
    }
    if (hostKind != BoundaryPenetrationHostKind.slab &&
        verticalCoreId != null) {
      throw StateError(
        'VerticalCoreId is only valid for a slab penetration requirement.',
      );
    }
    return BoundaryPenetration.normal(
      id: penetrationId,
      hostKind: hostKind,
      entrySurface: entrySurface,
      entryPoint: entryPoint,
      exitSurface: exitSurface,
      exitPoint: exitPoint,
      hostThicknessMm: resolvedThickness,
      routeId: routeId,
      materialId: materialId,
      slabId: slabId,
      verticalCoreId: verticalCoreId,
    );
  }
}
