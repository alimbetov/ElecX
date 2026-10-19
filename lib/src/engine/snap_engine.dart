import 'dart:math' as math;

import '../domain/geometry.dart';

enum SnapKind {
  port,
  componentAnchor,
  endpoint,
  intersection,
  midpoint,
  center,
  perpendicular,
  wall,
  guide,
  nearest,
  grid,
}

final class SnapCandidate {
  const SnapCandidate({
    required this.kind,
    required this.point,
    required this.distanceMm,
    this.sourceId,
  });

  final SnapKind kind;
  final MmPoint point;
  final double distanceMm;
  final String? sourceId;
}

final class SemanticSnapAnchor {
  const SemanticSnapAnchor({
    required this.kind,
    required this.point,
    required this.sourceId,
  }) : assert(
         kind == SnapKind.port || kind == SnapKind.componentAnchor,
         'Semantic anchors are restricted to port/component anchors.',
       );

  final SnapKind kind;
  final MmPoint point;
  final String sourceId;
}

final class SnapSegment {
  const SnapSegment({required this.id, required this.a, required this.b});

  final String id;
  final MmPoint a;
  final MmPoint b;

  MmPoint get midpoint => MmPoint((a.x + b.x) ~/ 2, (a.y + b.y) ~/ 2);
}

final class SnapRequest {
  const SnapRequest({
    required this.rawPoint,
    required this.acquisitionRadiusMm,
    required this.gridStepMm,
    this.segments = const [],
    this.guides = const [],
    this.semanticAnchors = const [],
  });

  final MmPoint rawPoint;
  final double acquisitionRadiusMm;
  final int gridStepMm;
  final List<SnapSegment> segments;
  final List<MmPoint> guides;
  final List<SemanticSnapAnchor> semanticAnchors;
}

/// Holds a captured semantic target until the pointer leaves a larger release
/// radius. This prevents attach/detach flicker around a port boundary.
final class SnapHysteresis {
  SnapCandidate? _captured;

  SnapCandidate? get captured => _captured;

  SnapCandidate? resolve({
    required MmPoint rawPoint,
    required SnapCandidate? candidate,
    required double releaseRadiusMm,
  }) {
    if (releaseRadiusMm <= 0) {
      throw ArgumentError.value(releaseRadiusMm, 'releaseRadiusMm');
    }
    final current = _captured;
    if (current != null) {
      final distance = rawPoint.distanceTo(current.point);
      if (distance <= releaseRadiusMm) return current;
      _captured = null;
    }
    if (candidate != null) _captured = candidate;
    return _captured;
  }

  void clear() => _captured = null;
}

abstract final class SnapEngine {
  static const Map<SnapKind, int> _priority = {
    SnapKind.port: 0,
    SnapKind.componentAnchor: 1,
    SnapKind.endpoint: 2,
    SnapKind.intersection: 3,
    SnapKind.midpoint: 4,
    SnapKind.center: 5,
    SnapKind.perpendicular: 6,
    SnapKind.wall: 7,
    SnapKind.guide: 8,
    SnapKind.nearest: 9,
    SnapKind.grid: 10,
  };

  static SnapCandidate? resolve(SnapRequest request) {
    if (request.acquisitionRadiusMm <= 0 || request.gridStepMm <= 0) {
      throw ArgumentError('Snap radius and grid step must be positive.');
    }

    final candidates = <SnapCandidate>[];

    for (final anchor in request.semanticAnchors) {
      _addPoint(
        candidates,
        request,
        anchor.kind,
        anchor.point,
        anchor.sourceId,
      );
    }

    for (final segment in request.segments) {
      _addPoint(candidates, request, SnapKind.endpoint, segment.a, segment.id);
      _addPoint(candidates, request, SnapKind.endpoint, segment.b, segment.id);
      _addPoint(
        candidates,
        request,
        SnapKind.midpoint,
        segment.midpoint,
        segment.id,
      );
      final nearest =
          _nearestPointOnSegment(request.rawPoint, segment.a, segment.b);
      _addPoint(candidates, request, SnapKind.nearest, nearest, segment.id);
    }

    for (var i = 0; i < request.segments.length; i++) {
      for (var j = i + 1; j < request.segments.length; j++) {
        final intersection = _segmentIntersection(
          request.segments[i],
          request.segments[j],
        );
        if (intersection != null) {
          _addPoint(
            candidates,
            request,
            SnapKind.intersection,
            intersection,
            '${request.segments[i].id}|${request.segments[j].id}',
          );
        }
      }
    }

    for (var i = 0; i < request.guides.length; i++) {
      _addPoint(
        candidates,
        request,
        SnapKind.guide,
        request.guides[i],
        'guide-$i',
      );
    }

    final grid = MmPoint(
      (request.rawPoint.x / request.gridStepMm).round() * request.gridStepMm,
      (request.rawPoint.y / request.gridStepMm).round() * request.gridStepMm,
    );
    _addPoint(candidates, request, SnapKind.grid, grid, 'grid');

    if (candidates.isEmpty) return null;
    candidates.sort((a, b) {
      final priority = _priority[a.kind]!.compareTo(_priority[b.kind]!);
      if (priority != 0) return priority;
      return a.distanceMm.compareTo(b.distanceMm);
    });
    return candidates.first;
  }

  static void _addPoint(
    List<SnapCandidate> candidates,
    SnapRequest request,
    SnapKind kind,
    MmPoint point,
    String sourceId,
  ) {
    final distance = request.rawPoint.distanceTo(point);
    if (distance <= request.acquisitionRadiusMm) {
      candidates.add(
        SnapCandidate(
          kind: kind,
          point: point,
          distanceMm: distance,
          sourceId: sourceId,
        ),
      );
    }
  }

  static MmPoint _nearestPointOnSegment(MmPoint p, MmPoint a, MmPoint b) {
    final dx = (b.x - a.x).toDouble();
    final dy = (b.y - a.y).toDouble();
    final lengthSquared = dx * dx + dy * dy;
    if (lengthSquared == 0) return a;
    final t =
        (((p.x - a.x) * dx + (p.y - a.y) * dy) / lengthSquared).clamp(0.0, 1.0);
    return MmPoint((a.x + dx * t).round(), (a.y + dy * t).round());
  }

  static MmPoint? _segmentIntersection(SnapSegment first, SnapSegment second) {
    final x1 = first.a.x.toDouble();
    final y1 = first.a.y.toDouble();
    final x2 = first.b.x.toDouble();
    final y2 = first.b.y.toDouble();
    final x3 = second.a.x.toDouble();
    final y3 = second.a.y.toDouble();
    final x4 = second.b.x.toDouble();
    final y4 = second.b.y.toDouble();
    final denominator = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4);
    if (denominator.abs() < 0.000001) return null;

    final px =
        ((x1 * y2 - y1 * x2) * (x3 - x4) - (x1 - x2) * (x3 * y4 - y3 * x4)) /
            denominator;
    final py =
        ((x1 * y2 - y1 * x2) * (y3 - y4) - (y1 - y2) * (x3 * y4 - y3 * x4)) /
            denominator;

    bool inside(double value, double a, double b) =>
        value >= math.min(a, b) - 0.001 && value <= math.max(a, b) + 0.001;
    if (!inside(px, x1, x2) ||
        !inside(py, y1, y2) ||
        !inside(px, x3, x4) ||
        !inside(py, y3, y4)) {
      return null;
    }
    return MmPoint(px.round(), py.round());
  }
}
