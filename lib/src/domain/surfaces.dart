import 'dart:math' as math;

import 'geometry.dart';
import 'project_model.dart';
import 'wall_profile.dart';

enum SurfacePlaneType { floor, ceiling, wall }

enum ArchitecturalOpeningType { door, window, passage, technicalOpening }

/// Stable reference to an editable plane of a room.
///
/// Wall surfaces are addressed by the boundary edge index so the same physical
/// wall can be resolved from plan and elevation views without duplicating
/// geometry.
final class RoomSurfaceRef {
  const RoomSurfaceRef._({
    required this.spaceId,
    required this.type,
    this.wallIndex,
  });

  factory RoomSurfaceRef.floor(String spaceId) => RoomSurfaceRef._(
        spaceId: spaceId,
        type: SurfacePlaneType.floor,
      );

  factory RoomSurfaceRef.ceiling(String spaceId) => RoomSurfaceRef._(
        spaceId: spaceId,
        type: SurfacePlaneType.ceiling,
      );

  factory RoomSurfaceRef.wall(String spaceId, int wallIndex) {
    if (wallIndex < 0) {
      throw ArgumentError.value(wallIndex, 'wallIndex', 'Must be non-negative.');
    }
    return RoomSurfaceRef._(
      spaceId: spaceId,
      type: SurfacePlaneType.wall,
      wallIndex: wallIndex,
    );
  }

  final String spaceId;
  final SurfacePlaneType type;
  final int? wallIndex;

  String get id => switch (type) {
        SurfacePlaneType.floor => '$spaceId:floor',
        SurfacePlaneType.ceiling => '$spaceId:ceiling',
        SurfacePlaneType.wall => '$spaceId:wall:$wallIndex',
      };

  @override
  bool operator ==(Object other) =>
      other is RoomSurfaceRef &&
      other.spaceId == spaceId &&
      other.type == type &&
      other.wallIndex == wallIndex;

  @override
  int get hashCode => Object.hash(spaceId, type, wallIndex);
}

final class RoomWallSurface {
  const RoomWallSurface({
    required this.ref,
    required this.start,
    required this.end,
    required this.heightMm,
    required this.profile,
  });

  final RoomSurfaceRef ref;
  final MmPoint start;
  final MmPoint end;
  final int heightMm;
  final WallProfile profile;

  double get lengthMm => start.distanceTo(end);
}

/// Door/window/opening hosted by one room wall.
///
/// [offsetFromStartMm] is measured along the wall from its start vertex.
/// [sillHeightMm] is measured from the finished floor level.
final class ArchitecturalOpening {
  ArchitecturalOpening({
    required this.id,
    required this.hostWall,
    required this.type,
    required this.offsetFromStartMm,
    required this.widthMm,
    required this.heightMm,
    required this.sillHeightMm,
  }) {
    if (id.isEmpty) throw ArgumentError('Opening id must be non-empty.');
    if (hostWall.type != SurfacePlaneType.wall) {
      throw ArgumentError('Architectural openings must be hosted by a wall.');
    }
    if (offsetFromStartMm < 0 ||
        widthMm <= 0 ||
        heightMm <= 0 ||
        sillHeightMm < 0) {
      throw ArgumentError('Opening dimensions and offsets are invalid.');
    }
  }

  final String id;
  final RoomSurfaceRef hostWall;
  final ArchitecturalOpeningType type;
  final int offsetFromStartMm;
  final int widthMm;
  final int heightMm;
  final int sillHeightMm;

  int get topMm => sillHeightMm + heightMm;
  int get endOffsetMm => offsetFromStartMm + widthMm;

  ArchitecturalOpening copyWith({
    RoomSurfaceRef? hostWall,
    ArchitecturalOpeningType? type,
    int? offsetFromStartMm,
    int? widthMm,
    int? heightMm,
    int? sillHeightMm,
  }) =>
      ArchitecturalOpening(
        id: id,
        hostWall: hostWall ?? this.hostWall,
        type: type ?? this.type,
        offsetFromStartMm: offsetFromStartMm ?? this.offsetFromStartMm,
        widthMm: widthMm ?? this.widthMm,
        heightMm: heightMm ?? this.heightMm,
        sillHeightMm: sillHeightMm ?? this.sillHeightMm,
      );
}

/// A point in coordinates local to a physical surface.
///
/// For walls x runs from the wall start vertex toward the end vertex and y is
/// height above floor. For floor/ceiling both axes use the room-local plane.
final class SurfacePointMm {
  const SurfacePointMm(this.xMm, this.yMm);

  final int xMm;
  final int yMm;
}

final class SurfaceRouteDraft {
  const SurfaceRouteDraft({
    required this.id,
    required this.surface,
    required this.points,
  });

  final String id;
  final RoomSurfaceRef surface;
  final List<SurfacePointMm> points;
}

abstract final class RoomSurfaceResolver {
  static List<RoomWallSurface> walls(
    EngineeringSpace space, {
    int defaultHeightMm = 3000,
  }) {
    if (defaultHeightMm <= 0) {
      throw ArgumentError.value(defaultHeightMm, 'defaultHeightMm');
    }
    final vertices = space.boundary.vertices;
    return List.unmodifiable([
      for (var i = 0; i < vertices.length; i++)
        _wallForIndex(space, i, defaultHeightMm),
    ]);
  }

  static RoomWallSurface _wallForIndex(
    EngineeringSpace space,
    int wallIndex,
    int defaultHeightMm,
  ) {
    final vertices = space.boundary.vertices;
    final start = vertices[wallIndex];
    final end = vertices[(wallIndex + 1) % vertices.length];
    final length = start.distanceTo(end).round();
    final profile = space.wallProfiles[wallIndex] ??
        WallProfile.rectangle(widthMm: length, heightMm: defaultHeightMm);
    return RoomWallSurface(
      ref: RoomSurfaceRef.wall(space.id, wallIndex),
      start: start,
      end: end,
      heightMm: profile.maxY,
      profile: profile,
    );
  }

  static RoomWallSurface wall(
    EngineeringSpace space,
    int wallIndex, {
    int defaultHeightMm = 3000,
  }) {
    final allWalls = walls(space, defaultHeightMm: defaultHeightMm);
    if (wallIndex < 0 || wallIndex >= allWalls.length) {
      throw RangeError.index(wallIndex, allWalls, 'wallIndex');
    }
    return allWalls[wallIndex];
  }

  static bool openingFitsWall({
    required ArchitecturalOpening opening,
    required RoomWallSurface wall,
  }) {
    if (opening.hostWall != wall.ref) return false;
    return wall.profile.containsRect(
      leftMm: opening.offsetFromStartMm,
      bottomMm: opening.sillHeightMm,
      widthMm: opening.widthMm,
      heightMm: opening.heightMm,
    );
  }

  /// Converts a wall-local x coordinate back to a point on the floor plan.
  static MmPoint wallLocalToPlan(RoomWallSurface wall, int xMm) {
    final length = wall.lengthMm;
    if (length == 0) return wall.start;
    final t = (xMm / length).clamp(0.0, 1.0);
    return MmPoint(
      (wall.start.x + (wall.end.x - wall.start.x) * t).round(),
      (wall.start.y + (wall.end.y - wall.start.y) * t).round(),
    );
  }

  static double wallAngleRadians(RoomWallSurface wall) => math.atan2(
        wall.end.y - wall.start.y,
        wall.end.x - wall.start.x,
      );
}
