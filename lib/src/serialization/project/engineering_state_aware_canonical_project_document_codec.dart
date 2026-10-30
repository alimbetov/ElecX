import '../../application/project/project_snapshot.dart';
import '../../domain/canonical_engineering_graph.dart';
import '../../domain/engineering_circuit_topology.dart';
import '../../domain/engineering_classification.dart';
import '../../domain/engineering_dependency_projection.dart';
import '../../domain/engineering_extension.dart';
import '../../domain/engineering_graph.dart';
import '../../domain/engineering_graph_validation.dart';
import '../../domain/engineering_project_state.dart';
import '../../domain/engineering_supply_topology.dart';
import '../../domain/impact_graph.dart';
import '../../domain/project_aggregate.dart';
import '../../domain/project_identity.dart';
import 'composition_provenance_aware_canonical_project_document_codec.dart';
import 'project_document_codec.dart';

/// v20 persists the single project-owned P11 engineering aggregate.
///
/// Earlier canonical documents remain readable and reopen with the default
/// empty engineering state. A P11 payload is never accepted under an older
/// envelope schema.
final class EngineeringStateAwareCanonicalProjectDocumentCodec
    implements ProjectDocumentCodec {
  const EngineeringStateAwareCanonicalProjectDocumentCodec();

  static const schemaVersion = 20;
  static const _base =
      CompositionProvenanceAwareCanonicalProjectDocumentCodec();

  @override
  int get currentSchemaVersion => schemaVersion;

  @override
  ProjectDocument encode(ProjectSnapshot snapshot) {
    final metadata = snapshot.aggregate.engineeringMetadata;
    final state = metadata.engineeringState;
    state.requireKnownServiceEntries(metadata.siteLayout.serviceAnchors.keys);

    final base = _base.encode(snapshot);
    return ProjectDocument(
      schemaVersion: schemaVersion,
      payload: <String, Object?>{
        ...base.payload,
        'engineeringState': state.toCanonicalJson(),
      },
    );
  }

  @override
  ProjectSnapshot decode(ProjectDocument document) {
    if (document.schemaVersion < 1 || document.schemaVersion > schemaVersion) {
      throw const FormatException('Unsupported engineering state schema');
    }
    if (document.schemaVersion < schemaVersion) {
      if (document.payload.containsKey('engineeringState')) {
        throw const FormatException('Engineering state requires v20');
      }
      return _base.decode(document);
    }

    try {
      final rawState = document.payload['engineeringState'];
      final base = _base.decode(
        ProjectDocument(
          schemaVersion: CompositionProvenanceAwareCanonicalProjectDocumentCodec
              .schemaVersion,
          payload: <String, Object?>{...document.payload}
            ..remove('engineeringState'),
        ),
      );
      final metadata = base.aggregate.engineeringMetadata;
      final state = _decodeEngineeringState(
        rawState,
        knownServiceEntryIds: metadata.siteLayout.serviceAnchors.keys,
      );
      final aggregate = base.aggregate;
      return base.copyWith(
        aggregate: ProjectAggregateRoot(
          id: aggregate.id,
          siteId: aggregate.siteId,
          version: aggregate.version,
          stores: aggregate.stores,
          engineeringMetadata: metadata.withEngineeringState(state),
        ),
      );
    } on FormatException {
      rethrow;
    } on ArgumentError {
      throw const FormatException('Malformed engineering state');
    } on StateError {
      throw const FormatException('Invalid engineering state');
    } on TypeError {
      throw const FormatException('Malformed engineering state types');
    }
  }
}

EngineeringProjectState _decodeEngineeringState(
  Object? raw, {
  required Iterable<ServiceEntryId> knownServiceEntryIds,
}) {
  final root = _object(raw, const {
    'schemaVersion',
    'classificationVocabularyVersion',
    'graph',
    'circuits',
    'loops',
    'groups',
    'sources',
    'circuitSupplies',
    'extensionContracts',
    'dependencyRelations',
    'compatibilityProfile',
  });
  if (_integer(root['schemaVersion']) != 1) {
    throw const FormatException('Unsupported engineering aggregate schema');
  }

  final graph = _decodeGraph(root['graph']);
  return EngineeringProjectState(
    graph: graph,
    circuits: _list(root['circuits']).map(_decodeCircuit),
    loops: _list(root['loops']).map(_decodeLoop),
    groups: _list(root['groups']).map(_decodeGroup),
    sources: _list(root['sources']).map(_decodeSource),
    circuitSupplies: _list(root['circuitSupplies']).map(_decodeCircuitSupply),
    extensionContracts:
        _list(root['extensionContracts']).map(_decodeExtensionContract),
    dependencyRelations:
        _list(root['dependencyRelations']).map(_decodeDependencyRelation),
    compatibilityProfile:
        _decodeCompatibilityProfile(root['compatibilityProfile']),
    classificationVocabularyVersion:
        _string(root['classificationVocabularyVersion']),
    knownServiceEntryIds: knownServiceEntryIds,
  );
}

CanonicalEngineeringGraph _decodeGraph(Object? raw) {
  final root = _object(raw, const {'components', 'connections'});
  return CanonicalEngineeringGraph(
    components: _list(root['components']).map(_decodeComponent),
    connections: _list(root['connections']).map(_decodeConnection),
  );
}

EngineeringGraphComponent _decodeComponent(Object? raw) {
  final value = _object(raw, const {
    'id',
    'componentTypeId',
    'discipline',
    'disciplineKey',
    'systemClass',
    'systemKey',
    'ports',
    'ratedPowerW',
    'voltageV',
    'quantity',
  });
  return EngineeringGraphComponent(
    id: ComponentId(_string(value['id'])),
    componentTypeId: _string(value['componentTypeId']),
    discipline: _enumByName(
      EngineeringDiscipline.values,
      value['discipline'],
      'engineering discipline',
    ),
    disciplineKey: EngineeringDisciplineKey(_string(value['disciplineKey'])),
    systemClass: _enumByName(
      EngineeringSystemClass.values,
      value['systemClass'],
      'engineering system class',
    ),
    systemKey: EngineeringSystemKey(_string(value['systemKey'])),
    ports: _list(value['ports']).map(_decodePort),
    ratedPowerW: _nullableInteger(value['ratedPowerW']),
    voltageV: _nullableInteger(value['voltageV']),
    quantity: _integer(value['quantity']),
  );
}

EngineeringPortSpec _decodePort(Object? raw) {
  final value = _object(raw, const {
    'id',
    'direction',
    'allowedConnections',
    'media',
    'capabilities',
  });
  return EngineeringPortSpec.identified(
    portId: PortId(_string(value['id'])),
    direction: _enumByName(
      EngineeringPortDirection.values,
      value['direction'],
      'engineering port direction',
    ),
    allowedConnections: _list(value['allowedConnections'])
        .map(
          (rawType) => _enumByName(
            EngineeringConnectionType.values,
            rawType,
            'engineering connection type',
          ),
        )
        .toSet(),
    media: _list(value['media'])
        .map((rawMedium) => EngineeringMedia(_string(rawMedium)))
        .toSet(),
    capabilities: _list(value['capabilities'])
        .map(
          (rawCapability) => EngineeringPortCapability(_string(rawCapability)),
        )
        .toSet(),
  );
}

EngineeringGraphConnection _decodeConnection(Object? raw) {
  final value = _object(raw, const {
    'id',
    'fromComponentId',
    'fromPortId',
    'toComponentId',
    'toPortId',
    'connectionType',
    'systemClass',
    'systemKey',
    'media',
    'semanticTypeId',
    'routeId',
    'circuitId',
  });
  final medium = _nullableString(value['media']);
  final routeId = _nullableString(value['routeId']);
  final circuitId = _nullableString(value['circuitId']);
  return EngineeringGraphConnection(
    id: EngineeringConnectionId(_string(value['id'])),
    fromComponentId: ComponentId(_string(value['fromComponentId'])),
    fromPortId: PortId(_string(value['fromPortId'])),
    toComponentId: ComponentId(_string(value['toComponentId'])),
    toPortId: PortId(_string(value['toPortId'])),
    connectionType: _enumByName(
      EngineeringConnectionType.values,
      value['connectionType'],
      'engineering connection type',
    ),
    systemClass: _enumByName(
      EngineeringSystemClass.values,
      value['systemClass'],
      'engineering system class',
    ),
    systemKey: EngineeringSystemKey(_string(value['systemKey'])),
    media: medium == null ? null : EngineeringMedia(medium),
    semanticTypeId: _nullableString(value['semanticTypeId']),
    routeId: routeId == null ? null : RouteId(routeId),
    circuitId: circuitId == null ? null : CircuitId(circuitId),
  );
}

EngineeringCircuit _decodeCircuit(Object? raw) {
  final value = _object(raw, const {
    'id',
    'systemClass',
    'systemKey',
    'media',
    'connectionIds',
  });
  final medium = _nullableString(value['media']);
  return EngineeringCircuit(
    id: CircuitId(_string(value['id'])),
    systemClass: _enumByName(
      EngineeringSystemClass.values,
      value['systemClass'],
      'engineering system class',
    ),
    systemKey: EngineeringSystemKey(_string(value['systemKey'])),
    media: medium == null ? null : EngineeringMedia(medium),
    connectionIds: _list(value['connectionIds'])
        .map((id) => EngineeringConnectionId(_string(id))),
  );
}

EngineeringLoop _decodeLoop(Object? raw) {
  final value = _object(raw, const {
    'id',
    'systemClass',
    'systemKey',
    'media',
    'circuitId',
    'connectionIds',
  });
  final medium = _nullableString(value['media']);
  final circuitId = _nullableString(value['circuitId']);
  return EngineeringLoop(
    id: LoopId(_string(value['id'])),
    systemClass: _enumByName(
      EngineeringSystemClass.values,
      value['systemClass'],
      'engineering system class',
    ),
    systemKey: EngineeringSystemKey(_string(value['systemKey'])),
    media: medium == null ? null : EngineeringMedia(medium),
    circuitId: circuitId == null ? null : CircuitId(circuitId),
    connectionIds: _list(value['connectionIds'])
        .map((id) => EngineeringConnectionId(_string(id))),
  );
}

EngineeringGroup _decodeGroup(Object? raw) {
  final value = _object(raw, const {
    'id',
    'semanticTypeId',
    'componentIds',
    'connectionIds',
    'circuitIds',
    'loopIds',
  });
  return EngineeringGroup(
    id: EngineeringGroupId(_string(value['id'])),
    semanticTypeId: _string(value['semanticTypeId']),
    componentIds:
        _list(value['componentIds']).map((id) => ComponentId(_string(id))),
    connectionIds: _list(value['connectionIds'])
        .map((id) => EngineeringConnectionId(_string(id))),
    circuitIds: _list(value['circuitIds']).map((id) => CircuitId(_string(id))),
    loopIds: _list(value['loopIds']).map((id) => LoopId(_string(id))),
  );
}

EngineeringSupplySource _decodeSource(Object? raw) {
  final value = _object(raw, const {
    'id',
    'componentId',
    'portId',
    'systemClass',
    'systemKey',
    'role',
    'media',
    'serviceEntryId',
  });
  final medium = _nullableString(value['media']);
  final serviceEntryId = _nullableString(value['serviceEntryId']);
  return EngineeringSupplySource(
    id: EngineeringSupplySourceId(_string(value['id'])),
    endpoint: EngineeringPortRef(
      componentId: ComponentId(_string(value['componentId'])),
      portId: PortId(_string(value['portId'])),
    ),
    systemClass: _enumByName(
      EngineeringSystemClass.values,
      value['systemClass'],
      'engineering system class',
    ),
    systemKey: EngineeringSystemKey(_string(value['systemKey'])),
    role: EngineeringSupplyRoleKey(_string(value['role'])),
    media: medium == null ? null : EngineeringMedia(medium),
    serviceEntryId:
        serviceEntryId == null ? null : ServiceEntryId(serviceEntryId),
  );
}

EngineeringCircuitSupply _decodeCircuitSupply(Object? raw) {
  final value = _object(raw, const {'circuitId', 'sourceIds'});
  return EngineeringCircuitSupply(
    circuitId: CircuitId(_string(value['circuitId'])),
    sourceIds: _list(value['sourceIds'])
        .map((id) => EngineeringSupplySourceId(_string(id))),
  );
}

EngineeringExtensionContract _decodeExtensionContract(Object? raw) {
  final value = _object(raw, const {
    'id',
    'version',
    'disciplines',
    'systems',
  });
  return EngineeringExtensionContract(
    id: _string(value['id']),
    version: _string(value['version']),
    disciplines: _list(value['disciplines']).map((rawDefinition) {
      final definition = _object(
        rawDefinition,
        const {'key', 'legacyFamily'},
      );
      return EngineeringExtensionDisciplineDefinition(
        key: EngineeringDisciplineKey(_string(definition['key'])),
        legacyFamily: _enumByName(
          EngineeringDiscipline.values,
          definition['legacyFamily'],
          'engineering discipline',
        ),
      );
    }),
    systems: _list(value['systems']).map((rawDefinition) {
      final definition = _object(rawDefinition, const {
        'key',
        'disciplineKey',
        'legacySystemFamily',
        'media',
        'portCapabilities',
      });
      return EngineeringExtensionSystemDefinition(
        key: EngineeringSystemKey(_string(definition['key'])),
        disciplineKey:
            EngineeringDisciplineKey(_string(definition['disciplineKey'])),
        legacySystemFamily: _enumByName(
          EngineeringSystemClass.values,
          definition['legacySystemFamily'],
          'engineering system class',
        ),
        media: _list(definition['media'])
            .map((rawMedium) => EngineeringMedia(_string(rawMedium))),
        portCapabilities: _list(definition['portCapabilities']).map(
          (rawCapability) => EngineeringPortCapability(_string(rawCapability)),
        ),
      );
    }),
  );
}

EngineeringDependencyRelationDefinition _decodeDependencyRelation(Object? raw) {
  final value = _object(raw, const {
    'semanticTypeId',
    'relationKey',
    'symmetric',
  });
  return EngineeringDependencyRelationDefinition(
    semanticTypeId: _string(value['semanticTypeId']),
    relationKey: ImpactDependencyRelationKey(_string(value['relationKey'])),
    symmetric: _boolean(value['symmetric']),
  );
}

EngineeringCompatibilityProfile? _decodeCompatibilityProfile(Object? raw) {
  if (raw == null) return null;
  final value = _object(raw, const {'id', 'revision', 'rules'});
  return EngineeringCompatibilityProfile(
    id: _string(value['id']),
    revision: _string(value['revision']),
    rules: _list(value['rules']).map(_decodeCompatibilityRule),
  );
}

EngineeringConnectionCompatibilityRule _decodeCompatibilityRule(Object? raw) {
  final value = _object(raw, const {
    'id',
    'fromSystemClass',
    'fromSystemKey',
    'toSystemClass',
    'toSystemKey',
    'connectionSystemClass',
    'connectionSystemKey',
    'connectionType',
    'media',
    'allowUnspecifiedMedia',
  });
  final medium = _nullableString(value['media']);
  return EngineeringConnectionCompatibilityRule(
    id: _string(value['id']),
    fromSystemClass: _enumByName(
      EngineeringSystemClass.values,
      value['fromSystemClass'],
      'engineering system class',
    ),
    fromSystemKey: EngineeringSystemKey(_string(value['fromSystemKey'])),
    toSystemClass: _enumByName(
      EngineeringSystemClass.values,
      value['toSystemClass'],
      'engineering system class',
    ),
    toSystemKey: EngineeringSystemKey(_string(value['toSystemKey'])),
    connectionSystemClass: _enumByName(
      EngineeringSystemClass.values,
      value['connectionSystemClass'],
      'engineering system class',
    ),
    connectionSystemKey:
        EngineeringSystemKey(_string(value['connectionSystemKey'])),
    connectionType: _enumByName(
      EngineeringConnectionType.values,
      value['connectionType'],
      'engineering connection type',
    ),
    media: medium == null ? null : EngineeringMedia(medium),
    allowUnspecifiedMedia: _boolean(value['allowUnspecifiedMedia']),
  );
}

Map<String, Object?> _object(Object? raw, Set<String> expectedKeys) {
  if (raw is! Map || raw.keys.any((key) => key is! String)) {
    throw const FormatException('Expected engineering object');
  }
  final value = Map<String, Object?>.from(raw);
  final actualKeys = value.keys.toSet();
  if (actualKeys.length != expectedKeys.length ||
      !actualKeys.containsAll(expectedKeys)) {
    throw const FormatException('Unexpected engineering object fields');
  }
  return value;
}

List<Object?> _list(Object? raw) {
  if (raw is! List) {
    throw const FormatException('Expected engineering list');
  }
  return List<Object?>.from(raw);
}

String _string(Object? raw) {
  if (raw is! String || raw.trim().isEmpty) {
    throw const FormatException('Expected non-empty engineering string');
  }
  return raw;
}

String? _nullableString(Object? raw) {
  if (raw == null) return null;
  return _string(raw);
}

int _integer(Object? raw) {
  if (raw is! int) {
    throw const FormatException('Expected engineering integer');
  }
  return raw;
}

int? _nullableInteger(Object? raw) {
  if (raw == null) return null;
  return _integer(raw);
}

bool _boolean(Object? raw) {
  if (raw is! bool) {
    throw const FormatException('Expected engineering boolean');
  }
  return raw;
}

T _enumByName<T extends Enum>(
  Iterable<T> values,
  Object? raw,
  String label,
) {
  final name = _string(raw);
  for (final value in values) {
    if (value.name == name) return value;
  }
  throw FormatException('Unknown $label: $name');
}
