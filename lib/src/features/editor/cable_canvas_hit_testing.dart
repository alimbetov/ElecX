import 'dart:math' as math;

import '../../domain/electrical_routing.dart';
import '../../domain/surfaces.dart';
import '../../engine/port_snap_resolver.dart';

sealed class CableCanvasHit {
  const CableCanvasHit({required this.route, required this.segmentIndex});

  final ElectricalCableRoute route;
  final int segmentIndex;
}

final class CableEndpointHit extends CableCanvasHit {
  const CableEndpointHit({
    required super.route,
    required super.segmentIndex,
    required this.role,
    required this.point,
  });

  final CableEndpointRole role;
  final SurfacePointMm point;
}

final class CableVertexHit extends CableCanvasHit {
  const CableVertexHit({
    required super.route,
    required super.segmentIndex,
    required this.pointIndex,
    required this.point,
  });

  final int pointIndex;
  final SurfacePointMm point;
}

final class CableSegmentHit extends CableCanvasHit {
  const CableSegmentHit({
    required super.route,
    required super.segmentIndex,
    required this.edgeIndex,
    required this.point,
  });

  final int edgeIndex;
  final SurfacePointMm point;
}

abstract final class CableCanvasHitTesting {
  static CableCanvasHit? hitTest({
    required ElectricalCableRoute route,
    required RoomSurfaceRef surface,
    required SurfacePointMm point,
    required double radiusMm,
  }) {
    final endpoint = _endpointHit(
      route: route,
      surface: surface,
      point: point,
      radiusMm: radiusMm,
    );
    if (endpoint != null) return endpoint;

    final vertex = _vertexHit(
      route: route,
      surface: surface,
      point: point,
      radiusMm: radiusMm,
    );
    if (vertex != null) return vertex;

    return _segmentHit(
      route: route,
      surface: surface,
      point: point,
      radiusMm: radiusMm,
    );
  }

  static CableEndpointHit? _endpointHit({
    required ElectricalCableRoute route,
    required RoomSurfaceRef surface,
    required SurfacePointMm point,
    required double radiusMm,
  }) {
    if (route.segments.isEmpty) return null;
    final first = route.segments.first;
    if (first.surface == surface && first.points.length >= 2) {
      final source = first.points.first;
      if (_distance(point, source) <= radiusMm) {
        return CableEndpointHit(
          route: route,
          segmentIndex: 0,
          role: CableEndpointRole.source,
          point: source,
        );
      }
    }
    final lastIndex = route.segments.length - 1;
    final last = route.segments[lastIndex];
    if (last.surface == surface && last.points.length >= 2) {
      final target = last.points.last;
      if (_distance(point, target) <= radiusMm) {
        return CableEndpointHit(
          route: route,
          segmentIndex: lastIndex,
          role: CableEndpointRole.target,
          point: target,
        );
      }
    }
    return null;
  }

  static CableVertexHit? _vertexHit({
    required ElectricalCableRoute route,
    required RoomSurfaceRef surface,
    required SurfacePointMm point,
    required double radiusMm,
  }) {
    CableVertexHit? best;
    var bestDistance = double.infinity;
    for (var s = 0; s < route.segments.length; s++) {
      final segment = route.segments[s];
      if (segment.surface != surface || segment.points.length < 3) continue;
      for (var p = 1; p < segment.points.length - 1; p++) {
        final distance = _distance(point, segment.points[p]);
        if (distance <= radiusMm && distance < bestDistance) {
          bestDistance = distance;
          best = CableVertexHit(
            route: route,
            segmentIndex: s,
            pointIndex: p,
            point: segment.points[p],
          );
        }
      }
    }
    return best;
  }

  static CableSegmentHit? _segmentHit({
    required ElectricalCableRoute route,
    required RoomSurfaceRef surface,
    required SurfacePointMm point,
    required double radiusMm,
  }) {
    CableSegmentHit? best;
    var bestDistance = double.infinity;
    for (var s = 0; s < route.segments.length; s++) {
      final segment = route.segments[s];
      if (segment.surface != surface || segment.points.length < 2) continue;
      for (var e = 0; e < segment.points.length - 1; e++) {
        final a = segment.points[e];
        final b = segment.points[e + 1];
        final nearest = _nearestPoint(point, a, b);
        final distance = _distance(point, nearest);
        if (distance <= radiusMm && distance < bestDistance) {
          bestDistance = distance;
          best = CableSegmentHit(
            route: route,
            segmentIndex: s,
            edgeIndex: e,
            point: nearest,
          );
        }
      }
    }
    return best;
  }

  static List<SurfacePointMm> moveVertex({
    required List<SurfacePointMm> points,
    required int pointIndex,
    required SurfacePointMm target,
  }) {
    if (pointIndex <= 0 || pointIndex >= points.length - 1) return points;

    final before = points[pointIndex - 1];
    final after = points[pointIndex + 1];
    final replacement = <SurfacePointMm>[
      SurfacePointMm(target.xMm, before.yMm),
      target,
      SurfacePointMm(after.xMm, target.yMm),
    ];

    final result = <SurfacePointMm>[
      ...points.take(pointIndex),
      ...replacement,
      ...points.skip(pointIndex + 1),
    ];
    return _compactOrthogonal(result);
  }

  static List<SurfacePointMm> moveSegment({
    required List<SurfacePointMm> points,
    required int edgeIndex,
    required SurfacePointMm target,
  }) {
    if (edgeIndex < 0 || edgeIndex >= points.length - 1) return points;
    final a = points[edgeIndex];
    final b = points[edgeIndex + 1];
    final horizontal = a.yMm == b.yMm;
    final vertical = a.xMm == b.xMm;
    if (!horizontal && !vertical) return points;

    final movedA = horizontal
        ? SurfacePointMm(a.xMm, target.yMm)
        : SurfacePointMm(target.xMm, a.yMm);
    final movedB = horizontal
        ? SurfacePointMm(b.xMm, target.yMm)
        : SurfacePointMm(target.xMm, b.yMm);
    final firstEdge = edgeIndex == 0;
    final lastEdge = edgeIndex == points.length - 2;

    final result = <SurfacePointMm>[
      ...points.take(edgeIndex),
      if (firstEdge) a,
      movedA,
      movedB,
      if (lastEdge) b,
      ...points.skip(edgeIndex + 2),
    ];
    return _compactOrthogonal(result);
  }

  static List<SurfacePointMm> _compactOrthogonal(
    List<SurfacePointMm> points,
  ) {
    final result = <SurfacePointMm>[];
    for (final point in points) {
      if (result.isNotEmpty &&
          result.last.xMm == point.xMm &&
          result.last.yMm == point.yMm) {
        continue;
      }
      while (result.length >= 2) {
        final a = result[result.length - 2];
        final b = result.last;
        final collinearX = a.xMm == b.xMm && b.xMm == point.xMm;
        final collinearY = a.yMm == b.yMm && b.yMm == point.yMm;
        if (!collinearX && !collinearY) break;
        result.removeLast();
      }
      result.add(point);
    }
    return List.unmodifiable(result);
  }

  static SurfacePointMm _nearestPoint(
    SurfacePointMm point,
    SurfacePointMm a,
    SurfacePointMm b,
  ) {
    final dx = (b.xMm - a.xMm).toDouble();
    final dy = (b.yMm - a.yMm).toDouble();
    final lengthSquared = dx * dx + dy * dy;
    if (lengthSquared == 0) return a;
    final px = (point.xMm - a.xMm).toDouble();
    final py = (point.yMm - a.yMm).toDouble();
    final t = ((px * dx + py * dy) / lengthSquared).clamp(0.0, 1.0);
    return SurfacePointMm(
      (a.xMm + dx * t).round(),
      (a.yMm + dy * t).round(),
    );
  }

  static double _distance(SurfacePointMm a, SurfacePointMm b) {
    final dx = a.xMm - b.xMm;
    final dy = a.yMm - b.yMm;
    return math.sqrt((dx * dx + dy * dy).toDouble());
  }
}
