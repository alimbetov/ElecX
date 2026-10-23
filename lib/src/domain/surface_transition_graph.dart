import 'dart:math' as math;

import 'boundary_penetration.dart';
import 'geometry.dart';
import 'project_model.dart';
import 'surface_routing.dart';
import 'surfaces.dart';

enum SurfaceTransitionKind {
  wallToWall,
  wallToFloor,
  wallToCeiling,
  roomPenetration,
  levelPenetration,
}

typedef BoundaryThicknessResolver = int? Function(
  RoomSurfaceRef fromSurface,
  RoomSurfaceRef toSurface,
);

typedef BoundaryMaterialResolver = String? Function(
  RoomSurfaceRef fromSurface,
  RoomSurfaceRef toSurface,
);

/// One physical continuation point represented on two surface coordinate
/// systems. Both anchors refer to the same place in the building.
final class SurfaceTransitionCandidate {
  const SurfaceTransitionCandidate({
    required this.id,
    required this.kind,
    required this.fromSurface,
    required this.fromPoint,
    required this.toSurface,
    required this.toPoint,
    this.penetrationRequirement,
  });

  final String id;
  final SurfaceTransitionKind kind;
  final RoomSurfaceRef fromSurface;
  final SurfacePointMm fromPoint;
  final RoomSurfaceRef toSurface;
  final SurfacePointMm toPoint;

  /// Non-null means this transition crosses a physical construction and cannot
  /// be committed as a zero-length teleport between surfaces.
  final BoundaryPenetrationRequirement? penetrationRequirement;

  bool get requiresPenetration => penetrationRequirement != null;

  BoundaryPenetration createPenetration({
    required String penetrationId,
    required String routeId,
    int? thicknessMm,
  }) {
    final requirement = penetrationRequirement;
    if (requirement == null) {
      throw StateError('Transition $id does not require a penetration.');
    }
    return requirement.create(
      penetrationId: penetrationId,
      routeId: routeId,
      entrySurface: fromSurface,
      entryPoint: fromPoint,
      exitSurface: toSurface,
      exitPoint: toPoint,
      thicknessMm: thicknessMm,
    );
  }
}

/// Discovers physically valid continuation points for an in-progress route.
///
/// Same-room transitions reuse [SurfaceTransitionResolver]. Cross-room wall
/// transitions always require a physical penetration. Optional thickness and
/// material resolvers allow the graph to bind that requirement to the current
/// wall-construction registry without coupling routing to persistence.
abstract final class SurfaceTransitionGraph {
  static List<SurfaceTransitionCandidate> candidates({
    required BuildingLevel level,
    required EngineeringSpace fromSpace,
    required RoomSurfaceRef fromSurface,
    required SurfacePointMm point,
    int roomHeightMm = 3000,
    int toleranceMm = 2,
    BoundaryThicknessResolver? thicknessResolver,
    BoundaryMaterialResolver? materialResolver,
  }) {
    final result = <SurfaceTransitionCandidate>[];

    void addSameRoom(RoomSurfaceRef target, SurfaceTransitionKind kind) {
      final mapped = SurfaceTransitionResolver.mapPoint(
        space: fromSpace,
        from: fromSurface,
        point: point,
        to: target,
        roomHeightMm: roomHeightMm,
        toleranceMm: toleranceMm,
      );
      if (mapped == null) return;
      result.add(
        SurfaceTransitionCandidate(
          id: _id(fromSurface, point, target, mapped),
          kind: kind,
          fromSurface: fromSurface,
          fromPoint: point,
          toSurface: target,
          toPoint: mapped,
        ),
      );
    }

    if (fromSurface.type == SurfacePlaneType.wall) {
      addSameRoom(
        RoomSurfaceRef.floor(fromSpace.id),
        SurfaceTransitionKind.wallToFloor,
      );
      addSameRoom(
        RoomSurfaceRef.ceiling(fromSpace.id),
        SurfaceTransitionKind.wallToCeiling,
      );
      for (final wall in RoomSurfaceResolver.walls(fromSpace)) {
        if (wall.ref == fromSurface) continue;
        addSameRoom(wall.ref, SurfaceTransitionKind.wallToWall);
      }
      result.addAll(
        _crossRoomCandidates(
          level: level,
          fromSpace: fromSpace,
          fromSurface: fromSurface,
          point: point,
          toleranceMm: toleranceMm,
          thicknessResolver: thicknessResolver,
          materialResolver: materialResolver,
        ),
      );
    } else {
      for (final wall in RoomSurfaceResolver.walls(fromSpace)) {
        addSameRoom(
          wall.ref,
          fromSurface.type == SurfacePlaneType.floor
              ? SurfaceTransitionKind.wallToFloor
              : SurfaceTransitionKind.wallToCeiling,
        );
      }
    }

    final unique = <String, SurfaceTransitionCandidate>{};
    for (final candidate in result) {
      unique[candidate.id] = candidate;
    }
    return List.unmodifiable(unique.values);
  }

  /// Resolves a ceiling/floor penetration between two building levels at the
  /// same plan coordinate. This is intentionally explicit: floor and ceiling
  /// surfaces do not become adjacent merely because they belong to successive
  /// levels; the route must cross a physical slab.
  static SurfaceTransitionCandidate? levelPenetration({
    required BuildingLevel fromLevel,
    required EngineeringSpace fromSpace,
    required RoomSurfaceRef fromSurface,
    required SurfacePointMm point,
    required BuildingLevel toLevel,
    required EngineeringSpace toSpace,
    required int slabThicknessMm,
    String? materialId,
  }) {
    if (slabThicknessMm <= 0) {
      throw ArgumentError.value(
        slabThicknessMm,
        'slabThicknessMm',
        'Must be positive.',
      );
    }
    if (fromLevel.id == toLevel.id) return null;

    final isUp = toLevel.elevationMm > fromLevel.elevationMm;
    final expectedFrom = isUp ? SurfacePlaneType.ceiling : SurfacePlaneType.floor;
    final expectedTo = isUp ? SurfacePlaneType.floor : SurfacePlaneType.ceiling;
    if (fromSurface.type != expectedFrom || fromSurface.spaceId != fromSpace.id) {
      return null;
    }

    final planPoint = _horizontalToPlan(fromSpace, point);
    if (!toSpace.boundary.contains(planPoint) &&
        !_onBounds(toSpace.boundary.bounds, planPoint)) {
      return null;
    }

    final target = expectedTo == SurfacePlaneType.floor
        ? RoomSurfaceRef.floor(toSpace.id)
        : RoomSurfaceRef.ceiling(toSpace.id);
    final mapped = _planToHorizontal(toSpace, planPoint);
    return SurfaceTransitionCandidate(
      id: _id(fromSurface, point, target, mapped),
      kind: SurfaceTransitionKind.levelPenetration,
      fromSurface: fromSurface,
      fromPoint: point,
      toSurface: target,
      toPoint: mapped,
      penetrationRequirement: BoundaryPenetrationRequirement(
        hostKind: BoundaryPenetrationHostKind.slab,
        hostThicknessMm: slabThicknessMm,
        materialId: materialId,
      ),
    );
  }

  static List<SurfaceTransitionCandidate> _crossRoomCandidates({
    required BuildingLevel level,
    required EngineeringSpace fromSpace,
    required RoomSurfaceRef fromSurface,
    required SurfacePointMm point,
    required int toleranceMm,
    required BoundaryThicknessResolver? thicknessResolver,
    required BoundaryMaterialResolver? materialResolver,
  }) {
    final fromWall = RoomSurfaceResolver.wall(
      fromSpace,
      fromSurface.wallIndex!,
    );
    final worldPoint = RoomSurfaceResolver.wallLocalToPlan(fromWall, point.xMm);
    final result = <SurfaceTransitionCandidate>[];

    for (final space in level.spaces) {
      if (space.id == fromSpace.id) continue;
      for (final wall in RoomSurfaceResolver.walls(space)) {
        if (!_collinear(fromWall, wall, toleranceMm: toleranceMm)) continue;
        final x = _distanceAlongWallIfOnSegment(
          wall,
          worldPoint,
          toleranceMm: toleranceMm,
        );
        if (x == null) continue;
        final mapped = SurfacePointMm(x, point.yMm);
        result.add(
          SurfaceTransitionCandidate(
            id: _id(fromSurface, point, wall.ref, mapped),
            kind: SurfaceTransitionKind.roomPenetration,
            fromSurface: fromSurface,
            fromPoint: point,
            toSurface: wall.ref,
            toPoint: mapped,
            penetrationRequirement: BoundaryPenetrationRequirement(
              hostKind: BoundaryPenetrationHostKind.wall,
              hostThicknessMm: thicknessResolver?.call(fromSurface, wall.ref),
              materialId: materialResolver?.call(fromSurface, wall.ref),
            ),
          ),
        );
      }
    }
    return result;
  }

  static SurfacePointMm _planToHorizontal(
    EngineeringSpace space,
    MmPoint point,
  ) {
    final bounds = space.boundary.bounds;
    return SurfacePointMm(point.x - bounds.left, point.y - bounds.bottom);
  }

  static MmPoint _horizontalToPlan(
    EngineeringSpace space,
    SurfacePointMm point,
  ) {
    final bounds = space.boundary.bounds;
    return MmPoint(bounds.left + point.xMm, bounds.bottom + point.yMm);
  }

  static bool _onBounds(MmBounds bounds, MmPoint point) =>
      point.x >= bounds.left &&
      point.x <= bounds.right &&
      point.y >= bounds.bottom &&
      point.y <= bounds.top;

  static bool _collinear(
    RoomWallSurface a,
    RoomWallSurface b, {
    required int toleranceMm,
  }) {
    final adx = (a.end.x - a.start.x).toDouble();
    final ady = (a.end.y - a.start.y).toDouble();
    final bdx = (b.end.x - b.start.x).toDouble();
    final bdy = (b.end.y - b.start.y).toDouble();
    final crossDirection = (adx * bdy - ady * bdx).abs();
    final scale = math.max(1.0, math.sqrt(adx * adx + ady * ady));
    if (crossDirection / scale > toleranceMm) return false;
    final px = (b.start.x - a.start.x).toDouble();
    final py = (b.start.y - a.start.y).toDouble();
    final crossOffset = (adx * py - ady * px).abs();
    return crossOffset / scale <= toleranceMm;
  }

  static int? _distanceAlongWallIfOnSegment(
    RoomWallSurface wall,
    MmPoint point, {
    required int toleranceMm,
  }) {
    final ax = wall.start.x.toDouble();
    final ay = wall.start.y.toDouble();
    final dx = (wall.end.x - wall.start.x).toDouble();
    final dy = (wall.end.y - wall.start.y).toDouble();
    final lengthSquared = dx * dx + dy * dy;
    if (lengthSquared == 0) return null;
    final t = ((point.x - ax) * dx + (point.y - ay) * dy) / lengthSquared;
    if (t < 0 || t > 1) return null;
    final px = ax + t * dx;
    final py = ay + t * dy;
    final distance = math.sqrt(
      (point.x - px) * (point.x - px) + (point.y - py) * (point.y - py),
    );
    if (distance > toleranceMm) return null;
    return (math.sqrt(lengthSquared) * t).round();
  }

  static String _id(
    RoomSurfaceRef from,
    SurfacePointMm fromPoint,
    RoomSurfaceRef to,
    SurfacePointMm toPoint,
  ) =>
      '${from.id}@${fromPoint.xMm},${fromPoint.yMm}->'
      '${to.id}@${toPoint.xMm},${toPoint.yMm}';
}
