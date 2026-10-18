import 'dart:math' as math;

import '../domain/geometry.dart';
import '../domain/project_model.dart';

final class PlanPullMeasure {
  const PlanPullMeasure({
    required this.sourceMidpoint,
    required this.targetPoint,
    required this.distanceMm,
  });

  final MmPoint sourceMidpoint;
  final MmPoint targetPoint;
  final int distanceMm;
}

abstract final class PlanPullMeasureResolver {
  static PlanPullMeasure? nearestParallelBoundary({
    required EngineeringSpace space,
    required int edgeIndex,
  }) {
    final vertices = space.boundary.vertices;
    if (edgeIndex < 0 || edgeIndex >= vertices.length) return null;

    final a = vertices[edgeIndex];
    final b = vertices[(edgeIndex + 1) % vertices.length];
    final dx = (b.x - a.x).toDouble();
    final dy = (b.y - a.y).toDouble();
    final length = math.sqrt(dx * dx + dy * dy);
    if (length <= 0) return null;

    final tx = dx / length;
    final ty = dy / length;
    final nx = -ty;
    final ny = tx;
    final midpoint = MmPoint((a.x + b.x) ~/ 2, (a.y + b.y) ~/ 2);

    PlanPullMeasure? best;
    for (var i = 0; i < vertices.length; i++) {
      if (i == edgeIndex) continue;
      final c = vertices[i];
      final d = vertices[(i + 1) % vertices.length];
      final odx = (d.x - c.x).toDouble();
      final ody = (d.y - c.y).toDouble();
      final otherLength = math.sqrt(odx * odx + ody * ody);
      if (otherLength <= 0) continue;

      final cross = (tx * (ody / otherLength) - ty * (odx / otherLength)).abs();
      if (cross > 0.015) continue;

      final signedDistance =
          (c.x - midpoint.x) * nx + (c.y - midpoint.y) * ny;
      final distance = signedDistance.abs();
      if (distance < 1) continue;

      final along =
          (midpoint.x - c.x) * (odx / otherLength) +
          (midpoint.y - c.y) * (ody / otherLength);
      final projected = MmPoint(
        (c.x + odx / otherLength * along).round(),
        (c.y + ody / otherLength * along).round(),
      );
      final candidate = PlanPullMeasure(
        sourceMidpoint: midpoint,
        targetPoint: projected,
        distanceMm: distance.round(),
      );
      if (best == null || candidate.distanceMm < best.distanceMm) {
        best = candidate;
      }
    }
    return best;
  }
}
