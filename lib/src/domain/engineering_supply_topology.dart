import 'dart:collection';

import 'canonical_engineering_graph.dart';
import 'engineering_circuit_topology.dart';
import 'engineering_classification.dart';
import 'engineering_graph.dart';
import 'project_identity.dart';

/// Stable identity for one logical engineering supply source.
///
/// Allocation/persistence integration remains owned by P11.8. The identity is
/// intentionally opaque and must never be derived from display order or graph
/// coordinates.
final class EngineeringSupplySourceId extends EntityId {
  EngineeringSupplySourceId(super.value);
}

/// Extensible semantic role of a supply source.
///
/// Roles describe topology only. They do not implement automatic transfer,
/// dispatch, load-flow or protection policy.
final class EngineeringSupplyRoleKey {
  EngineeringSupplyRoleKey(String id) : id = _nonEmpty(id, 'id');

  final String id;

  static final primary = EngineeringSupplyRoleKey('core.primary');
  static final alternate = EngineeringSupplyRoleKey('core.alternate');
  static final emergency = EngineeringSupplyRoleKey('core.emergency');
  static final storage = EngineeringSupplyRoleKey('core.storage');

  @override
  bool operator ==(Object other) =>
      other is EngineeringSupplyRoleKey && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => id;
}

/// One logical source endpoint already owned by the canonical graph.
///
/// [serviceEntryId] is a non-owning provenance link to the architectural P10
/// service-anchor model. The supply topology never owns or rewrites that anchor.
final class EngineeringSupplySource {
  EngineeringSupplySource({
    required this.id,
    required this.endpoint,
    required this.systemClass,
    EngineeringSystemKey? systemKey,
    EngineeringSupplyRoleKey? role,
    this.media,
    this.serviceEntryId,
  })  : systemKey = systemKey ?? EngineeringSystemKey.fromLegacy(systemClass),
        role = role ?? EngineeringSupplyRoleKey.primary;

  final EngineeringSupplySourceId id;
  final EngineeringPortRef endpoint;
  final EngineeringSystemClass systemClass;
  final EngineeringSystemKey systemKey;
  final EngineeringSupplyRoleKey role;
  final EngineeringMedia? media;
  final ServiceEntryId? serviceEntryId;
}

/// Declares the candidate supply sources for one canonical circuit.
///
/// Membership is deliberately unordered. Source roles carry semantic intent;
/// actual source selection/transfer policy belongs to a later engineering stage.
final class EngineeringCircuitSupply {
  EngineeringCircuitSupply({
    required this.circuitId,
    required Iterable<EngineeringSupplySourceId> sourceIds,
  }) : sourceIds = _uniqueSourceIds(sourceIds);

  final CircuitId circuitId;
  final Set<EngineeringSupplySourceId> sourceIds;
}

/// Immutable validated view that layers multiple-source semantics over the same
/// [CanonicalEngineeringTopology]. It is not a second graph/project store.
final class CanonicalEngineeringSupplyTopology {
  CanonicalEngineeringSupplyTopology({
    required this.topology,
    Iterable<EngineeringSupplySource> sources = const [],
    Iterable<EngineeringCircuitSupply> circuitSupplies = const [],
    Iterable<ServiceEntryId> knownServiceEntryIds = const [],
  }) {
    final knownEntries = Set<ServiceEntryId>.unmodifiable(knownServiceEntryIds);
    final sourceMap = <EngineeringSupplySourceId, EngineeringSupplySource>{};

    for (final source in sources) {
      if (sourceMap.containsKey(source.id)) {
        throw ArgumentError('Duplicate supply source id ${source.id}.');
      }
      _validateSource(source, knownEntries);
      sourceMap[source.id] = source;
    }

    final supplyByCircuit = <CircuitId, EngineeringCircuitSupply>{};
    final circuitIdsBySource = <EngineeringSupplySourceId, List<CircuitId>>{};
    for (final supply in circuitSupplies) {
      if (supplyByCircuit.containsKey(supply.circuitId)) {
        throw ArgumentError(
          'Duplicate supply declaration for circuit ${supply.circuitId}.',
        );
      }
      final circuit = topology.circuit(supply.circuitId);
      if (circuit == null) {
        throw ArgumentError(
          'Supply declaration references unknown circuit ${supply.circuitId}.',
        );
      }
      for (final sourceId in supply.sourceIds) {
        final source = sourceMap[sourceId];
        if (source == null) {
          throw ArgumentError(
            'Circuit ${supply.circuitId} references unknown supply source '
            '$sourceId.',
          );
        }
        _validateCircuitSource(circuit, source);
        (circuitIdsBySource[sourceId] ??= []).add(circuit.id);
      }
      supplyByCircuit[supply.circuitId] = supply;
    }

    _sources = Map.unmodifiable(sourceMap);
    _supplyByCircuit = Map.unmodifiable(supplyByCircuit);
    _circuitIdsBySource = Map.unmodifiable({
      for (final entry in circuitIdsBySource.entries)
        entry.key: List<CircuitId>.unmodifiable(entry.value..sort(_byEntityId)),
    });
  }

  final CanonicalEngineeringTopology topology;

  late final Map<EngineeringSupplySourceId, EngineeringSupplySource> _sources;
  late final Map<CircuitId, EngineeringCircuitSupply> _supplyByCircuit;
  late final Map<EngineeringSupplySourceId, List<CircuitId>>
      _circuitIdsBySource;

  List<EngineeringSupplySource> get sources {
    final values = _sources.values.toList()
      ..sort((left, right) => left.id.value.compareTo(right.id.value));
    return List.unmodifiable(values);
  }

  EngineeringSupplySource? source(EngineeringSupplySourceId id) => _sources[id];

  EngineeringCircuitSupply? supplyForCircuit(CircuitId id) =>
      _supplyByCircuit[id];

  List<EngineeringSupplySource> sourcesForCircuit(CircuitId id) {
    final supply = _supplyByCircuit[id];
    if (supply == null) return const [];
    final values = supply.sourceIds
        .map((sourceId) => _sources[sourceId]!)
        .toList()
      ..sort((left, right) => left.id.value.compareTo(right.id.value));
    return List.unmodifiable(values);
  }

  List<EngineeringCircuit> circuitsForSource(EngineeringSupplySourceId id) =>
      List.unmodifiable(
        (_circuitIdsBySource[id] ?? const <CircuitId>[]).map(
          (circuitId) => topology.circuit(circuitId)!,
        ),
      );

  void _validateSource(
    EngineeringSupplySource source,
    Set<ServiceEntryId> knownEntries,
  ) {
    final graph = topology.graph;
    final component = graph.component(source.endpoint.componentId);
    final port = graph.port(source.endpoint);
    if (component == null || port == null) {
      throw ArgumentError(
        'Supply source ${source.id} references unknown endpoint '
        '${source.endpoint}.',
      );
    }
    if (port.direction == EngineeringPortDirection.input) {
      throw ArgumentError(
        'Supply source ${source.id} must use an output or bidirectional port.',
      );
    }
    if (component.systemClass != source.systemClass ||
        component.systemKey != source.systemKey) {
      throw ArgumentError(
        'Supply source ${source.id} system does not match its component.',
      );
    }
    if (source.media != null && !port.supportsMedia(source.media!)) {
      throw ArgumentError(
        'Supply source ${source.id} medium is not supported by its endpoint.',
      );
    }
    final usableOutgoing = graph
        .outgoingConnections(source.endpoint.componentId)
        .where((edge) => edge.fromPortId == source.endpoint.portId)
        .where(
          (edge) =>
              edge.systemKey == source.systemKey &&
              edge.systemClass == source.systemClass,
        )
        .where((edge) => source.media == null || edge.media == source.media);
    if (usableOutgoing.isEmpty) {
      throw ArgumentError(
        'Supply source ${source.id} endpoint has no compatible outgoing edge.',
      );
    }
    final serviceEntryId = source.serviceEntryId;
    if (serviceEntryId != null && !knownEntries.contains(serviceEntryId)) {
      throw ArgumentError(
        'Supply source ${source.id} references unknown service entry '
        '$serviceEntryId.',
      );
    }
  }

  void _validateCircuitSource(
    EngineeringCircuit circuit,
    EngineeringSupplySource source,
  ) {
    if (circuit.systemClass != source.systemClass ||
        circuit.systemKey != source.systemKey) {
      throw ArgumentError(
        'Supply source ${source.id} system does not match circuit '
        '${circuit.id}.',
      );
    }
    if (circuit.media != null &&
        source.media != null &&
        circuit.media != source.media) {
      throw ArgumentError(
        'Supply source ${source.id} medium does not match circuit '
        '${circuit.id}.',
      );
    }

    final reachableByMedia =
        <EngineeringMedia?, Set<EngineeringConnectionId>>{};
    for (final connectionId in circuit.connectionIds) {
      final connection = topology.graph.connection(connectionId)!;
      final medium = source.media ?? circuit.media ?? connection.media;
      final reachable = reachableByMedia.putIfAbsent(
        medium,
        () => _reachableSupplyConnections(topology.graph, source, medium),
      );
      if (!reachable.contains(connectionId)) {
        throw ArgumentError(
          'Supply source ${source.id} cannot reach circuit ${circuit.id} '
          'connection $connectionId from endpoint ${source.endpoint} through '
          'system ${source.systemKey} and medium $medium.',
        );
      }
    }
  }
}

// Only the declared source port injects supply. Intermediate components retain
// the existing logical through-component model; no physical transfer or load
// flow is inferred. Explicit media cannot be crossed or replaced with null.
Set<EngineeringConnectionId> _reachableSupplyConnections(
  CanonicalEngineeringGraph graph,
  EngineeringSupplySource source,
  EngineeringMedia? medium,
) {
  final start = source.endpoint.componentId;
  final visited = <ComponentId>{start};
  final queue = ListQueue<ComponentId>()..add(start);
  final reachable = <EngineeringConnectionId>{};
  while (queue.isNotEmpty) {
    final current = queue.removeFirst();
    for (final edge in graph.outgoingConnections(current)) {
      if (current == start && edge.fromPortId != source.endpoint.portId) {
        continue;
      }
      if (edge.systemKey != source.systemKey ||
          edge.systemClass != source.systemClass ||
          (medium != null && edge.media != medium)) {
        continue;
      }
      reachable.add(edge.id);
      if (visited.add(edge.toComponentId)) queue.add(edge.toComponentId);
    }
  }
  return reachable;
}

Set<EngineeringSupplySourceId> _uniqueSourceIds(
  Iterable<EngineeringSupplySourceId> values,
) {
  final result = <EngineeringSupplySourceId>{};
  for (final value in values) {
    if (!result.add(value)) {
      throw ArgumentError('Duplicate circuit supply source id $value.');
    }
  }
  if (result.isEmpty) {
    throw ArgumentError('A circuit supply requires at least one source.');
  }
  return Set.unmodifiable(result);
}

int _byEntityId(EntityId left, EntityId right) =>
    left.value.compareTo(right.value);

String _nonEmpty(String value, String name) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, name, 'Must be non-empty.');
  }
  return value;
}
