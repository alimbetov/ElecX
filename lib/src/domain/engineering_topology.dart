import 'component_catalog_v2.dart';
import 'electrical_placement.dart';
import 'engineering_graph.dart';

final class EngineeringTopology {
  EngineeringTopology({
    required Iterable<EngineeringNode> nodes,
    Iterable<EngineeringEdge> edges = const [],
  })  : _nodes = {for (final node in nodes) node.id: node},
        _edges = List<EngineeringEdge>.of(edges) {
    if (_nodes.length != nodes.length) {
      throw ArgumentError('Engineering node ids must be unique.');
    }
  }

  final Map<String, EngineeringNode> _nodes;
  final List<EngineeringEdge> _edges;

  List<EngineeringNode> get nodes => List.unmodifiable(_nodes.values);
  List<EngineeringEdge> get edges => List.unmodifiable(_edges);

  EngineeringNode requireNode(String id) {
    final node = _nodes[id];
    if (node == null) throw ArgumentError.value(id, 'id', 'Unknown node.');
    return node;
  }

  void addNode(EngineeringNode node) {
    if (_nodes.containsKey(node.id)) {
      throw ArgumentError.value(node.id, 'node.id', 'Duplicate node id.');
    }
    _nodes[node.id] = node;
  }

  EngineeringEdge connect({
    required String id,
    required String fromNodeId,
    required String fromPortId,
    required String toNodeId,
    required String toPortId,
    required EngineeringConnectionType connectionType,
    required EngineeringSystemClass systemClass,
    String? routeId,
    String? circuitId,
  }) {
    final from = requireNode(fromNodeId);
    final to = requireNode(toNodeId);
    if (!EngineeringGraphValidator.canConnect(
      from: from,
      fromPortId: fromPortId,
      to: to,
      toPortId: toPortId,
      type: connectionType,
    )) {
      throw StateError(
        'Invalid engineering connection: '
        '$fromNodeId.$fromPortId -> $toNodeId.$toPortId '
        '(${connectionType.name}).',
      );
    }
    if (_edges.any((edge) => edge.id == id)) {
      throw ArgumentError.value(id, 'id', 'Duplicate edge id.');
    }
    final edge = EngineeringEdge(
      id: id,
      fromNodeId: fromNodeId,
      fromPortId: fromPortId,
      toNodeId: toNodeId,
      toPortId: toPortId,
      connectionType: connectionType,
      systemClass: systemClass,
      routeId: routeId,
      circuitId: circuitId,
    );
    _edges.add(edge);
    return edge;
  }

  /// Physical-connectivity query. Direction is intentionally ignored.
  bool hasPath(String startNodeId, String targetNodeId) {
    requireNode(startNodeId);
    requireNode(targetNodeId);
    if (startNodeId == targetNodeId) return true;

    final visited = <String>{startNodeId};
    final queue = <String>[startNodeId];
    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      for (final edge in _edges) {
        String? next;
        if (edge.fromNodeId == current) {
          next = edge.toNodeId;
        } else if (edge.toNodeId == current) {
          next = edge.fromNodeId;
        }
        if (next == null || !visited.add(next)) continue;
        if (next == targetNodeId) return true;
        queue.add(next);
      }
    }
    return false;
  }

  /// Semantic flow query. Only follows fromNode -> toNode edges.
  ///
  /// For an electrical supply topology this lets validation prove that power
  /// can flow from a distribution board to a load rather than merely proving
  /// that the two nodes are present in the same undirected component.
  bool hasDirectedPath(String startNodeId, String targetNodeId) {
    requireNode(startNodeId);
    requireNode(targetNodeId);
    if (startNodeId == targetNodeId) return true;

    final visited = <String>{startNodeId};
    final queue = <String>[startNodeId];
    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      for (final edge in _edges) {
        if (edge.fromNodeId != current) continue;
        final next = edge.toNodeId;
        if (!visited.add(next)) continue;
        if (next == targetNodeId) return true;
        queue.add(next);
      }
    }
    return false;
  }

  List<String> downstreamNodeIds(String startNodeId) {
    requireNode(startNodeId);
    final visited = <String>{startNodeId};
    final queue = <String>[startNodeId];
    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      for (final edge in _edges) {
        if (edge.fromNodeId != current || !visited.add(edge.toNodeId)) continue;
        queue.add(edge.toNodeId);
      }
    }
    visited.remove(startNodeId);
    return List.unmodifiable(visited);
  }
}

abstract final class EngineeringNodeFactory {
  static EngineeringNode fromPlacement({
    required ElectricalComponentPlacement placement,
    required ComponentCatalogEntryV2 entry,
  }) {
    if (placement.componentTypeId != entry.id) {
      throw ArgumentError(
        'Placement componentTypeId ${placement.componentTypeId} '
        'does not match catalog entry ${entry.id}.',
      );
    }
    return EngineeringNode(
      id: placement.id,
      componentTypeId: entry.id,
      discipline: entry.discipline,
      systemClass: entry.systemClass,
      surface: placement.surface,
      position: placement.position,
      ports: entry.ports,
      ratedPowerW: entry.loadDefaults.ratedPowerW,
      voltageV: entry.loadDefaults.nominalVoltageV,
    );
  }
}
