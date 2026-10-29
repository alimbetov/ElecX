import '../../application/project/project_snapshot.dart';
import '../../domain/generation_provenance.dart';
import '../../domain/level_apartment_composition.dart';
import '../../domain/project_aggregate.dart';
import '../../domain/project_identity.dart';
import 'project_document_codec.dart';
import 'typical_floor_aware_canonical_project_document_codec.dart';

/// Schema v15 retains P10.5 parent composition → P9 child generation evidence.
final class LevelCompositionAwareCanonicalProjectDocumentCodec
    implements ProjectDocumentCodec {
  const LevelCompositionAwareCanonicalProjectDocumentCodec();
  static const schemaVersion = 15;
  static const _base = TypicalFloorAwareCanonicalProjectDocumentCodec();
  @override
  int get currentSchemaVersion => schemaVersion;

  @override
  ProjectDocument encode(ProjectSnapshot snapshot) {
    final registry =
        snapshot.aggregate.engineeringMetadata.generationProvenanceRegistry;
    LevelApartmentCompositionIntegrity.validateOrThrow(
        registry: registry,
        projectId: snapshot.id,
        stores: snapshot.aggregate.stores);
    final base = _base.encode(
        _withRegistry(snapshot, registry.copyWith(levelCompositions: {})));
    final compositions = registry.levelCompositions.values.toList()
      ..sort((a, b) => a.generationId.value.compareTo(b.generationId.value));
    return ProjectDocument(schemaVersion: schemaVersion, payload: {
      ...base.payload,
      'levelApartmentCompositions': {
        'schemaVersion': 1,
        'manifests': [for (final value in compositions) value.toCanonicalJson()]
      }
    });
  }

  @override
  ProjectSnapshot decode(ProjectDocument document) {
    if (document.schemaVersion < 1 || document.schemaVersion > schemaVersion) {
      throw const FormatException('Unsupported canonical project schema.');
    }
    if (document.schemaVersion < schemaVersion) {
      if (document.payload.containsKey('levelApartmentCompositions')) {
        throw const FormatException('Composition lineage requires schema v15.');
      }
      return _base.decode(document);
    }
    try {
      final json = _map(document.payload['levelApartmentCompositions'],
          {'schemaVersion', 'manifests'});
      if (_int(json['schemaVersion']) != 1) {
        throw const FormatException('Unsupported composition lineage version.');
      }
      final compositions = <GenerationId, LevelApartmentCompositionManifest>{};
      for (final raw in _list(json['manifests'])) {
        final value = _map(raw, {
          'generationId',
          'projectId',
          'buildingId',
          'levelId',
          'generatorVersion',
          'compositionKey',
          'canonicalRequest',
          'candidateFingerprint',
          'apartments',
          'generatedAdjacencies',
          'removedGenerationKeys'
        });
        if (value['generatorVersion'] !=
            LevelApartmentCompositionManifest.generatorVersion) {
          throw const FormatException(
              'Unsupported composition generator version.');
        }
        final id = GenerationId(_string(value['generationId']));
        if (compositions.containsKey(id)) {
          throw const FormatException('Duplicate composition identity.');
        }
        final children = <String, ComposedApartmentLineage>{};
        for (final entry in _map(value['apartments']).entries) {
          final child = _map(entry.value, {
            'generationId',
            'apartmentZoneId',
            'accessSpaceId',
            'sourceCandidateFingerprint',
            'transform'
          });
          final transform =
              _map(child['transform'], {'xMm', 'yMm', 'clockwiseQuarterTurns'});
          final turns = _int(transform['clockwiseQuarterTurns']);
          if (turns < 0 || turns > 3) {
            throw const FormatException(
                'Persisted quarter-turns must be normalized.');
          }
          children[entry.key] = ComposedApartmentLineage(
              generationId: GenerationId(_string(child['generationId'])),
              apartmentZoneId: ZoneId(_string(child['apartmentZoneId'])),
              accessSpaceId: SpaceId(_string(child['accessSpaceId'])),
              sourceCandidateFingerprint:
                  _string(child['sourceCandidateFingerprint']),
              transform: ApartmentPlacementTransform(
                  xMm: _int(transform['xMm']),
                  yMm: _int(transform['yMm']),
                  clockwiseQuarterTurns: turns));
        }
        final removed =
            _list(value['removedGenerationKeys']).map(_string).toList();
        if (removed.toSet().length != removed.length) {
          throw const FormatException('Duplicate removed composition key.');
        }
        compositions[id] = LevelApartmentCompositionManifest(
            generationId: id,
            projectId: ProjectId(_string(value['projectId'])),
            buildingId: BuildingId(_string(value['buildingId'])),
            levelId: LevelId(_string(value['levelId'])),
            compositionKey: _string(value['compositionKey']),
            canonicalRequest: _string(value['canonicalRequest']),
            candidateFingerprint: _string(value['candidateFingerprint']),
            apartments: children,
            generatedAdjacencies: {
              for (final entry in _map(value['generatedAdjacencies']).entries)
                entry.key: SpaceAdjacencyId(_string(entry.value))
            },
            removedGenerationKeys: removed);
      }
      final base = _base.decode(ProjectDocument(
          schemaVersion: 14,
          payload: {...document.payload}
            ..remove('levelApartmentCompositions')));
      final registry = base
          .aggregate.engineeringMetadata.generationProvenanceRegistry
          .copyWith(levelCompositions: compositions);
      LevelApartmentCompositionIntegrity.validateOrThrow(
          registry: registry,
          projectId: base.id,
          stores: base.aggregate.stores);
      return _withRegistry(base, registry);
    } on FormatException {
      rethrow;
    } on ArgumentError catch (error) {
      throw FormatException('Malformed composition lineage: $error');
    } on ApartmentCompositionException catch (error) {
      throw FormatException(error.code);
    }
  }

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

Map<String, Object?> _map(Object? value, [Set<String>? expected]) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw const FormatException('Expected an object with string keys.');
  }
  final json = Map<String, Object?>.from(value);
  if (expected != null &&
      (json.length != expected.length || !expected.containsAll(json.keys))) {
    throw const FormatException('Unknown or missing composition field.');
  }
  return json;
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

int _int(Object? value) {
  if (value is! int) throw const FormatException('Expected an integer.');
  return value;
}
