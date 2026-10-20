import 'dart:math' as math;

import 'geometry.dart';
import 'project_model.dart';
import 'surfaces.dart';

/// Builds a rectangular room that shares a segment of an existing room wall.
///
/// The host room boundary is expected to be ordered consistently. The builder
/// determines the outward normal by checking which side of the host wall does
/// not contain the host room centre. This keeps the new room outside the host
/// room without requiring callers to know polygon winding.
abstract final class AdjacentRoomBuilder {
  static EngineeringSpace build({
    required EngineeringSpace hostRoom,
    required RoomWallSurface hostWall,
    required String id,
    required String name,
    required int depthMm,
    int offsetFromWallStartMm = 0,
    int? sharedLengthMm,
    SpaceType type = SpaceType.room,
  }) {
    if (depthMm < 300) {
      throw ArgumentError.value(depthMm, 'depthMm', 'Must be at least 300 mm.');
    }

    final wallLength = hostWall.lengthMm;
    final length =
        sharedLengthMm ?? (wallLength - offsetFromWallStartMm).round();
    if (offsetFromWallStartMm < 0 || length < 300) {
      throw ArgumentError('Shared wall offset/length is invalid.');
    }
    if (offsetFromWallStartMm + length > wallLength + 0.5) {
      throw ArgumentError('Shared wall segment exceeds host wall.');
    }

    MmPoint pointAt(double distanceMm) {
      final t = wallLength == 0 ? 0.0 : distanceMm / wallLength;
      return MmPoint(
        (hostWall.start.x + (hostWall.end.x - hostWall.start.x) * t).round(),
        (hostWall.start.y + (hostWall.end.y - hostWall.start.y) * t).round(),
      );
    }

    final a = pointAt(offsetFromWallStartMm.toDouble());
    final b = pointAt((offsetFromWallStartMm + length).toDouble());
    final dx = b.x - a.x;
    final dy = b.y - a.y;
    final segmentLength = math.sqrt((dx * dx + dy * dy).toDouble());
    if (segmentLength == 0) {
      throw ArgumentError('Host wall segment must have non-zero length.');
    }

    final normalA = _normalPoint(
      a,
      dx,
      dy,
      depthMm,
      clockwise: false,
      length: segmentLength,
    );
    final normalB = _normalPoint(
      b,
      dx,
      dy,
      depthMm,
      clockwise: false,
      length: segmentLength,
    );
    final candidateCenter = MmPoint(
      (normalA.x + normalB.x + a.x + b.x) ~/ 4,
      (normalA.y + normalB.y + a.y + b.y) ~/ 4,
    );

    final useOtherSide = hostRoom.boundary.contains(candidateCenter);
    final c = _normalPoint(
      b,
      dx,
      dy,
      depthMm,
      clockwise: useOtherSide,
      length: segmentLength,
    );
    final d = _normalPoint(
      a,
      dx,
      dy,
      depthMm,
      clockwise: useOtherSide,
      length: segmentLength,
    );

    final boundary = MmPolygon([a, b, c, d]);
    return EngineeringSpace(
      id: id,
      name: name,
      type: type,
      boundary: boundary,
      referenceFrame: RoomReferenceFrame(origin: boundary.bounds.center),
      grid: hostRoom.grid,
    );
  }

  static MmPoint _normalPoint(
    MmPoint base,
    int dx,
    int dy,
    int depthMm, {
    required bool clockwise,
    required double length,
  }) {
    final nx = clockwise ? dy / length : -dy / length;
    final ny = clockwise ? -dx / length : dx / length;
    return MmPoint(
      (base.x + nx * depthMm).round(),
      (base.y + ny * depthMm).round(),
    );
  }
}
