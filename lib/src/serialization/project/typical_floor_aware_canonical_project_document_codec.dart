import '../../application/project/project_snapshot.dart';
import '../../domain/generation_provenance.dart';
import '../../domain/project_aggregate.dart';
import '../../domain/project_identity.dart';
import '../../domain/typical_floor.dart';
import 'applied_engineering_proposal_aware_canonical_project_document_codec.dart';
import 'project_document_codec.dart';

/// Additive v14 persistence for P10.4 lineage in the existing provenance owner.
/// Old schemas load with empty typical-floor metadata. The inner v13 codec is
/// deliberately given no P10 state, so its fail-closed downgrade guard remains
/// effective for callers that accidentally select an older persistence codec.
final class TypicalFloorAwareCanonicalProjectDocumentCodec
    implements ProjectDocumentCodec {
  const TypicalFloorAwareCanonicalProjectDocumentCodec();

  static const int schemaVersion = 14;
  static const _base =
      AppliedEngineeringProposalAwareCanonicalProjectDocumentCodec();

  @override
  int get currentSchemaVersion => schemaVersion;

  @override
  ProjectDocument encode(ProjectSnapshot snapshot) {
    final registry =
        snapshot.aggregate.engineeringMetadata.generationProvenanceRegistry;
    if (registry.levelCompositions.isNotEmpty) {
      throw const FormatException(
          'Level apartment composition requires project schema v15.');
    }
    _validate(registry, snapshot.aggregate.stores);
    final base = _base.encode(_withRegistry(snapshot,
        registry.copyWith(typicalFloorDefinitions: {}, floorInstances: {})));
    final definitions = registry.typicalFloorDefinitions.values.toList()
      ..sort((a, b) => a.id.value.compareTo(b.id.value));
    final instances = registry.floorInstances.values.toList()
      ..sort((a, b) => a.levelId.value.compareTo(b.levelId.value));
    return ProjectDocument(schemaVersion: schemaVersion, payload: {
      ...base.payload,
      'typicalFloorLineage': {
        'schemaVersion': 1,
        'definitions': [
          for (final definition in definitions) definition.toCanonicalJson()
        ],
        'instances': [
          for (final instance in instances) instance.toCanonicalJson()
        ],
      },
    });
  }

  @override
  ProjectSnapshot decode(ProjectDocument document) {
    if (document.payload.containsKey('levelApartmentCompositions')) {
      throw const FormatException(
          'Level apartment composition requires project schema v15.');
    }
    if (document.schemaVersion < 1 || document.schemaVersion > schemaVersion) {
      throw FormatException(
          'Unsupported canonical project schema ${document.schemaVersion}.');
    }
    if (document.schemaVersion < schemaVersion) {
      if (document.payload.containsKey('typicalFloorLineage')) {
        throw const FormatException(
            'Typical-floor lineage requires project schema v14.');
      }
      return _base.decode(document);
    }
    try {
      final lineage = _map(document.payload['typicalFloorLineage'],
          {'schemaVersion', 'definitions', 'instances'});
      if (_integer(lineage['schemaVersion']) != 1) {
        throw const FormatException(
            'Unsupported typical-floor lineage schema.');
      }
      final definitions = <TypicalFloorDefinitionId, TypicalFloorDefinition>{};
      for (final raw in _list(lineage['definitions'])) {
        final value = _map(raw, {
          'id',
          'buildingId',
          'templateId',
          'templateVersion',
          'definitionKey',
          'patternFingerprint',
          'entityKinds'
        });
        final id = TypicalFloorDefinitionId(_string(value['id']));
        if (definitions.containsKey(id)) {
          throw const FormatException('Duplicate typical-floor definition.');
        }
        definitions[id] = TypicalFloorDefinition(
          id: id,
          buildingId: BuildingId(_string(value['buildingId'])),
          templateId: TemplateId(_string(value['templateId'])),
          templateVersion: _integer(value['templateVersion']),
          definitionKey: _normalizedString(value['definitionKey']),
          patternFingerprint: _string(value['patternFingerprint']),
          entityKinds: {
            for (final entry in _map(value['entityKinds']).entries)
              entry.key: _enum(TypicalFloorEntityKind.values, entry.value)
          },
        );
      }
      final instances = <LevelId, TypicalFloorInstance>{};
      for (final raw in _list(lineage['instances'])) {
        final value = _map(raw, {
          'levelId',
          'definitionId',
          'generationKey',
          'patternFingerprint',
          'detached',
          'entities',
          'overriddenProperties',
          'removedGenerationKeys'
        });
        final id = LevelId(_string(value['levelId']));
        if (instances.containsKey(id)) {
          throw const FormatException('Duplicate typical-floor instance.');
        }
        final overrides = <String, Set<GenerationPropertyKey>>{};
        for (final entry in _map(value['overriddenProperties']).entries) {
          final properties = _list(entry.value)
              .map((raw) => _enum(GenerationPropertyKey.values, raw))
              .toList();
          if (properties.toSet().length != properties.length) {
            throw const FormatException('Duplicate overridden property.');
          }
          overrides[entry.key] = properties.toSet();
        }
        final removed =
            _list(value['removedGenerationKeys']).map(_string).toList();
        if (removed.toSet().length != removed.length) {
          throw const FormatException('Duplicate removed generation key.');
        }
        instances[id] = TypicalFloorInstance(
          levelId: id,
          definitionId:
              TypicalFloorDefinitionId(_string(value['definitionId'])),
          generationKey: _normalizedString(value['generationKey']),
          patternFingerprint: _string(value['patternFingerprint']),
          entities: {
            for (final entry in _map(value['entities']).entries)
              entry.key: _entityId(entry.value)
          },
          detached: _boolean(value['detached']),
          overriddenProperties: overrides,
          removedGenerationKeys: removed,
        );
      }
      final base = _base.decode(ProjectDocument(
          schemaVersion: 13,
          payload: {...document.payload}..remove('typicalFloorLineage')));
      final registry = base
          .aggregate.engineeringMetadata.generationProvenanceRegistry
          .copyWith(
              typicalFloorDefinitions: definitions, floorInstances: instances);
      _validate(registry, base.aggregate.stores);
      return _withRegistry(base, registry);
    } on FormatException {
      rethrow;
    } on ArgumentError catch (error) {
      throw FormatException('Malformed typical-floor lineage: $error');
    } on TypicalFloorLineageException catch (error) {
      throw FormatException(error.code);
    }
  }

  static void _validate(
          GenerationProvenanceRegistry registry, ProjectEntityStores stores) =>
      TypicalFloorLineageIntegrity.validateOrThrow(
          definitions: registry.typicalFloorDefinitions,
          instances: registry.floorInstances,
          stores: stores);

  static ProjectSnapshot _withRegistry(
      ProjectSnapshot snapshot, GenerationProvenanceRegistry registry) {
    final project = snapshot.aggregate;
    return snapshot.copyWith(
        aggregate: ProjectAggregateRoot(
            id: project.id,
            siteId: project.siteId,
            version: project.version,
            engineeringMetadata: project.engineeringMetadata
                .withGenerationProvenanceRegistry(registry),
            stores: project.stores));
  }
}

EntityId _entityId(Object? raw) {
  final value = _map(raw, {'kind', 'value'});
  final id = _string(value['value']);
  return switch (_enum(TypicalFloorEntityKind.values, value['kind'])) {
    TypicalFloorEntityKind.level => LevelId(id),
    TypicalFloorEntityKind.zone => ZoneId(id),
    TypicalFloorEntityKind.space => SpaceId(id),
    TypicalFloorEntityKind.boundaryEdge => BoundaryEdgeId(id),
    TypicalFloorEntityKind.opening => OpeningId(id),
    TypicalFloorEntityKind.adjacency => SpaceAdjacencyId(id),
  };
}

Map<String, Object?> _map(Object? value, [Set<String>? expected]) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw const FormatException('Expected an object with string keys.');
  }
  final result = Map<String, Object?>.from(value);
  if (expected != null &&
      (result.length != expected.length ||
          !expected.containsAll(result.keys))) {
    throw const FormatException('Unknown or missing typical-floor field.');
  }
  return result;
}

List<Object?> _list(Object? value) {
  if (value is! List) throw const FormatException('Expected a list.');
  return List<Object?>.from(value);
}

String _string(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    throw const FormatException('Expected a non-empty string.');
  }
  return value;
}

int _integer(Object? value) {
  if (value is! int) throw const FormatException('Expected an integer.');
  return value;
}

String _normalizedString(Object? value) {
  final text = _string(value);
  if (text != text.trim()) {
    throw const FormatException('Expected a normalized semantic key.');
  }
  return text;
}

bool _boolean(Object? value) {
  if (value is! bool) throw const FormatException('Expected a boolean.');
  return value;
}

T _enum<T extends Enum>(List<T> values, Object? raw) {
  for (final value in values) {
    if (value.name == raw) return value;
  }
  throw const FormatException('Unsupported typical-floor enum value.');
}
