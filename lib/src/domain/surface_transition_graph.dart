import 'dart:math' as math;

import 'boundary_penetration.dart';
import 'geometry.dart';
import 'project_identity.dart';
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

typedef BoundaryEdgeOrderResolver = List<BoundaryEdgeId>? Function(
  String spaceId,
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
    BoundaryEdgeOrderResolver? boundaryEdgeOrderResolver,
  }) {
    if (fromSurface.spaceId != fromSpace.id) return const [];
    final sourceEdgeIds = boundaryEdgeOrderResolver?.call(fromSpace.id);
    final result = <SurfaceTransitionCandidate>[];

    void addSameRoom(RoomSurfaceRef target, SurfaceTransitionKind kind) {
      final mapped = SurfaceTransitionResolver.mapPoint(
        space: fromSpace,
        from: fromSurface,
        point: point,
        to: target,
        roomHeightMm: roomHeightMm,
        toleranceMm: toleranceMm,
        orderedBoundaryEdgeIds: sourceEdgeIds,
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
      for (final wall in _wallsForSpace(fromSpace, sourceEdgeIds)) {
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
          roomHeightMm: roomHeightMm,
          thicknessResolver: thicknessResolver,
          materialResolver: materialResolver,
          boundaryEdgeOrderResolver: boundaryEdgeOrderResolver,
        ),
      );
    } else {
      if (!_horizontalPointIsValid(fromSpace, point)) return const [];
      for (final wall in _wallsForSpace(fromSpace, sourceEdgeIds)) {
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

  /// Resolves a slab penetration only between physically adjacent levels and
  /// where source and target room polygons overlap at the same plan point.
  static SurfaceTransitionCandidate? levelPenetration({
    required Iterable<BuildingLevel> buildingLevels,
    required BuildingLevel fromLevel,
    required EngineeringSpace fromSpace,
    required RoomSurfaceRef fromSurface,
    required SurfacePointMm point,
    required int fromRoomHeightMm,
    required BuildingLevel toLevel,
    required EngineeringSpace toSpace,
    required int toRoomHeightMm,
    required int slabThicknessMm,
    int verticalToleranceMm = 2,
    String? materialId,
  }) {
    if (fromRoomHeightMm <= 0 || toRoomHeightMm <= 0) {
      throw ArgumentError('Room heights must be positive.');
    }
    if (slabThicknessMm <= 0) {
      throw ArgumentError.value(
        slabThicknessMm,
        'slabThicknessMm',
        'Must be positive.',
      );
    }
    if (verticalToleranceMm < 0) {
      throw ArgumentError.value(
        verticalToleranceMm,
        'verticalToleranceMm',
        'Must be non-negative.',
      );
    }
    if (fromLevel.id == toLevel.id) return null;
    if (!_levelContainsSpace(fromLevel, fromSpace) ||
        !_levelContainsSpace(toLevel, toSpace)) {
      return null;
    }
    if (!_areAdjacentLevels(buildingLevels, fromLevel, toLevel)) return null;

    final isUp = toLevel.elevationMm > fromLevel.elevationMm;
    final expectedFrom =
        isUp ? SurfacePlaneType.ceiling : SurfacePlaneType.floor;
    final expectedTo = isUp ? SurfacePlaneType.floor : SurfacePlaneType.ceiling;
    if (fromSurface.type != expectedFrom ||
        fromSurface.spaceId != fromSpace.id) {
      return null;
    }
    if (!_horizontalPointIsValid(fromSpace, point)) return null;

    final physicalGapMm = isUp
        ? toLevel.elevationMm - (fromLevel.elevationMm + fromRoomHeightMm)
        : fromLevel.elevationMm - (toLevel.elevationMm + toRoomHeightMm);
    if (physicalGapMm <= 0 ||
        (physicalGapMm - slabThicknessMm).abs() > verticalToleranceMm) {
      return null;
    }

    final planPoint = _horizontalToPlan(fromSpace, point);
    if (!_containsOrTouches(toSpace.boundary, planPoint)) return null;

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
    required int roomHeightMm,
    required BoundaryThicknessResolver? thicknessResolver,
    required BoundaryMaterialResolver? materialResolver,
    required BoundaryEdgeOrderResolver? boundaryEdgeOrderResolver,
  }) {
    final sourceEdgeIds = boundaryEdgeOrderResolver?.call(fromSpace.id);
    final fromWall = _wallForRef(
      fromSpace,
      fromSurface,
      sourceEdgeIds,
      roomHeightMm,
    );
    if (fromWall == null ||
        !fromWall.profile.containsPoint(point.xMm, point.yMm)) {
      return const [];
    }
    final worldPoint = RoomSurfaceResolver.wallLocalToPlan(fromWall, point.xMm);
    final result = <SurfaceTransitionCandidate>[];

    for (final space in level.spaces) {
      if (space.id == fromSpace.id) continue;
      final targetEdgeIds = boundaryEdgeOrderResolver?.call(space.id);
      for (final wall in _wallsForSpace(space, targetEdgeIds)) {
        if (!_collinear(fromWall, wall, toleranceMm: toleranceMm)) continue;
        final x = _distanceAlongWallIfOnSegment(
          wall,
          worldPoint,
          toleranceMm: toleranceMm,
        );
        if (x == null || !wall.profile.containsPoint(x, point.yMm)) continue;
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

  static List<RoomWallSurface> _wallsForSpace(
    EngineeringSpace space,
    List<BoundaryEdgeId>? edgeIds,
  ) {
    if (edgeIds == null) return RoomSurfaceResolver.walls(space);
    try {
      return RoomSurfaceResolver.wallsByBoundaryEdges(space, edgeIds);
    } on ArgumentError {
      return const [];
    }
  }

  static RoomWallSurface? _wallForRef(
    EngineeringSpace space,
    RoomSurfaceRef ref,
    List<BoundaryEdgeId>? edgeIds,
    int roomHeightMm,
  ) {
    if (ref.type != SurfacePlaneType.wall || ref.spaceId != space.id) {
      return null;
    }
    final edgeId = ref.boundaryEdgeId;
    if (edgeId != null) {
      if (edgeIds == null) {
        return null;
      }
      try {
        return RoomSurfaceResolver.wallByBoundaryEdge(
          space,
          edgeIds,
          edgeId,
          defaultHeightMm: roomHeightMm,
        );
      } on StateError {
        return null;
      } on ArgumentError {
        return null;
      }
    }
    final wallIndex = ref.wallIndex;
    if (wallIndex == null) return null;
    try {
      return RoomSurfaceResolver.wall(
        space,
        wallIndex,
        defaultHeightMm: roomHeightMm,
      );
    } on RangeError {
      return null;
    }
  }

  static bool _levelContainsSpace(
    BuildingLevel level,
    EngineeringSpace space,
  ) =>
      level.spaces.any((candidate) => candidate.id == space.id);

  static bool _areAdjacentLevels(
    Iterable<BuildingLevel> buildingLevels,
    BuildingLevel a,
    BuildingLevel b,
  ) {
    final levels = buildingLevels.toList()
      ..sort((left, right) => left.elevationMm.compareTo(right.elevationMm));
    final aIndex = levels.indexWhere((level) => level.id == a.id);
    final bIndex = levels.indexWhere((level) => level.id == b.id);
    if (aIndex < 0 || bIndex < 0) return false;
    return (aIndex - bIndex).abs() == 1;
  }

  static bool _horizontalPointIsValid(
    EngineeringSpace space,
    SurfacePointMm point,
  ) {
    if (point.xMm < 0 || point.yMm < 0) return false;
    return _containsOrTouches(space.boundary, _horizontalToPlan(space, point));
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

  static bool _containsOrTouches(MmPolygon polygon, MmPoint point) {
    if (polygon.contains(point)) return true;
    final vertices = polygon.vertices;
    for (var i = 0; i < vertices.length; i++) {
      final a = vertices[i];
      final b = vertices[(i + 1) % vertices.length];
      final cross =
          (point.x - a.x) * (b.y - a.y) - (point.y - a.y) * (b.x - a.x);
      if (cross != 0) continue;
      final minX = math.min(a.x, b.x);
      final maxX = math.max(a.x, b.x);
      final minY = math.min(a.y, b.y);
      final maxY = math.max(a.y, b.y);
      if (point.x >= minX &&
          point.x <= maxX &&
          point.y >= minY &&
          point.y <= maxY) {
        return true;
      }
    }
    return false;
  }

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
