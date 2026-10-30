import 'canonical_engineering_graph.dart';
import 'engineering_classification.dart';
import 'engineering_graph.dart';
import 'project_identity.dart';

export 'project_identity.dart' show EngineeringGroupId, LoopId;

/// Canonical logical circuit membership over existing graph connections.
///
/// A circuit can branch, therefore membership is an unordered set. P11.3 does
/// not calculate loads, protection or cable sizes and owns no route geometry.
final class EngineeringCircuit {
  EngineeringCircuit({
    required this.id,
    required this.systemClass,
    required Iterable<EngineeringConnectionId> connectionIds,
    EngineeringSystemKey? systemKey,
    this.media,
  })  : systemKey = systemKey ?? EngineeringSystemKey.fromLegacy(systemClass),
        connectionIds = _uniqueIds(
          connectionIds,
          label: 'circuit connection id',
          allowEmpty: false,
        );

  final CircuitId id;
  final EngineeringSystemClass systemClass;
  final EngineeringSystemKey systemKey;
  final EngineeringMedia? media;
  final Set<EngineeringConnectionId> connectionIds;
}

/// Canonical closed logical traversal.
///
/// Unlike [EngineeringCircuit], a loop has ordered edge membership because
/// continuity and closure are part of the abstraction itself.
final class EngineeringLoop {
  EngineeringLoop({
    required this.id,
    required this.systemClass,
    required Iterable<EngineeringConnectionId> connectionIds,
    EngineeringSystemKey? systemKey,
    this.media,
    this.circuitId,
  })  : systemKey = systemKey ?? EngineeringSystemKey.fromLegacy(systemClass),
        connectionIds = List.unmodifiable(connectionIds) {
    if (this.connectionIds.length < 2) {
      throw ArgumentError(
          'Engineering loop requires at least two connections.');
    }
    final unique = this.connectionIds.toSet();
    if (unique.length != this.connectionIds.length) {
      throw ArgumentError('Engineering loop cannot repeat a connection id.');
    }
  }

  final LoopId id;
  final EngineeringSystemClass systemClass;
  final EngineeringSystemKey systemKey;
  final EngineeringMedia? media;
  final CircuitId? circuitId;
  final List<EngineeringConnectionId> connectionIds;
}

/// Semantic grouping independent from electrical circuit/loop topology.
///
/// Groups may span disciplines and may contain any combination of graph
/// components, graph connections, circuits and loops. The semantic type is an
/// opaque extensible id rather than a closed enum.
final class EngineeringGroup {
  EngineeringGroup({
    required this.id,
    required this.semanticTypeId,
    Iterable<ComponentId> componentIds = const [],
    Iterable<EngineeringConnectionId> connectionIds = const [],
    Iterable<CircuitId> circuitIds = const [],
    Iterable<LoopId> loopIds = const [],
  })  : componentIds = _uniqueIds(
          componentIds,
          label: 'group component id',
          allowEmpty: true,
        ),
        connectionIds = _uniqueIds(
          connectionIds,
          label: 'group connection id',
          allowEmpty: true,
        ),
        circuitIds = _uniqueIds(
          circuitIds,
          label: 'group circuit id',
          allowEmpty: true,
        ),
        loopIds = _uniqueIds(
          loopIds,
          label: 'group loop id',
          allowEmpty: true,
        ) {
    if (semanticTypeId.trim().isEmpty) {
      throw ArgumentError.value(
        semanticTypeId,
        'semanticTypeId',
        'Must be non-empty.',
      );
    }
    if (this.componentIds.isEmpty &&
        this.connectionIds.isEmpty &&
        this.circuitIds.isEmpty &&
        this.loopIds.isEmpty) {
      throw ArgumentError(
          'Engineering group must contain at least one member.');
    }
  }

  final EngineeringGroupId id;
  final String semanticTypeId;
  final Set<ComponentId> componentIds;
  final Set<EngineeringConnectionId> connectionIds;
  final Set<CircuitId> circuitIds;
  final Set<LoopId> loopIds;
}

/// Immutable canonical topology view layered over [CanonicalEngineeringGraph].
///
/// This object is not a second project store. It validates and indexes circuit,
/// loop and group abstractions against the authoritative graph passed to it.
/// Persistence and mutation lifecycle integration are intentionally deferred to
/// P11.8.
final class CanonicalEngineeringTopology {
  CanonicalEngineeringTopology({
    required this.graph,
    Iterable<EngineeringCircuit> circuits = const [],
    Iterable<EngineeringLoop> loops = const [],
    Iterable<EngineeringGroup> groups = const [],
  }) {
    final circuitMap = <CircuitId, EngineeringCircuit>{};
    final circuitByConnection = <EngineeringConnectionId, CircuitId>{};
    for (final circuit in circuits) {
      if (circuitMap.containsKey(circuit.id)) {
        throw ArgumentError('Duplicate circuit id ${circuit.id}.');
      }
      _validateCircuit(circuit, circuitByConnection);
      circuitMap[circuit.id] = circuit;
      for (final connectionId in circuit.connectionIds) {
        circuitByConnection[connectionId] = circuit.id;
      }
    }

    for (final connection in graph.connections) {
      final legacyCircuitId = connection.circuitId;
      if (legacyCircuitId == null) continue;
      final circuit = circuitMap[legacyCircuitId];
      if (circuit != null && !circuit.connectionIds.contains(connection.id)) {
        throw ArgumentError(
          'Connection ${connection.id} declares circuit $legacyCircuitId but '
          'the canonical circuit does not contain it.',
        );
      }
    }

    final loopMap = <LoopId, EngineeringLoop>{};
    final loopsByConnection = <EngineeringConnectionId, List<LoopId>>{};
    for (final loop in loops) {
      if (loopMap.containsKey(loop.id)) {
        throw ArgumentError('Duplicate loop id ${loop.id}.');
      }
      _validateLoop(loop, circuitMap);
      loopMap[loop.id] = loop;
      for (final connectionId in loop.connectionIds) {
        (loopsByConnection[connectionId] ??= []).add(loop.id);
      }
    }

    final groupMap = <EngineeringGroupId, EngineeringGroup>{};
    for (final group in groups) {
      if (groupMap.containsKey(group.id)) {
        throw ArgumentError('Duplicate engineering group id ${group.id}.');
      }
      _validateGroup(group, circuitMap, loopMap);
      groupMap[group.id] = group;
    }

    _circuits = Map.unmodifiable(circuitMap);
    _loops = Map.unmodifiable(loopMap);
    _groups = Map.unmodifiable(groupMap);
    _circuitByConnection = Map.unmodifiable(circuitByConnection);
    _loopsByConnection = Map.unmodifiable({
      for (final entry in loopsByConnection.entries)
        entry.key: List<LoopId>.unmodifiable(entry.value),
    });
  }

  final CanonicalEngineeringGraph graph;

  late final Map<CircuitId, EngineeringCircuit> _circuits;
  late final Map<LoopId, EngineeringLoop> _loops;
  late final Map<EngineeringGroupId, EngineeringGroup> _groups;
  late final Map<EngineeringConnectionId, CircuitId> _circuitByConnection;
  late final Map<EngineeringConnectionId, List<LoopId>> _loopsByConnection;

  List<EngineeringCircuit> get circuits => List.unmodifiable(_circuits.values);
  List<EngineeringLoop> get loops => List.unmodifiable(_loops.values);
  List<EngineeringGroup> get groups => List.unmodifiable(_groups.values);

  EngineeringCircuit? circuit(CircuitId id) => _circuits[id];
  EngineeringLoop? loop(LoopId id) => _loops[id];
  EngineeringGroup? group(EngineeringGroupId id) => _groups[id];

  EngineeringCircuit? circuitForConnection(EngineeringConnectionId id) {
    final circuitId = _circuitByConnection[id];
    return circuitId == null ? null : _circuits[circuitId];
  }

  List<EngineeringLoop> loopsForConnection(EngineeringConnectionId id) =>
      List.unmodifiable(
        (_loopsByConnection[id] ?? const <LoopId>[])
            .map((loopId) => _loops[loopId]!),
      );

  void _validateCircuit(
    EngineeringCircuit circuit,
    Map<EngineeringConnectionId, CircuitId> circuitByConnection,
  ) {
    for (final connectionId in circuit.connectionIds) {
      final connection = _requireConnection(connectionId);
      final existingOwner = circuitByConnection[connectionId];
      if (existingOwner != null && existingOwner != circuit.id) {
        throw ArgumentError(
          'Connection $connectionId cannot belong to both circuit '
          '$existingOwner and ${circuit.id}.',
        );
      }
      if (connection.systemClass != circuit.systemClass ||
          connection.systemKey != circuit.systemKey) {
        throw ArgumentError(
          'Circuit ${circuit.id} system does not match connection '
          '$connectionId.',
        );
      }
      if (circuit.media != null && connection.media != circuit.media) {
        throw ArgumentError(
          'Circuit ${circuit.id} medium does not match connection '
          '$connectionId.',
        );
      }
      final declaredCircuitId = connection.circuitId;
      if (declaredCircuitId != null && declaredCircuitId != circuit.id) {
        throw ArgumentError(
          'Connection $connectionId declares circuit $declaredCircuitId, not '
          '${circuit.id}.',
        );
      }
    }
  }

  void _validateLoop(
    EngineeringLoop loop,
    Map<CircuitId, EngineeringCircuit> circuits,
  ) {
    final resolved = <EngineeringGraphConnection>[];
    for (final connectionId in loop.connectionIds) {
      final connection = _requireConnection(connectionId);
      if (connection.systemClass != loop.systemClass ||
          connection.systemKey != loop.systemKey) {
        throw ArgumentError(
          'Loop ${loop.id} system does not match connection $connectionId.',
        );
      }
      if (loop.media != null && connection.media != loop.media) {
        throw ArgumentError(
          'Loop ${loop.id} medium does not match connection $connectionId.',
        );
      }
      resolved.add(connection);
    }

    for (var index = 0; index < resolved.length; index++) {
      final current = resolved[index];
      final next = resolved[(index + 1) % resolved.length];
      if (current.toComponentId != next.fromComponentId) {
        throw ArgumentError(
          'Loop ${loop.id} is not continuous between ${current.id} and '
          '${next.id}.',
        );
      }
    }

    final circuitId = loop.circuitId;
    if (circuitId != null) {
      final circuit = circuits[circuitId];
      if (circuit == null) {
        throw ArgumentError(
          'Loop ${loop.id} references unknown circuit $circuitId.',
        );
      }
      if (circuit.systemClass != loop.systemClass ||
          circuit.systemKey != loop.systemKey) {
        throw ArgumentError(
          'Loop ${loop.id} system does not match circuit $circuitId.',
        );
      }
      for (final connectionId in loop.connectionIds) {
        if (!circuit.connectionIds.contains(connectionId)) {
          throw ArgumentError(
            'Loop ${loop.id} connection $connectionId is not a member of '
            'circuit $circuitId.',
          );
        }
      }
    }
  }

  void _validateGroup(
    EngineeringGroup group,
    Map<CircuitId, EngineeringCircuit> circuits,
    Map<LoopId, EngineeringLoop> loops,
  ) {
    for (final componentId in group.componentIds) {
      if (graph.component(componentId) == null) {
        throw ArgumentError(
          'Group ${group.id} references unknown component $componentId.',
        );
      }
    }
    for (final connectionId in group.connectionIds) {
      _requireConnection(connectionId);
    }
    for (final circuitId in group.circuitIds) {
      if (!circuits.containsKey(circuitId)) {
        throw ArgumentError(
          'Group ${group.id} references unknown circuit $circuitId.',
        );
      }
    }
    for (final loopId in group.loopIds) {
      if (!loops.containsKey(loopId)) {
        throw ArgumentError(
          'Group ${group.id} references unknown loop $loopId.',
        );
      }
    }
  }

  EngineeringGraphConnection _requireConnection(EngineeringConnectionId id) {
    final connection = graph.connection(id);
    if (connection == null) {
      throw ArgumentError.value(
        id,
        'connectionId',
        'Unknown engineering connection.',
      );
    }
    return connection;
  }
}

Set<T> _uniqueIds<T>(
  Iterable<T> values, {
  required String label,
  required bool allowEmpty,
}) {
  final result = <T>{};
  for (final value in values) {
    if (!result.add(value)) {
      throw ArgumentError('Duplicate $label $value.');
    }
  }
  if (!allowEmpty && result.isEmpty) {
    throw ArgumentError('$label collection must not be empty.');
  }
  return Set.unmodifiable(result);
}
