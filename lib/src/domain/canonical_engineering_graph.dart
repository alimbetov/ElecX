import 'engineering_graph.dart';
import 'project_identity.dart';

/// Logical engineering component identity and capabilities.
///
/// This contract intentionally contains no geometry or placement data. Physical
/// location belongs to the component-placement model, while route geometry
/// belongs to routing. Keeping the graph logical prevents editor coordinates
/// from becoming engineering identity.
final class EngineeringGraphComponent {
  EngineeringGraphComponent({
    required this.id,
    required this.componentTypeId,
    required this.discipline,
    required this.systemClass,
    required Iterable<EngineeringPortSpec> ports,
    this.ratedPowerW,
    this.voltageV,
    this.quantity = 1,
  }) : ports = List.unmodifiable(ports) {
    if (componentTypeId.trim().isEmpty) {
      throw ArgumentError.value(
        componentTypeId,
        'componentTypeId',
        'Must be non-empty.',
      );
    }
    if (quantity <= 0) throw ArgumentError.value(quantity, 'quantity');
    if (ratedPowerW != null && ratedPowerW! < 0) {
      throw ArgumentError.value(ratedPowerW, 'ratedPowerW');
    }
    if (voltageV != null && voltageV! <= 0) {
      throw ArgumentError.value(voltageV, 'voltageV');
    }
    final portIds = <String>{};
    for (final port in this.ports) {
      if (!portIds.add(port.id)) {
        throw ArgumentError('Duplicate port id ${port.id} on $id.');
      }
    }
  }

  final ComponentId id;
  final String componentTypeId;
  final EngineeringDiscipline discipline;
  final EngineeringSystemClass systemClass;
  final List<EngineeringPortSpec> ports;
  final int? ratedPowerW;
  final int? voltageV;
  final int quantity;

  int get connectedLoadW => (ratedPowerW ?? 0) * quantity;

  EngineeringPortSpec? port(PortId portId) {
    for (final port in ports) {
      if (port.id == portId.value) return port;
    }
    return null;
  }
}

/// Typed logical connection between two engineering component ports.
final class EngineeringGraphConnection {
  const EngineeringGraphConnection({
    required this.id,
    required this.fromComponentId,
    required this.fromPortId,
    required this.toComponentId,
    required this.toPortId,
    required this.connectionType,
    required this.systemClass,
    this.routeId,
    this.circuitId,
  });

  final EngineeringConnectionId id;
  final ComponentId fromComponentId;
  final PortId fromPortId;
  final ComponentId toComponentId;
  final PortId toPortId;
  final EngineeringConnectionType connectionType;
  final EngineeringSystemClass systemClass;
  final RouteId? routeId;
  final CircuitId? circuitId;
}

/// Canonical WHAT + CONNECTIVITY graph.
///
/// Construction fails closed for duplicate ids, dangling endpoints, unknown
/// ports, self-port loops and incompatible port directions/media.
final class CanonicalEngineeringGraph {
  CanonicalEngineeringGraph({
    required Iterable<EngineeringGraphComponent> components,
    Iterable<EngineeringGraphConnection> connections = const [],
  }) {
    final componentList = List<EngineeringGraphComponent>.of(components);
    final connectionList = List<EngineeringGraphConnection>.of(connections);
    final componentMap = <ComponentId, EngineeringGraphComponent>{};
    for (final component in componentList) {
      if (componentMap.containsKey(component.id)) {
        throw ArgumentError('Duplicate component id ${component.id}.');
      }
      componentMap[component.id] = component;
    }

    final connectionIds = <EngineeringConnectionId>{};
    for (final connection in connectionList) {
      if (!connectionIds.add(connection.id)) {
        throw ArgumentError('Duplicate connection id ${connection.id}.');
      }
      final from = componentMap[connection.fromComponentId];
      final to = componentMap[connection.toComponentId];
      if (from == null || to == null) {
        throw ArgumentError(
          'Connection ${connection.id} references an unknown component.',
        );
      }
      if (connection.fromComponentId == connection.toComponentId &&
          connection.fromPortId == connection.toPortId) {
        throw ArgumentError(
          'Connection ${connection.id} cannot loop a port to itself.',
        );
      }
      if (!CanonicalEngineeringGraphValidator.canConnect(
        from: from,
        fromPortId: connection.fromPortId,
        to: to,
        toPortId: connection.toPortId,
        type: connection.connectionType,
      )) {
        throw ArgumentError(
          'Connection ${connection.id} is incompatible with its endpoint ports.',
        );
      }
    }

    _components = Map.unmodifiable(componentMap);
    _connections = List.unmodifiable(connectionList);
  }

  late final Map<ComponentId, EngineeringGraphComponent> _components;
  late final List<EngineeringGraphConnection> _connections;

  List<EngineeringGraphComponent> get components =>
      List.unmodifiable(_components.values);
  List<EngineeringGraphConnection> get connections => _connections;

  EngineeringGraphComponent? component(ComponentId id) => _components[id];

  EngineeringGraphComponent requireComponent(ComponentId id) {
    final value = _components[id];
    if (value == null) {
      throw ArgumentError.value(id, 'id', 'Unknown engineering component.');
    }
    return value;
  }

  bool hasDirectedPath(ComponentId start, ComponentId target) {
    requireComponent(start);
    requireComponent(target);
    if (start == target) return true;

    final visited = <ComponentId>{start};
    final queue = <ComponentId>[start];
    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      for (final edge in _connections) {
        if (edge.fromComponentId != current) continue;
        final next = edge.toComponentId;
        if (!visited.add(next)) continue;
        if (next == target) return true;
        queue.add(next);
      }
    }
    return false;
  }

  Set<ComponentId> downstreamComponentIds(ComponentId start) {
    requireComponent(start);
    final visited = <ComponentId>{start};
    final queue = <ComponentId>[start];
    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      for (final edge in _connections) {
        if (edge.fromComponentId != current) continue;
        final next = edge.toComponentId;
        if (!visited.add(next)) continue;
        queue.add(next);
      }
    }
    visited.remove(start);
    return Set.unmodifiable(visited);
  }
}

abstract final class CanonicalEngineeringGraphValidator {
  static bool canConnect({
    required EngineeringGraphComponent from,
    required PortId fromPortId,
    required EngineeringGraphComponent to,
    required PortId toPortId,
    required EngineeringConnectionType type,
  }) {
    final fromPort = from.port(fromPortId);
    final toPort = to.port(toPortId);
    if (fromPort == null || toPort == null) return false;
    if (!fromPort.accepts(type) || !toPort.accepts(type)) return false;
    if (fromPort.direction == EngineeringPortDirection.input) return false;
    if (toPort.direction == EngineeringPortDirection.output) return false;
    return true;
  }
}

/// Transitional adapters let existing persisted/editor models move to the
/// canonical graph without changing durable identity.
extension LegacyEngineeringNodeCanonicalAdapter on EngineeringNode {
  EngineeringGraphComponent toCanonicalEngineeringComponent() =>
      EngineeringGraphComponent(
        id: ComponentId(id),
        componentTypeId: componentTypeId,
        discipline: discipline,
        systemClass: systemClass,
        ports: ports,
        ratedPowerW: ratedPowerW,
        voltageV: voltageV,
        quantity: quantity,
      );
}

extension LegacyEngineeringEdgeCanonicalAdapter on EngineeringEdge {
  EngineeringGraphConnection toCanonicalEngineeringConnection() =>
      EngineeringGraphConnection(
        id: EngineeringConnectionId(id),
        fromComponentId: ComponentId(fromNodeId),
        fromPortId: PortId(fromPortId),
        toComponentId: ComponentId(toNodeId),
        toPortId: PortId(toPortId),
        connectionType: connectionType,
        systemClass: systemClass,
        routeId: routeId == null ? null : RouteId(routeId!),
        circuitId: circuitId == null ? null : CircuitId(circuitId!),
      );
}
