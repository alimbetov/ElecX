import 'dart:math' as math;

import 'geometry.dart';
import 'surfaces.dart';

final class WallConstruction {
  const WallConstruction({
    required this.id,
    required this.thicknessMm,
    this.materialId,
  }) : assert(thicknessMm > 0);

  final String id;
  final int thicknessMm;
  final String? materialId;
}

/// Plan projection of a wall with a physical interior and exterior face.
///
/// The current room boundary is treated as the finished interior face. For an
/// external wall, thickness is projected outward from the room polygon. Shared
/// walls require a future canonical wall entity so two rooms do not create two
/// competing wall bodies.
final class WallPlanBody {
  const WallPlanBody({
    required this.surface,
    required this.interiorStart,
    required this.interiorEnd,
    required this.exteriorStart,
    required this.exteriorEnd,
    required this.thicknessMm,
  });

  final RoomSurfaceRef surface;
  final MmPoint interiorStart;
  final MmPoint interiorEnd;
  final MmPoint exteriorStart;
  final MmPoint exteriorEnd;
  final int thicknessMm;

  List<MmPoint> get polygon => [
        interiorStart,
        interiorEnd,
        exteriorEnd,
        exteriorStart,
      ];
}

abstract final class WallPlanGeometry {
  static bool isCounterClockwise(MmPolygon polygon) {
    var twiceArea = 0.0;
    final vertices = polygon.vertices;
    for (var i = 0; i < vertices.length; i++) {
      final a = vertices[i];
      final b = vertices[(i + 1) % vertices.length];
      twiceArea += a.x * b.y - b.x * a.y;
    }
    return twiceArea > 0;
  }

  static WallPlanBody externalWallBody({
    required String spaceId,
    required MmPolygon roomBoundary,
    required int wallIndex,
    required int thicknessMm,
  }) {
    if (thicknessMm <= 0) {
      throw ArgumentError.value(thicknessMm, 'thicknessMm', 'Must be positive.');
    }
    final vertices = roomBoundary.vertices;
    if (wallIndex < 0 || wallIndex >= vertices.length) {
      throw RangeError.index(wallIndex, vertices, 'wallIndex');
    }
    final a = vertices[wallIndex];
    final b = vertices[(wallIndex + 1) % vertices.length];
    final dx = (b.x - a.x).toDouble();
    final dy = (b.y - a.y).toDouble();
    final length = math.sqrt(dx * dx + dy * dy);
    if (length <= 0) {
      throw ArgumentError('Wall edge must have non-zero length.');
    }

    final ccw = isCounterClockwise(roomBoundary);
    // For a CCW room polygon the interior lies to the left of each edge, so
    // the exterior lies to the right. Reverse for clockwise polygons.
    final outwardX = ccw ? dy / length : -dy / length;
    final outwardY = ccw ? -dx / length : dx / length;
    final ox = outwardX * thicknessMm;
    final oy = outwardY * thicknessMm;

    MmPoint offset(MmPoint point) => MmPoint(
          (point.x + ox).round(),
          (point.y + oy).round(),
        );

    return WallPlanBody(
      surface: RoomSurfaceRef.wall(spaceId, wallIndex),
      interiorStart: a,
      interiorEnd: b,
      exteriorStart: offset(a),
      exteriorEnd: offset(b),
      thicknessMm: thicknessMm,
    );
  }
}
