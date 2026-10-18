import '../domain/electrical_routing.dart';
import '../domain/surfaces.dart';

enum RoutePreference { shortest, orthogonal, preferWall, preferCeiling, preferFloor }

final class RouteNode {
  const RouteNode({required this.id, required this.surface, required this.point});

  final String id;
  final RoomSurfaceRef surface;
  final SurfacePointMm point;
}

final class RouteEdge {
  const RouteEdge({
    required this.from,
    required this.to,
    required this.cost,
    this.transition = false,
  });

  final String from;
  final String to;
  final double cost;
  final bool transition;
}

final class RoutingGraph {
  const RoutingGraph({required this.nodes, required this.edges});

  final Map<String, RouteNode> nodes;
  final List<RouteEdge> edges;
}

final class RouteSolution {
  const RouteSolution({required this.nodeIds, required this.cost});

  final List<String> nodeIds;
  final double cost;
}

abstract final class RouteEngine {
  static RouteSolution? solve({
    required RoutingGraph graph,
    required String startNodeId,
    required String endNodeId,
    RoutePreference preference = RoutePreference.shortest,
  }) {
    if (!graph.nodes.containsKey(startNodeId) ||
        !graph.nodes.containsKey(endNodeId)) {
      return null;
    }

    final adjacency = <String, List<RouteEdge>>{};
    for (final edge in graph.edges) {
      adjacency.putIfAbsent(edge.from, () => []).add(edge);
    }

    final distances = <String, double>{startNodeId: 0};
    final previous = <String, String>{};
    final queue = <_QueueEntry>[_QueueEntry(startNodeId, 0)];

    while (queue.isNotEmpty) {
      queue.sort((a, b) => a.cost.compareTo(b.cost));
      final current = queue.removeAt(0);
      if (current.cost != distances[current.id]) continue;
      if (current.id == endNodeId) break;

      for (final edge in adjacency[current.id] ?? const <RouteEdge>[]) {
        final weighted = _weightedCost(edge, graph, preference);
        final nextCost = current.cost + weighted;
        if (nextCost < (distances[edge.to] ?? double.infinity)) {
          distances[edge.to] = nextCost;
          previous[edge.to] = current.id;
          queue.add(_QueueEntry(edge.to, nextCost));
        }
      }
    }

    final total = distances[endNodeId];
    if (total == null) return null;
    final path = <String>[endNodeId];
    var cursor = endNodeId;
    while (cursor != startNodeId) {
      final parent = previous[cursor];
      if (parent == null) return null;
      path.add(parent);
      cursor = parent;
    }
    return RouteSolution(nodeIds: path.reversed.toList(), cost: total);
  }

  static List<ElectricalRouteSegment> toSegments(
    RoutingGraph graph,
    RouteSolution solution,
  ) {
    if (solution.nodeIds.isEmpty) return const [];
    final result = <ElectricalRouteSegment>[];
    RoomSurfaceRef? activeSurface;
    var points = <SurfacePointMm>[];

    for (final id in solution.nodeIds) {
      final node = graph.nodes[id]!;
      if (activeSurface == null || activeSurface == node.surface) {
        activeSurface ??= node.surface;
        points.add(node.point);
        continue;
      }
      if (points.isNotEmpty) {
        result.add(ElectricalRouteSegment(surface: activeSurface, points: points));
      }
      activeSurface = node.surface;
      points = [node.point];
    }
    if (activeSurface != null && points.isNotEmpty) {
      result.add(ElectricalRouteSegment(surface: activeSurface, points: points));
    }
    return result;
  }

  static double _weightedCost(
    RouteEdge edge,
    RoutingGraph graph,
    RoutePreference preference,
  ) {
    final target = graph.nodes[edge.to]!;
    var multiplier = 1.0;
    if (edge.transition) multiplier += 0.08;
    switch (preference) {
      case RoutePreference.shortest:
        break;
      case RoutePreference.orthogonal:
        multiplier += 0.02;
      case RoutePreference.preferWall:
        if (target.surface.type != SurfacePlaneType.wall) multiplier += 0.25;
      case RoutePreference.preferCeiling:
        if (target.surface.type != SurfacePlaneType.ceiling) multiplier += 0.25;
      case RoutePreference.preferFloor:
        if (target.surface.type != SurfacePlaneType.floor) multiplier += 0.25;
    }
    return edge.cost * multiplier;
  }
}

final class _QueueEntry {
  const _QueueEntry(this.id, this.cost);

  final String id;
  final double cost;
}
