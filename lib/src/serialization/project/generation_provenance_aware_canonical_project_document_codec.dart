import '../../application/project/project_snapshot.dart';
import '../../domain/generation_provenance.dart';
import '../../domain/generation_provenance_integrity.dart';
import '../../domain/project_aggregate.dart';
import '../../domain/project_identity.dart';
import 'generation_provenance_schema_guard.dart';
import 'project_document_codec.dart';
import 'structural_semantics_aware_canonical_project_document_codec.dart';

/// Schema-v12 additive persistence for P9.12 generation provenance.
///
/// v1..v11 remain owned by the existing codec chain. This wrapper only adds
/// canonical generation manifests and entity-level lineage; old documents load
/// with an explicit empty registry.
final class GenerationProvenanceAwareCanonicalProjectDocumentCodec
    implements ProjectDocumentCodec {
  const GenerationProvenanceAwareCanonicalProjectDocumentCodec();

  static const int schemaVersion = 12;
  static const int provenanceSchemaVersion = 1;
  static const StructuralSemanticsAwareCanonicalProjectDocumentCodec _base =
      StructuralSemanticsAwareCanonicalProjectDocumentCodec();

  @override
  int get currentSchemaVersion => schemaVersion;

  @override
  ProjectDocument encode(ProjectSnapshot snapshot) {
    final registry =
        snapshot.aggregate.engineeringMetadata.generationProvenanceRegistry;
    if (registry.hasTypicalFloorLineage) {
      throw const FormatException(
          'Typical-floor lineage requires project schema v14.');
    }
    GenerationProvenanceIntegrityValidator.validateOrThrow(
      registry,
      project: snapshot.aggregate,
    );
    final base = _base.encode(snapshot);
    return ProjectDocument(
      schemaVersion: schemaVersion,
      payload: <String, Object?>{
        ...base.payload,
        'generationProvenance': _encodeRegistry(registry),
      },
    );
  }

  @override
  ProjectSnapshot decode(ProjectDocument document) {
    if (document.payload.containsKey('typicalFloorLineage')) {
      throw const FormatException(
          'Typical-floor lineage requires project schema v14.');
    }
    if (document.schemaVersion < 1 || document.schemaVersion > schemaVersion) {
      throw FormatException(
        'Unsupported canonical ElecX project schema '
        '${document.schemaVersion}; supported versions are 1..$schemaVersion.',
      );
    }
    if (document.schemaVersion <=
        StructuralSemanticsAwareCanonicalProjectDocumentCodec.schemaVersion) {
      return _base.decode(document);
    }

    final rawProvenance = document.payload['generationProvenance'];
    GenerationProvenanceSchemaGuard.validate(rawProvenance);
    final registry = _decodeRegistry(rawProvenance);
    final base = _base.decode(
      ProjectDocument(
        schemaVersion:
            StructuralSemanticsAwareCanonicalProjectDocumentCodec.schemaVersion,
        payload: document.payload,
      ),
    );
    final stores = base.aggregate.stores;
    registry.validateOrThrow(
      projectId: base.id,
      entityExists: (id) => _entityExists(stores, id),
    );
    GenerationProvenanceIntegrityValidator.validateOrThrow(
      registry,
      project: base.aggregate,
    );
    final aggregate = ProjectAggregateRoot(
      id: base.id,
      siteId: base.siteId,
      version: base.localVersion,
      engineeringMetadata: base.aggregate.engineeringMetadata
          .withGenerationProvenanceRegistry(registry),
      stores: stores,
    );
    return base.copyWith(aggregate: aggregate);
  }

  static Map<String, Object?> _encodeRegistry(
    GenerationProvenanceRegistry registry,
  ) {
    final manifests = registry.manifests.values.toList()
      ..sort((a, b) => a.generationId.value.compareTo(b.generationId.value));
    final entities = registry.entities.values.toList()
      ..sort((a, b) =>
          _entitySortKey(a.entityId).compareTo(_entitySortKey(b.entityId)));
    return <String, Object?>{
      'schemaVersion': provenanceSchemaVersion,
      'manifests': [
        for (final manifest in manifests)
          <String, Object?>{
            'generationId': manifest.generationId.value,
            'originType': manifest.originType.name,
            'providerTemplateId': manifest.providerTemplateId.value,
            'providerTemplateVersion': manifest.providerTemplateVersion,
            'catalogVersion': manifest.catalogVersion,
            'apartmentTemplateId': manifest.apartmentTemplateId.value,
            'apartmentTemplateVersion': manifest.apartmentTemplateVersion,
            'familyId': manifest.familyId,
            'variantSeedId': manifest.variantSeedId,
            'generatorVersion': manifest.generatorVersion,
            'scoringProfileVersion': manifest.scoringProfileVersion,
            'allocatorVersion': manifest.allocatorVersion,
            'geometryAlgorithmVersion': manifest.geometryAlgorithmVersion,
            'normalizedIntentFingerprint': manifest.normalizedIntentFingerprint,
            'selectedCandidateFingerprint':
                manifest.selectedCandidateFingerprint,
            'projectId': manifest.projectId.value,
            'buildingId': manifest.buildingId.value,
            'levelId': manifest.levelId.value,
            'apartmentZoneId': manifest.apartmentZoneId.value,
            'generatedEntityIds': [
              for (final id in manifest.generatedEntityIds.toList()
                ..sort(
                    (a, b) => _entitySortKey(a).compareTo(_entitySortKey(b))))
                _encodeEntityId(id),
            ],
            'removedGenerationKeys': manifest.removedGenerationKeys.toList()
              ..sort(),
          },
      ],
      'entities': [
        for (final provenance in entities)
          <String, Object?>{
            'entityId': _encodeEntityId(provenance.entityId),
            'generationId': provenance.generationId.value,
            'generationKey': provenance.generationKey,
            'generatedProperties':
                provenance.generatedProperties.map((key) => key.name).toList()
                  ..sort(),
            'overriddenProperties':
                provenance.overriddenProperties.map((key) => key.name).toList()
                  ..sort(),
            'lockedFromRegeneration': provenance.lockedFromRegeneration,
            'generatedBaselineFingerprint':
                provenance.generatedBaselineFingerprint,
          },
      ],
    };
  }

  static GenerationProvenanceRegistry _decodeRegistry(Object? raw) {
    final json = _map(raw, 'generationProvenance');
    final version =
        _int(json['schemaVersion'], 'generationProvenance.schemaVersion');
    if (version != provenanceSchemaVersion) {
      throw FormatException(
        'Unsupported generation provenance schema $version; expected '
        '$provenanceSchemaVersion.',
      );
    }
    final manifests = <GenerationId, GenerationManifest>{};
    for (final rawManifest
        in _list(json['manifests'], 'generationProvenance.manifests')) {
      final value = _map(rawManifest, 'generationManifest');
      final generationId = GenerationId(
        _string(value['generationId'], 'generationManifest.generationId'),
      );
      if (manifests.containsKey(generationId)) {
        throw FormatException('Duplicate GenerationId $generationId.');
      }
      manifests[generationId] = GenerationManifest(
        provenanceSchemaVersion: version,
        generationId: generationId,
        originType: _enumByName(
          GenerationOriginType.values,
          value['originType'],
          'generationManifest.originType',
        ),
        providerTemplateId: TemplateId(
          _string(
            value['providerTemplateId'],
            'generationManifest.providerTemplateId',
          ),
        ),
        providerTemplateVersion: _int(
          value['providerTemplateVersion'],
          'generationManifest.providerTemplateVersion',
        ),
        catalogVersion:
            _int(value['catalogVersion'], 'generationManifest.catalogVersion'),
        apartmentTemplateId: TemplateId(
          _string(
            value['apartmentTemplateId'],
            'generationManifest.apartmentTemplateId',
          ),
        ),
        apartmentTemplateVersion: _int(
          value['apartmentTemplateVersion'],
          'generationManifest.apartmentTemplateVersion',
        ),
        familyId: _string(value['familyId'], 'generationManifest.familyId'),
        variantSeedId:
            _string(value['variantSeedId'], 'generationManifest.variantSeedId'),
        generatorVersion: _string(
          value['generatorVersion'],
          'generationManifest.generatorVersion',
        ),
        scoringProfileVersion: _string(
          value['scoringProfileVersion'],
          'generationManifest.scoringProfileVersion',
        ),
        allocatorVersion: _string(
          value['allocatorVersion'],
          'generationManifest.allocatorVersion',
        ),
        geometryAlgorithmVersion: _string(
          value['geometryAlgorithmVersion'],
          'generationManifest.geometryAlgorithmVersion',
        ),
        normalizedIntentFingerprint: _string(
          value['normalizedIntentFingerprint'],
          'generationManifest.normalizedIntentFingerprint',
        ),
        selectedCandidateFingerprint: _string(
          value['selectedCandidateFingerprint'],
          'generationManifest.selectedCandidateFingerprint',
        ),
        projectId: ProjectId(
          _string(value['projectId'], 'generationManifest.projectId'),
        ),
        buildingId: BuildingId(
          _string(value['buildingId'], 'generationManifest.buildingId'),
        ),
        levelId:
            LevelId(_string(value['levelId'], 'generationManifest.levelId')),
        apartmentZoneId: ZoneId(
          _string(
            value['apartmentZoneId'],
            'generationManifest.apartmentZoneId',
          ),
        ),
        generatedEntityIds: _list(
          value['generatedEntityIds'],
          'generationManifest.generatedEntityIds',
        ).map(_decodeEntityId),
        removedGenerationKeys: _stringList(
          value['removedGenerationKeys'],
          'generationManifest.removedGenerationKeys',
        ),
      );
    }

    final entities = <EntityId, EntityGenerationProvenance>{};
    for (final rawEntity
        in _list(json['entities'], 'generationProvenance.entities')) {
      final value = _map(rawEntity, 'entityGenerationProvenance');
      final entityId = _decodeEntityId(value['entityId']);
      if (entities.containsKey(entityId)) {
        throw FormatException('Duplicate entity provenance for $entityId.');
      }
      entities[entityId] = EntityGenerationProvenance(
        entityId: entityId,
        generationId: GenerationId(
          _string(
            value['generationId'],
            'entityGenerationProvenance.generationId',
          ),
        ),
        generationKey: _string(
          value['generationKey'],
          'entityGenerationProvenance.generationKey',
        ),
        generatedProperties: _enumList(
          GenerationPropertyKey.values,
          value['generatedProperties'],
          'entityGenerationProvenance.generatedProperties',
        ),
        overriddenProperties: _enumList(
          GenerationPropertyKey.values,
          value['overriddenProperties'],
          'entityGenerationProvenance.overriddenProperties',
        ),
        lockedFromRegeneration: _bool(
          value['lockedFromRegeneration'],
          'entityGenerationProvenance.lockedFromRegeneration',
        ),
        generatedBaselineFingerprint: _string(
          value['generatedBaselineFingerprint'],
          'entityGenerationProvenance.generatedBaselineFingerprint',
        ),
      );
    }
    return GenerationProvenanceRegistry(
      manifests: manifests,
      entities: entities,
    );
  }

  static Map<String, Object?> _encodeEntityId(EntityId id) =>
      <String, Object?>{'kind': _entityKind(id), 'value': id.value};

  static EntityId _decodeEntityId(Object? raw) {
    final json = _map(raw, 'entityId');
    final kind = _string(json['kind'], 'entityId.kind');
    final value = _string(json['value'], 'entityId.value');
    return switch (kind) {
      'zone' => ZoneId(value),
      'space' => SpaceId(value),
      'opening' => OpeningId(value),
      'adjacency' => SpaceAdjacencyId(value),
      'boundaryEdge' => BoundaryEdgeId(value),
      _ => throw FormatException('Unsupported provenance entity kind $kind.'),
    };
  }

  static String _entityKind(EntityId id) => switch (id) {
        ZoneId _ => 'zone',
        SpaceId _ => 'space',
        OpeningId _ => 'opening',
        SpaceAdjacencyId _ => 'adjacency',
        BoundaryEdgeId _ => 'boundaryEdge',
        _ => throw StateError(
            'Unsupported generated provenance entity ${id.runtimeType}.',
          ),
      };

  static String _entitySortKey(EntityId id) => '${_entityKind(id)}:${id.value}';

  static bool _entityExists(ProjectEntityStores stores, EntityId id) {
    if (id is ZoneId) return stores.zones.containsKey(id);
    if (id is SpaceId) return stores.spaces.containsKey(id);
    if (id is OpeningId) return stores.openings.containsKey(id);
    if (id is SpaceAdjacencyId) return stores.adjacencies.containsKey(id);
    if (id is BoundaryEdgeId) {
      return stores.boundaries.values
          .any((topology) => topology.edges.containsKey(id));
    }
    return false;
  }
}

Map<String, Object?> _map(Object? value, String field) {
  if (value is! Map) throw FormatException('$field must be an object.');
  return value.map((key, item) => MapEntry(key.toString(), item));
}

List<Object?> _list(Object? value, String field) {
  if (value is! List) throw FormatException('$field must be an array.');
  return value.cast<Object?>();
}

String _string(Object? value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$field must be a non-empty string.');
  }
  return value;
}

int _int(Object? value, String field) {
  if (value is! int) throw FormatException('$field must be an integer.');
  return value;
}

bool _bool(Object? value, String field) {
  if (value is! bool) throw FormatException('$field must be a boolean.');
  return value;
}

List<String> _stringList(Object? value, String field) =>
    _list(value, field).map((item) => _string(item, '$field[]')).toList();

List<T> _enumList<T extends Enum>(
  List<T> values,
  Object? raw,
  String field,
) =>
    _list(raw, field)
        .map((item) => _enumByName(values, item, '$field[]'))
        .toList();

T _enumByName<T extends Enum>(List<T> values, Object? value, String field) {
  final raw = _string(value, field);
  for (final candidate in values) {
    if (candidate.name == raw) return candidate;
  }
  throw FormatException('$field contains unsupported value $raw.');
}
