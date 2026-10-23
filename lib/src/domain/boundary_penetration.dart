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
  /// Legacy scalar compatibility boundary.
  BoundaryPenetrationAnchor({
    required String id,
    required String penetrationId,
    required PenetrationAnchorSide side,
    required RoomSurfaceRef surface,
    required SurfacePointMm point,
    required String routeId,
  }) : this.typed(
          id: id,
          penetrationId: BoundaryPenetrationId(penetrationId),
          side: side,
          surface: surface,
          point: point,
          routeId: routeId,
        );

  /// Canonical constructor. New authoring must enter with an already allocated
  /// or reserved typed penetration identity.
  BoundaryPenetrationAnchor.typed({
    required this.id,
    required this.penetrationId,
    required this.side,
    required this.surface,
    required this.point,
    required this.routeId,
  }) {
    if (id.isEmpty) throw ArgumentError('Penetration anchor id is required.');
    if (penetrationId.trim().isEmpty) {
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
  BoundaryPenetration({
    required String id,
    required BoundaryPenetrationHostKind hostKind,
    required BoundaryPenetrationAnchor entryAnchor,
    required BoundaryPenetrationAnchor exitAnchor,
    required int hostThicknessMm,
    required double pathLengthMm,
    String? materialId,
    SlabId? slabId,
    VerticalCoreId? verticalCoreId,
  }) : this.typed(
          id: BoundaryPenetrationId(id),
          hostKind: hostKind,
          entryAnchor: entryAnchor,
          exitAnchor: exitAnchor,
          hostThicknessMm: hostThicknessMm,
          pathLengthMm: pathLengthMm,
          materialId: materialId,
          slabId: slabId,
          verticalCoreId: verticalCoreId,
        );

  /// Canonical aggregate constructor. New authoring must use the already
  /// allocated/reserved [BoundaryPenetrationId] without scalar reallocation.
  BoundaryPenetration.typed({
    required this.id,
    required this.hostKind,
    required this.entryAnchor,
    required this.exitAnchor,
    required this.hostThicknessMm,
    required this.pathLengthMm,
    this.materialId,
    this.slabId,
    this.verticalCoreId,
  }) {
    if (id.trim().isEmpty) {
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
    if (entryAnchor.penetrationId != id || exitAnchor.penetrationId != id) {
      throw ArgumentError('Both anchors must belong to penetration $id.');
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

  /// Low-level compatibility factory for scalar persisted identifiers.
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
  }) =>
      BoundaryPenetration.normalTyped(
        id: BoundaryPenetrationId(id),
        hostKind: hostKind,
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

  /// Canonical low-level factory using a preallocated typed identity.
  factory BoundaryPenetration.normalTyped({
    required BoundaryPenetrationId id,
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
  }) =>
      BoundaryPenetration.typed(
        id: id,
        hostKind: hostKind,
        entryAnchor: BoundaryPenetrationAnchor.typed(
          id: '${id.value}:entry',
          penetrationId: id,
          side: PenetrationAnchorSide.entry,
          surface: entrySurface,
          point: entryPoint,
          routeId: routeId,
        ),
        exitAnchor: BoundaryPenetrationAnchor.typed(
          id: '${id.value}:exit',
          penetrationId: id,
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

  /// Compatibility factory for persisted/legacy scalar ids.
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
      BoundaryPenetration.slabTyped(
        id: BoundaryPenetrationId(id),
        slabId: slabId,
        entrySurface: entrySurface,
        entryPoint: entryPoint,
        exitSurface: exitSurface,
        exitPoint: exitPoint,
        hostThicknessMm: hostThicknessMm,
        routeId: routeId,
        materialId: materialId,
        verticalCoreId: verticalCoreId,
      );

  /// Canonical slab factory. Slab authoring cannot regress to a scalar id.
  factory BoundaryPenetration.slabTyped({
    required BoundaryPenetrationId id,
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
      BoundaryPenetration.normalTyped(
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
    return BoundaryPenetration.normalTyped(
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
