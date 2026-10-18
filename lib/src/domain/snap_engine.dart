import 'dart:math' as math;

import 'geometry.dart';

enum SnapKind {
  grid,
  endpoint,
  midpoint,
  center,
  intersection,
  perpendicular,
  nearest,
  wall,
  guide,
}

final class SnapCandidate {
  const SnapCandidate({
    required this.point,
    required this.kind,
    required this.distanceMm,
    this.sourceId,
  });

  final MmPoint point;
  final SnapKind kind;
  final double distanceMm;
  final String? sourceId;
}

final class SnapResult {
  const SnapResult({required this.point, this.candidate});

  final MmPoint point;
  final SnapCandidate? candidate;

  bool get snapped => candidate != null;
}

final class SnapContext {
  const SnapContext({
    required this.gridStepMm,
    this.endpoints = const [],
    this.midpoints = const [],
    this.centers = const [],
    this.intersections = const [],
    this.maxAcquireDistanceMm = 180,
  });

  final int gridStepMm;
  final List<MmPoint> endpoints;
  final List<MmPoint> midpoints;
  final List<MmPoint> centers;
  final List<MmPoint> intersections;
  final double maxAcquireDistanceMm;
}

final class SnapEngine {
  const SnapEngine();

  SnapResult resolve(MmPoint raw, SnapContext context) {
    final candidates = <SnapCandidate>[
      _gridCandidate(raw, context.gridStepMm),
      ..._pointCandidates(raw, context.endpoints, SnapKind.endpoint),
      ..._pointCandidates(raw, context.midpoints, SnapKind.midpoint),
      ..._pointCandidates(raw, context.centers, SnapKind.center),
      ..._pointCandidates(raw, context.intersections, SnapKind.intersection),
    ];

    candidates.removeWhere(
      (candidate) => candidate.distanceMm > context.maxAcquireDistanceMm,
    );
    if (candidates.isEmpty) return SnapResult(point: raw);

    candidates.sort((a, b) {
      final priority = _priority(a.kind).compareTo(_priority(b.kind));
      if (priority != 0 &&
          (a.distanceMm - b.distanceMm).abs() < context.maxAcquireDistanceMm * 0.25) {
        return priority;
      }
      return a.distanceMm.compareTo(b.distanceMm);
    });
    final best = candidates.first;
    return SnapResult(point: best.point, candidate: best);
  }

  SnapCandidate _gridCandidate(MmPoint raw, int stepMm) {
    final step = math.max(stepMm, 1);
    final snapped = MmPoint(
      (raw.x / step).round() * step,
      (raw.y / step).round() * step,
    );
    return SnapCandidate(
      point: snapped,
      kind: SnapKind.grid,
      distanceMm: raw.distanceTo(snapped),
    );
  }

  Iterable<SnapCandidate> _pointCandidates(
    MmPoint raw,
    List<MmPoint> points,
    SnapKind kind,
  ) sync* {
    for (final point in points) {
      yield SnapCandidate(
        point: point,
        kind: kind,
        distanceMm: raw.distanceTo(point),
      );
    }
  }

  int _priority(SnapKind kind) => switch (kind) {
        SnapKind.endpoint => 0,
        SnapKind.intersection => 1,
        SnapKind.midpoint => 2,
        SnapKind.center => 3,
        SnapKind.perpendicular => 4,
        SnapKind.wall => 5,
        SnapKind.guide => 6,
        SnapKind.nearest => 7,
        SnapKind.grid => 8,
      };
}
