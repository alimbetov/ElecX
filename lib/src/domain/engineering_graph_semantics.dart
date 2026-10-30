import 'dart:convert';

import 'canonical_engineering_graph.dart';
import 'project_identity.dart';
import 'semantic_sha256.dart';

/// Canonical, order-independent semantic projection of the P11 engineering graph.
///
/// This projection is the single contract used by P11.8 fingerprinting/diffing
/// and, later in the same package, schema-v20 persistence. Collection insertion
/// order is deliberately excluded from semantic identity.
Map<String, Object?> engineeringGraphCanonicalJson(
  CanonicalEngineeringGraph graph,
) {
  final components = graph.components.toList()
    ..sort((a, b) => a.id.value.compareTo(b.id.value));
  final connections = graph.connections.toList()
    ..sort((a, b) => a.id.value.compareTo(b.id.value));

  return <String, Object?>{
    'components': <Object?>[
      for (final component in components) _componentJson(component),
    ],
    'connections': <Object?>[
      for (final connection in connections) _connectionJson(connection),
    ],
  };
}

/// Stable SHA-256 over [engineeringGraphCanonicalJson].
String engineeringGraphFingerprint(CanonicalEngineeringGraph graph) =>
    semanticSha256Hex(jsonEncode(engineeringGraphCanonicalJson(graph)));

/// Deterministic semantic delta between two canonical engineering graphs.
///
/// Entity ids identify ownership. A stable canonical projection determines
/// whether an entity with the same id changed semantically.
final class EngineeringGraphDiff {
  EngineeringGraphDiff({
    required Iterable<ComponentId> addedComponents,
    required Iterable<ComponentId> removedComponents,
    required Iterable<ComponentId> changedComponents,
    required Iterable<EngineeringConnectionId> addedConnections,
    required Iterable<EngineeringConnectionId> removedConnections,
    required Iterable<EngineeringConnectionId> changedConnections,
  })  : addedComponents = List.unmodifiable(addedComponents),
        removedComponents = List.unmodifiable(removedComponents),
        changedComponents = List.unmodifiable(changedComponents),
        addedConnections = List.unmodifiable(addedConnections),
        removedConnections = List.unmodifiable(removedConnections),
        changedConnections = List.unmodifiable(changedConnections);

  final List<ComponentId> addedComponents;
  final List<ComponentId> removedComponents;
  final List<ComponentId> changedComponents;
  final List<EngineeringConnectionId> addedConnections;
  final List<EngineeringConnectionId> removedConnections;
  final List<EngineeringConnectionId> changedConnections;

  bool get isEmpty =>
      addedComponents.isEmpty &&
      removedComponents.isEmpty &&
      changedComponents.isEmpty &&
      addedConnections.isEmpty &&
      removedConnections.isEmpty &&
      changedConnections.isEmpty;

  static EngineeringGraphDiff between(
    CanonicalEngineeringGraph before,
    CanonicalEngineeringGraph after,
  ) {
    final beforeComponents = <ComponentId, String>{
      for (final component in before.components)
        component.id: jsonEncode(_componentJson(component)),
    };
    final afterComponents = <ComponentId, String>{
      for (final component in after.components)
        component.id: jsonEncode(_componentJson(component)),
    };
    final beforeConnections = <EngineeringConnectionId, String>{
      for (final connection in before.connections)
        connection.id: jsonEncode(_connectionJson(connection)),
    };
    final afterConnections = <EngineeringConnectionId, String>{
      for (final connection in after.connections)
        connection.id: jsonEncode(_connectionJson(connection)),
    };

    return EngineeringGraphDiff(
      addedComponents: _addedIds(beforeComponents, afterComponents),
      removedComponents: _addedIds(afterComponents, beforeComponents),
      changedComponents: _changedIds(beforeComponents, afterComponents),
      addedConnections: _addedIds(beforeConnections, afterConnections),
      removedConnections: _addedIds(afterConnections, beforeConnections),
      changedConnections: _changedIds(beforeConnections, afterConnections),
    );
  }
}

Map<String, Object?> _componentJson(EngineeringGraphComponent component) {
  final ports = component.ports.toList()
    ..sort((a, b) => a.portId.value.compareTo(b.portId.value));
  return <String, Object?>{
    'id': component.id.value,
    'componentTypeId': component.componentTypeId,
    'discipline': component.discipline.name,
    'disciplineKey': component.disciplineKey.id,
    'systemClass': component.systemClass.name,
    'systemKey': component.systemKey.id,
    'ports': <Object?>[
      for (final port in ports)
        <String, Object?>{
          'id': port.portId.value,
          'direction': port.direction.name,
          'allowedConnections':
              (port.allowedConnections.map((e) => e.name).toList()..sort()),
          'media': (port.media.map((e) => e.id).toList()..sort()),
          'capabilities': (port.capabilities.map((e) => e.id).toList()..sort()),
        },
    ],
    'ratedPowerW': component.ratedPowerW,
    'voltageV': component.voltageV,
    'quantity': component.quantity,
  };
}

Map<String, Object?> _connectionJson(EngineeringGraphConnection connection) =>
    <String, Object?>{
      'id': connection.id.value,
      'fromComponentId': connection.fromComponentId.value,
      'fromPortId': connection.fromPortId.value,
      'toComponentId': connection.toComponentId.value,
      'toPortId': connection.toPortId.value,
      'connectionType': connection.connectionType.name,
      'systemClass': connection.systemClass.name,
      'systemKey': connection.systemKey.id,
      'media': connection.media?.id,
      'semanticTypeId': connection.semanticTypeId,
      'routeId': connection.routeId?.value,
      'circuitId': connection.circuitId?.value,
    };

List<T> _addedIds<T extends Object>(
  Map<T, String> before,
  Map<T, String> after,
) {
  final ids = after.keys.where((id) => !before.containsKey(id)).toList();
  ids.sort((a, b) => _idValue(a).compareTo(_idValue(b)));
  return ids;
}

List<T> _changedIds<T extends Object>(
  Map<T, String> before,
  Map<T, String> after,
) {
  final ids = before.keys
      .where((id) => after.containsKey(id) && before[id] != after[id])
      .toList();
  ids.sort((a, b) => _idValue(a).compareTo(_idValue(b)));
  return ids;
}

String _idValue(Object id) => switch (id) {
      final EntityId value => value.value,
      _ => throw StateError('Unsupported engineering graph identity: $id'),
    };
