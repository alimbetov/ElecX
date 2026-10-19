import '../domain/geometry.dart';
import '../domain/surfaces.dart';
import 'route_engine.dart';

/// A rectangular keep-out envelope expressed in surface-local millimetres.
///
/// Typical sources: architectural openings, structural zones, equipment
/// service clearances, wet zones, shafts and manually reserved corridors.
final class SurfaceKeepOutZone {
  const SurfaceKeepOutZone({
    required this.id,
    required this.surface,
    required this.bounds,
    this.reason,
  });

  final String id;
  final RoomSurfaceRef surface;
  final MmBounds bounds;
  final String? reason;

  bool contains(SurfacePointMm point) =>
      point.xMm >= bounds.left &&
      point.xMm <= bounds.right &&
      point.yMm >= bounds.bottom &&
      point.yMm <= bounds.top;
}

abstract final class RoutingConstraintEngine {
  /// Returns a routing graph with edges crossing keep-out zones removed.
  /// Nodes are retained so diagnostics can still explain unreachable targets.
  static RoutingGraph constrain({
    required RoutingGraph graph,
    required Iterable<SurfaceKeepOutZone> zones,
  }) {
    final bySurface = <RoomSurfaceRef, List<SurfaceKeepOutZone>>{};
    for (final zone in zones) {
      bySurface.putIfAbsent(zone.surface, () => []).add(zone);
    }
    if (bySurface.isEmpty) return graph;

    final edges = <RouteEdge>[];
    for (final edge in graph.edges) {
      final from = graph.nodes[edge.from];
      final to = graph.nodes[edge.to];
      if (from == null || to == null) continue;
      if (from.surface != to.surface) {
        edges.add(edge);
        continue;
      }
      final surfaceZones = bySurface[from.surface];
      if (surfaceZones == null || surfaceZones.isEmpty) {
        edges.add(edge);
        continue;
      }
      final blocked = surfaceZones.any(
        (zone) => _segmentIntersectsBounds(from.point, to.point, zone.bounds),
      );
      if (!blocked) edges.add(edge);
    }
    return RoutingGraph(nodes: graph.nodes, edges: List.unmodifiable(edges));
  }

  static List<SurfaceKeepOutZone> routeViolations({
    required RoomSurfaceRef surface,
    required List<SurfacePointMm> points,
    required Iterable<SurfaceKeepOutZone> zones,
  }) {
    final relevant = zones.where((zone) => zone.surface == surface).toList();
    if (relevant.isEmpty || points.length < 2) return const [];
    final result = <SurfaceKeepOutZone>[];
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1];
      final b = points[i];
      for (final zone in relevant) {
        if (_segmentIntersectsBounds(a, b, zone.bounds) &&
            !result.any((item) => item.id == zone.id)) {
          result.add(zone);
        }
      }
    }
    return List.unmodifiable(result);
  }

  static bool _segmentIntersectsBounds(
    SurfacePointMm a,
    SurfacePointMm b,
    MmBounds bounds,
  ) {
    if (_pointInBounds(a, bounds) || _pointInBounds(b, bounds)) return true;

    final p1 = MmPoint(a.xMm, a.yMm);
    final p2 = MmPoint(b.xMm, b.yMm);
    final corners = <MmPoint>[
      MmPoint(bounds.left, bounds.bottom),
      MmPoint(bounds.right, bounds.bottom),
      MmPoint(bounds.right, bounds.top),
      MmPoint(bounds.left, bounds.top),
    ];
    for (var i = 0; i < corners.length; i++) {
      if (_segmentsIntersect(
        p1,
        p2,
        corners[i],
        corners[(i + 1) % corners.length],
      )) {
        return true;
      }
    }
    return false;
  }

  static bool _pointInBounds(SurfacePointMm point, MmBounds bounds) =>
      point.xMm >= bounds.left &&
      point.xMm <= bounds.right &&
      point.yMm >= bounds.bottom &&
      point.yMm <= bounds.top;

  static bool _segmentsIntersect(MmPoint a, MmPoint b, MmPoint c, MmPoint d) {
    final o1 = _orientation(a, b, c);
    final o2 = _orientation(a, b, d);
    final o3 = _orientation(c, d, a);
    final o4 = _orientation(c, d, b);
    if (o1 == 0 && _onSegment(a, c, b)) return true;
    if (o2 == 0 && _onSegment(a, d, b)) return true;
    if (o3 == 0 && _onSegment(c, a, d)) return true;
    if (o4 == 0 && _onSegment(c, b, d)) return true;
    return o1 != o2 && o3 != o4;
  }

  static int _orientation(MmPoint a, MmPoint b, MmPoint c) {
    final value = (b.y - a.y) * (c.x - b.x) -
        (b.x - a.x) * (c.y - b.y);
    if (value == 0) return 0;
    return value > 0 ? 1 : 2;
  }

  static bool _onSegment(MmPoint a, MmPoint b, MmPoint c) =>
      b.x >= (a.x < c.x ? a.x : c.x) &&
      b.x <= (a.x > c.x ? a.x : c.x) &&
      b.y >= (a.y < c.y ? a.y : c.y) &&
      b.y <= (a.y > c.y ? a.y : c.y);
}
