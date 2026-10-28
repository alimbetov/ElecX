import 'component_catalog_v2.dart';
import 'component_placement.dart';
import 'engineering_graph.dart';

final class ComponentPhysicalEnvelopeMm {
  ComponentPhysicalEnvelopeMm({
    required this.widthMm,
    required this.heightMm,
    required this.depthMm,
    this.massGrams,
  }) {
    if (widthMm <= 0 || heightMm <= 0 || depthMm <= 0) {
      throw ArgumentError('Component physical dimensions must be positive.');
    }
    if (massGrams != null && massGrams! <= 0) {
      throw ArgumentError.value(massGrams, 'massGrams', 'Must be positive.');
    }
  }

  final int widthMm;
  final int heightMm;
  final int depthMm;
  final int? massGrams;
}

final class ComponentCatalogSourceMetadata {
  ComponentCatalogSourceMetadata({
    required String manufacturer,
    required String model,
    required String revision,
    this.sourceUri,
    this.verifiedAtIso8601,
  })  : manufacturer = _nonEmpty(manufacturer, 'manufacturer'),
        model = _nonEmpty(model, 'model'),
        revision = _nonEmpty(revision, 'revision');

  final String manufacturer;
  final String model;
  final String revision;
  final String? sourceUri;
  final String? verifiedAtIso8601;
}

/// Explicit compatibility used by selection/auto-configuration. It is kept
/// separate from display taxonomy and from physical placement coordinates.
final class ComponentCompatibilityProfile {
  ComponentCompatibilityProfile({
    required Iterable<EngineeringSystemClass> systems,
    required Iterable<EngineeringConnectionType> connections,
    required Iterable<ComponentHostKind> hostKinds,
  })  : systems = Set.unmodifiable(systems),
        connections = Set.unmodifiable(connections),
        hostKinds = Set.unmodifiable(hostKinds) {
    if (this.systems.isEmpty) {
      throw ArgumentError(
          'At least one compatible engineering system required.');
    }
    if (this.hostKinds.isEmpty) {
      throw ArgumentError('At least one compatible host kind required.');
    }
  }

  final Set<EngineeringSystemClass> systems;
  final Set<EngineeringConnectionType> connections;
  final Set<ComponentHostKind> hostKinds;
}

/// Engineering facts that are unsafe to infer from a catalog display name.
///
/// Unknown physical/source facts remain null instead of being fabricated. Such
/// a record can still be browsed, but [isAutoConfigurationReady] remains false.
final class ComponentCatalogEngineeringMetadata {
  ComponentCatalogEngineeringMetadata({
    required String componentTypeId,
    required this.compatibility,
    this.physicalEnvelope,
    this.source,
  }) : componentTypeId = _nonEmpty(componentTypeId, 'componentTypeId');

  final String componentTypeId;
  final ComponentCompatibilityProfile compatibility;
  final ComponentPhysicalEnvelopeMm? physicalEnvelope;
  final ComponentCatalogSourceMetadata? source;

  bool get isAutoConfigurationReady =>
      physicalEnvelope != null && source != null;
}

final class ComponentCatalogEngineeringRecord {
  ComponentCatalogEngineeringRecord({
    required this.entry,
    required this.metadata,
  }) {
    if (entry.id != metadata.componentTypeId) {
      throw ArgumentError(
        'Catalog entry ${entry.id} does not match metadata '
        '${metadata.componentTypeId}.',
      );
    }
    if (!metadata.compatibility.systems.contains(entry.systemClass)) {
      throw ArgumentError(
        'Compatibility must include catalog system ${entry.systemClass.name}.',
      );
    }
    final portConnections = <EngineeringConnectionType>{
      for (final port in entry.ports) ...port.allowedConnections,
    };
    if (!metadata.compatibility.connections.containsAll(portConnections)) {
      throw ArgumentError(
        'Compatibility connections must include every catalog port medium.',
      );
    }
  }

  final ComponentCatalogEntryV2 entry;
  final ComponentCatalogEngineeringMetadata metadata;

  bool supports({
    required EngineeringSystemClass systemClass,
    EngineeringConnectionType? connectionType,
    ComponentHostKind? hostKind,
    bool requireAutoConfigurationReady = true,
  }) {
    if (requireAutoConfigurationReady && !metadata.isAutoConfigurationReady) {
      return false;
    }
    if (!metadata.compatibility.systems.contains(systemClass)) return false;
    if (connectionType != null &&
        !metadata.compatibility.connections.contains(connectionType)) {
      return false;
    }
    if (hostKind != null &&
        !metadata.compatibility.hostKinds.contains(hostKind)) {
      return false;
    }
    return true;
  }
}

final class ComponentCatalogEngineeringRegistry {
  ComponentCatalogEngineeringRegistry(
    Iterable<ComponentCatalogEngineeringRecord> records,
  ) : _records = _index(records);

  final Map<String, ComponentCatalogEngineeringRecord> _records;

  static Map<String, ComponentCatalogEngineeringRecord> _index(
    Iterable<ComponentCatalogEngineeringRecord> records,
  ) {
    final result = <String, ComponentCatalogEngineeringRecord>{};
    for (final record in records) {
      if (result.containsKey(record.entry.id)) {
        throw ArgumentError(
            'Duplicate engineering metadata ${record.entry.id}.');
      }
      result[record.entry.id] = record;
    }
    return Map.unmodifiable(result);
  }

  ComponentCatalogEngineeringRecord? find(String componentTypeId) =>
      _records[componentTypeId];

  ComponentCatalogEngineeringRecord require(String componentTypeId) {
    final record = _records[componentTypeId];
    if (record == null) {
      throw ArgumentError.value(
        componentTypeId,
        'componentTypeId',
        'Engineering catalog metadata is missing.',
      );
    }
    return record;
  }

  List<ComponentCatalogEngineeringRecord> compatibleCandidates({
    required EngineeringSystemClass systemClass,
    EngineeringConnectionType? connectionType,
    ComponentHostKind? hostKind,
    bool requireAutoConfigurationReady = true,
  }) =>
      List.unmodifiable(
        _records.values.where(
          (record) => record.supports(
            systemClass: systemClass,
            connectionType: connectionType,
            hostKind: hostKind,
            requireAutoConfigurationReady: requireAutoConfigurationReady,
          ),
        ),
      );
}

String _nonEmpty(String value, String name) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, name, 'Must be non-empty.');
  }
  return value;
}
