import 'dart:collection';

import 'engineering_graph.dart';
import 'engineering_port_ref.dart';
import 'project_identity.dart';

export 'engineering_port_ref.dart';

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
    final portIds = <PortId>{};
    for (final port in this.ports) {
      if (!portIds.add(port.portId)) {
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
      if (port.portId == portId) return port;
    }
    return null;
  }
}

/// Typed logical connection between two engineering component ports.
final class EngineeringGraphConnection {
  EngineeringGraphConnection({
    required this.id,
    required this.fromComponentId,
    required this.fromPortId,
    required this.toComponentId,
    required this.toPortId,
    required this.connectionType,
    required this.systemClass,
    this.semanticTypeId,
    this.routeId,
    this.circuitId,
  }) {
    if (semanticTypeId != null && semanticTypeId!.trim().isEmpty) {
      throw ArgumentError.value(
        semanticTypeId,
        'semanticTypeId',
        'Must be null or non-empty.',
      );
    }
  }

  final EngineeringConnectionId id;
  final ComponentId fromComponentId;
  final PortId fromPortId;
  final ComponentId toComponentId;
  final PortId toPortId;
  final EngineeringConnectionType connectionType;
  final EngineeringSystemClass systemClass;

  /// Optional domain-semantic subtype when the generic engineering transport
  /// enum is intentionally broader than the canonical relationship semantics.
  final String? semanticTypeId;
  final RouteId? routeId;
  final CircuitId? circuitId;

  EngineeringPortRef get fromEndpoint =>
      EngineeringPortRef(componentId: fromComponentId, portId: fromPortId);
  EngineeringPortRef get toEndpoint =>
      EngineeringPortRef(componentId: toComponentId, portId: toPortId);
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
    final portMap = <EngineeringPortRef, EngineeringPortSpec>{};
    for (final component in componentList) {
      if (componentMap.containsKey(component.id)) {
        throw ArgumentError('Duplicate component id ${component.id}.');
      }
      componentMap[component.id] = component;
      for (final port in component.ports) {
        portMap[EngineeringPortRef(
            componentId: component.id, portId: port.portId)] = port;
      }
    }

    final connectionIds = <EngineeringConnectionId>{};
    final connectionMap =
        <EngineeringConnectionId, EngineeringGraphConnection>{};
    final outgoing = <ComponentId, List<EngineeringGraphConnection>>{};
    final incoming = <ComponentId, List<EngineeringGraphConnection>>{};
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
      connectionMap[connection.id] = connection;
      (outgoing[connection.fromComponentId] ??= []).add(connection);
      (incoming[connection.toComponentId] ??= []).add(connection);
    }

    _components = Map.unmodifiable(componentMap);
    _connections = List.unmodifiable(connectionList);
    _ports = Map.unmodifiable(portMap);
    _connectionsById = Map.unmodifiable(connectionMap);
    _outgoing = Map.unmodifiable({
      for (final e in outgoing.entries)
        e.key: List<EngineeringGraphConnection>.unmodifiable(e.value)
    });
    _incoming = Map.unmodifiable({
      for (final e in incoming.entries)
        e.key: List<EngineeringGraphConnection>.unmodifiable(e.value)
    });
  }

  late final Map<ComponentId, EngineeringGraphComponent> _components;
  late final List<EngineeringGraphConnection> _connections;
  late final Map<EngineeringPortRef, EngineeringPortSpec> _ports;
  late final Map<EngineeringConnectionId, EngineeringGraphConnection>
      _connectionsById;
  late final Map<ComponentId, List<EngineeringGraphConnection>> _outgoing;
  late final Map<ComponentId, List<EngineeringGraphConnection>> _incoming;

  List<EngineeringGraphComponent> get components =>
      List.unmodifiable(_components.values);
  List<EngineeringGraphConnection> get connections => _connections;

  EngineeringGraphComponent? component(ComponentId id) => _components[id];

  EngineeringPortSpec? port(EngineeringPortRef ref) => _ports[ref];
  EngineeringGraphConnection? connection(EngineeringConnectionId id) =>
      _connectionsById[id];

  EngineeringPortSpec requirePort(EngineeringPortRef ref) {
    final value = port(ref);
    if (value == null) {
      throw ArgumentError.value(ref, 'ref', 'Unknown engineering endpoint.');
    }
    return value;
  }

  List<EngineeringGraphConnection> outgoingConnections(ComponentId id) {
    requireComponent(id);
    return _outgoing[id] ?? const [];
  }

  List<EngineeringGraphConnection> incomingConnections(ComponentId id) {
    requireComponent(id);
    return _incoming[id] ?? const [];
  }

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
    final queue = ListQueue<ComponentId>()..add(start);
    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      for (final edge
          in _outgoing[current] ?? const <EngineeringGraphConnection>[]) {
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
    final queue = ListQueue<ComponentId>()..add(start);
    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      for (final edge
          in _outgoing[current] ?? const <EngineeringGraphConnection>[]) {
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
