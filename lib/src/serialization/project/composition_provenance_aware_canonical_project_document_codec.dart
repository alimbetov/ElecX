import '../../application/project/project_snapshot.dart';
import '../../domain/composition_generation_provenance.dart';
import '../../domain/generation_provenance.dart';
import '../../domain/project_aggregate.dart';
import '../../domain/project_identity.dart';
import 'project_document_codec.dart';
import 'service_anchor_aware_canonical_project_document_codec.dart';

/// v19 adds P10 parent evidence to the existing canonical codec/registry.
/// Earlier documents retain their actual lineage; none is fabricated on load.
final class CompositionProvenanceAwareCanonicalProjectDocumentCodec
    implements ProjectDocumentCodec {
  const CompositionProvenanceAwareCanonicalProjectDocumentCodec();
  static const schemaVersion = 19;
  static const _base = ServiceAnchorAwareCanonicalProjectDocumentCodec();
  @override
  int get currentSchemaVersion => schemaVersion;
  @override
  ProjectDocument encode(ProjectSnapshot snapshot) {
    CompositionProvenanceIntegrity.validate(snapshot.aggregate);
    final registry =
        snapshot.aggregate.engineeringMetadata.generationProvenanceRegistry;
    final base =
        _base.encode(_with(snapshot, registry.copyWith(compositions: {})));
    return ProjectDocument(schemaVersion: schemaVersion, payload: {
      ...base.payload,
      'compositionProvenance': {
        'schemaVersion': 1,
        'manifests': [
          for (final id
              in registry.compositions.keys.toList()
                ..sort((a, b) => a.value.compareTo(b.value)))
            registry.compositions[id]!.toJson()
        ]
      }
    });
  }

  @override
  ProjectSnapshot decode(ProjectDocument document) {
    if (document.schemaVersion < 1 || document.schemaVersion > schemaVersion) {
      throw const FormatException('Unsupported composition provenance schema');
    }
    if (document.schemaVersion < schemaVersion) {
      if (document.payload.containsKey('compositionProvenance')) {
        throw const FormatException('Composition provenance requires v19');
      }
      return _base.decode(document);
    }
    try {
      final root = compositionObject(document.payload['compositionProvenance'],
          {'schemaVersion', 'manifests'});
      if (root['schemaVersion'] != 1 || root['manifests'] is! List) {
        throw const FormatException('Unsupported composition registry');
      }
      final manifests = <GenerationId, CompositionGenerationManifest>{};
      for (final raw in root['manifests'] as List) {
        final j = compositionObject(raw, {
          'id',
          'projectId',
          'siteId',
          'commandType',
          'canonicalEvidence',
          'immutableFingerprint',
          'entities',
          'children'
        });
        final id = GenerationId(_string(j['id']));
        if (manifests.containsKey(id)) {
          throw const FormatException('Duplicate composition generation');
        }
        final entities = <String, CompositionGeneratedEntity>{};
        final rawEntities = _map(j['entities']);
        for (final e in rawEntities.entries) {
          final v = compositionObject(
              e.value, {'id', 'baseline', 'overrides', 'removed'});
          if (v['overrides'] is! List || v['removed'] is! bool) {
            throw const FormatException('Invalid composition fields');
          }
          final overrides = (v['overrides'] as List).map(_string).toList();
          if (overrides.toSet().length != overrides.length) {
            throw const FormatException('Duplicate override');
          }
          entities[e.key] = CompositionGeneratedEntity(
              id: compositionEntityIdFromJson(v['id']),
              baseline:
                  _map(v['baseline']).map((k, v) => MapEntry(k, _string(v))),
              overrides: overrides.toSet(),
              removed: v['removed'] as bool);
        }
        manifests[id] = CompositionGenerationManifest(
            id: id,
            projectId: ProjectId(_string(j['projectId'])),
            siteId: SiteId(_string(j['siteId'])),
            commandType: _string(j['commandType']),
            canonicalEvidence: _string(j['canonicalEvidence']),
            entities: entities,
            children: _map(j['children'])
                .map((k, v) => MapEntry(GenerationId(k), _string(v))));
        if (manifests[id]!.immutableFingerprint != j['immutableFingerprint']) {
          throw const FormatException(
              'Composition immutable evidence mismatch');
        }
      }
      final base = _base.decode(ProjectDocument(
          schemaVersion: 18,
          payload: {...document.payload}..remove('compositionProvenance')));
      final result = _with(
          base,
          base.aggregate.engineeringMetadata.generationProvenanceRegistry
              .copyWith(compositions: manifests));
      CompositionProvenanceIntegrity.validate(result.aggregate);
      return result;
    } on FormatException {
      rethrow;
    } on ArgumentError {
      throw const FormatException('Malformed composition provenance');
    } on TypeError {
      throw const FormatException('Malformed composition provenance types');
    } on StateError {
      throw const FormatException('Invalid composition lineage');
    }
  }

  static ProjectSnapshot _with(
      ProjectSnapshot snapshot, GenerationProvenanceRegistry registry) {
    final p = snapshot.aggregate;
    return snapshot.copyWith(
        aggregate: ProjectAggregateRoot(
            id: p.id,
            siteId: p.siteId,
            version: p.version,
            stores: p.stores,
            engineeringMetadata: p.engineeringMetadata
                .withGenerationProvenanceRegistry(registry)));
  }
}

Map<String, Object?> _map(Object? raw) {
  if (raw is! Map || raw.keys.any((k) => k is! String)) {
    throw const FormatException('Expected object');
  }
  return Map<String, Object?>.from(raw);
}

String _string(Object? v) {
  if (v is! String || v.trim().isEmpty) {
    throw const FormatException('Expected non-empty string');
  }
  return v;
}
