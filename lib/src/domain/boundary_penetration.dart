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
/// always keep the same [penetrationId] and [routeId]. The exit anchor can be
/// rendered on the opposite surface as the start point for continuing the same
/// logical route.
final class BoundaryPenetrationAnchor {
  BoundaryPenetrationAnchor({
    required this.id,
    required this.penetrationId,
    required this.side,
    required this.surface,
    required this.point,
    required this.routeId,
  }) {
    if (id.isEmpty) throw ArgumentError('Penetration anchor id is required.');
    if (penetrationId.isEmpty) {
      throw ArgumentError('Penetration id is required.');
    }
    if (routeId.isEmpty) throw ArgumentError('Route id is required.');
  }

  final String id;
  final String penetrationId;
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
/// larger for a future angled penetration, but never smaller.
final class BoundaryPenetration {
  BoundaryPenetration({
    required this.id,
    required this.hostKind,
    required this.entryAnchor,
    required this.exitAnchor,
    required this.hostThicknessMm,
    required this.pathLengthMm,
    this.materialId,
  }) {
    if (id.isEmpty) throw ArgumentError('Penetration id is required.');
    if (hostThicknessMm <= 0) {
      throw ArgumentError.value(
        hostThicknessMm,
        'hostThicknessMm',
        'Must be positive.',
      );
    }
    if (pathLengthMm < hostThicknessMm) {
      throw ArgumentError.value(
        pathLengthMm,
        'pathLengthMm',
        'Must not be shorter than the host thickness.',
      );
    }
    if (entryAnchor.penetrationId != id || exitAnchor.penetrationId != id) {
      throw ArgumentError('Both anchors must belong to penetration $id.');
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
  }

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
  }) =>
      BoundaryPenetration(
        id: id,
        hostKind: hostKind,
        entryAnchor: BoundaryPenetrationAnchor(
          id: '$id:entry',
          penetrationId: id,
          side: PenetrationAnchorSide.entry,
          surface: entrySurface,
          point: entryPoint,
          routeId: routeId,
        ),
        exitAnchor: BoundaryPenetrationAnchor(
          id: '$id:exit',
          penetrationId: id,
          side: PenetrationAnchorSide.exit,
          surface: exitSurface,
          point: exitPoint,
          routeId: routeId,
        ),
        hostThicknessMm: hostThicknessMm,
        pathLengthMm: hostThicknessMm,
        materialId: materialId,
      );

  final String id;
  final BoundaryPenetrationHostKind hostKind;
  final BoundaryPenetrationAnchor entryAnchor;
  final BoundaryPenetrationAnchor exitAnchor;
  final int hostThicknessMm;
  final double pathLengthMm;
  final String? materialId;

  String get routeId => entryAnchor.routeId;

  /// Physical route length contributed by the hidden part inside the wall/slab.
  double get routeLengthContributionMm => pathLengthMm;

  BoundaryPenetrationAnchor oppositeAnchor(RoomSurfaceRef surface) {
    if (entryAnchor.surface == surface) return exitAnchor;
    if (exitAnchor.surface == surface) return entryAnchor;
    throw StateError('Surface ${surface.id} does not belong to penetration $id.');
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
  });

  final BoundaryPenetrationHostKind hostKind;
  final int? hostThicknessMm;
  final String? materialId;

  BoundaryPenetration create({
    required String penetrationId,
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
    );
  }
}
