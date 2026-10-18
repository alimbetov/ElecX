import 'dart:math' as math;

import '../domain/geometry.dart';

enum ConstraintKind {
  horizontal,
  vertical,
  distance,
  coincident,
  perpendicular,
}

final class ConstraintResult {
  const ConstraintResult({required this.a, required this.b});

  final MmPoint a;
  final MmPoint b;
}

abstract final class ConstraintEngine {
  static ConstraintResult horizontal(MmPoint fixed, MmPoint moving) =>
      ConstraintResult(a: fixed, b: MmPoint(moving.x, fixed.y));

  static ConstraintResult vertical(MmPoint fixed, MmPoint moving) =>
      ConstraintResult(a: fixed, b: MmPoint(fixed.x, moving.y));

  static ConstraintResult distance(
    MmPoint fixed,
    MmPoint moving,
    int distanceMm,
  ) {
    if (distanceMm <= 0) {
      throw ArgumentError.value(distanceMm, 'distanceMm');
    }
    final dx = moving.x - fixed.x;
    final dy = moving.y - fixed.y;
    final length = math.sqrt(dx * dx + dy * dy);
    if (length == 0) {
      return ConstraintResult(
        a: fixed,
        b: MmPoint(fixed.x + distanceMm, fixed.y),
      );
    }
    final scale = distanceMm / length;
    return ConstraintResult(
      a: fixed,
      b: MmPoint(
        (fixed.x + dx * scale).round(),
        (fixed.y + dy * scale).round(),
      ),
    );
  }

  static MmPoint coincident(MmPoint anchor) => anchor;

  static MmPoint perpendicularPoint({
    required MmPoint lineA,
    required MmPoint lineB,
    required MmPoint rawPoint,
  }) {
    final dx = (lineB.x - lineA.x).toDouble();
    final dy = (lineB.y - lineA.y).toDouble();
    final lengthSquared = dx * dx + dy * dy;
    if (lengthSquared == 0) return lineA;
    final t = (((rawPoint.x - lineA.x) * dx +
                (rawPoint.y - lineA.y) * dy) /
            lengthSquared)
        .clamp(0.0, 1.0);
    return MmPoint(
      (lineA.x + dx * t).round(),
      (lineA.y + dy * t).round(),
    );
  }
}
