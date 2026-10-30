import 'dart:convert';

import 'boundary_topology.dart';
import 'generation_provenance.dart';
import 'project_aggregate.dart';
import 'project_identity.dart';
import 'semantic_sha256.dart';

final class ApartmentCompositionException implements Exception {
  const ApartmentCompositionException(this.code);
  final String code;
  @override
  String toString() => code;
}

/// Exact rectilinear apartment-local → level-local transform. Clockwise quarter
/// turns retain the P9 integer grid without floating-point resampling.
final class ApartmentPlacementTransform {
  ApartmentPlacementTransform(
      {required this.xMm, required this.yMm, int clockwiseQuarterTurns = 0})
      : clockwiseQuarterTurns = clockwiseQuarterTurns % 4 {
    if (xMm.abs() > 10000000 ||
        yMm.abs() > 10000000 ||
        xMm % 10 != 0 ||
        yMm % 10 != 0) {
      throw ArgumentError(
          'Apartment translation must be a supported integer-mm grid point.');
    }
  }
  final int xMm;
  final int yMm;
  final int clockwiseQuarterTurns;

  BoundaryPointMm apply(BoundaryPointMm point) {
    final (x, y) = switch (clockwiseQuarterTurns) {
      0 => (point.xMm, point.yMm),
      1 => (point.yMm, -point.xMm),
      2 => (-point.xMm, -point.yMm),
      _ => (-point.yMm, point.xMm),
    };
    final result = BoundaryPointMm(xMm: x + xMm, yMm: y + yMm);
    if (result.xMm.abs() > 10000000 || result.yMm.abs() > 10000000) {
      throw const ApartmentCompositionException(
          'p10.apartments.placement-out-of-range');
    }
    return result;
  }

  Map<String, Object?> toCanonicalJson() =>
      {'xMm': xMm, 'yMm': yMm, 'clockwiseQuarterTurns': clockwiseQuarterTurns};
}

final class ComposedApartmentLineage {
  ComposedApartmentLineage(
      {required this.generationId,
      required this.apartmentZoneId,
      required this.accessSpaceId,
      required String sourceCandidateFingerprint,
      required this.transform})
      : sourceCandidateFingerprint = _sha(sourceCandidateFingerprint);
  final GenerationId generationId;
  final ZoneId apartmentZoneId;
  final SpaceId accessSpaceId;
  final String sourceCandidateFingerprint;
  final ApartmentPlacementTransform transform;

  Map<String, Object?> toCanonicalJson() => {
        'generationId': generationId.value,
        'apartmentZoneId': apartmentZoneId.value,
        'accessSpaceId': accessSpaceId.value,
        'sourceCandidateFingerprint': sourceCandidateFingerprint,
        'transform': transform.toCanonicalJson(),
      };
}

/// Parent composition evidence in the existing provenance owner. Child P9
/// manifests retain their original candidate identities and generation keys.
final class LevelApartmentCompositionManifest {
  LevelApartmentCompositionManifest({
    required this.generationId,
    required this.projectId,
    required this.buildingId,
    required this.levelId,
    required this.compositionKey,
    required this.canonicalRequest,
    required String candidateFingerprint,
    required Map<String, ComposedApartmentLineage> apartments,
    required Map<String, SpaceAdjacencyId> generatedAdjacencies,
    Iterable<String> removedGenerationKeys = const [],
  })  : candidateFingerprint = _sha(candidateFingerprint),
        apartments = Map.unmodifiable(apartments),
        generatedAdjacencies = Map.unmodifiable(generatedAdjacencies),
        removedGenerationKeys = Set.unmodifiable(removedGenerationKeys) {
    if (compositionKey.isEmpty ||
        compositionKey != compositionKey.trim() ||
        this.apartments.isEmpty ||
        this.apartments.length > 128 ||
        this
                .apartments
                .values
                .map((child) => child.generationId)
                .toSet()
                .length !=
            this.apartments.length ||
        this.generatedAdjacencies.values.toSet().length !=
            this.generatedAdjacencies.length) {
      throw ArgumentError(
          'Composition lineage requires independent apartment and relation identities.');
    }
    for (final key in [
      ...this.apartments.keys,
      ...this.generatedAdjacencies.keys,
      ...this.removedGenerationKeys
    ]) {
      if (key.isEmpty || key != key.trim()) {
        throw ArgumentError('Composition keys must be normalized.');
      }
    }
    if (this.removedGenerationKeys.any(this.generatedAdjacencies.containsKey)) {
      throw ArgumentError('Active relation cannot be tombstoned.');
    }
    _validateFrozenRequest();
  }

  static const generatorVersion = 'p10.level-apartments.v1';
  final GenerationId generationId;
  final ProjectId projectId;
  final BuildingId buildingId;
  final LevelId levelId;
  final String compositionKey;
  final String canonicalRequest;
  final String candidateFingerprint;
  final Map<String, ComposedApartmentLineage> apartments;
  final Map<String, SpaceAdjacencyId> generatedAdjacencies;
  final Set<String> removedGenerationKeys;

  LevelApartmentCompositionManifest reconcileRelations(
      ProjectEntityStores stores) {
    final missing = generatedAdjacencies.entries
        .where((entry) => !stores.adjacencies.containsKey(entry.value))
        .toList();
    if (missing.isEmpty) return this;
    return LevelApartmentCompositionManifest(
        generationId: generationId,
        projectId: projectId,
        buildingId: buildingId,
        levelId: levelId,
        compositionKey: compositionKey,
        canonicalRequest: canonicalRequest,
        candidateFingerprint: candidateFingerprint,
        apartments: apartments,
        generatedAdjacencies: {...generatedAdjacencies}
          ..removeWhere((key, id) => !stores.adjacencies.containsKey(id)),
        removedGenerationKeys: {
          ...removedGenerationKeys,
          ...missing.map((entry) => entry.key)
        });
  }

  Map<String, Object?> toCanonicalJson() => {
        'generationId': generationId.value,
        'projectId': projectId.value,
        'buildingId': buildingId.value,
        'levelId': levelId.value,
        'generatorVersion': generatorVersion,
        'compositionKey': compositionKey,
        'canonicalRequest': canonicalRequest,
        'candidateFingerprint': candidateFingerprint,
        'apartments': {
          for (final key in apartments.keys.toList()..sort())
            key: apartments[key]!.toCanonicalJson()
        },
        'generatedAdjacencies': {
          for (final key in generatedAdjacencies.keys.toList()..sort())
            key: generatedAdjacencies[key]!.value
        },
        'removedGenerationKeys': removedGenerationKeys.toList()..sort(),
      };

  bool sameAs(LevelApartmentCompositionManifest other) =>
      jsonEncode(toCanonicalJson()) == jsonEncode(other.toCanonicalJson());

  void _validateFrozenRequest() {
    Never invalid() => throw ArgumentError(
        'Composition lineage does not match its frozen request.');
    if (semanticSha256Hex(canonicalRequest) != candidateFingerprint) invalid();
    final Object? decoded;
    try {
      decoded = jsonDecode(canonicalRequest);
    } on FormatException {
      invalid();
    }
    if (decoded is! Map<String, dynamic> ||
        !_sameKeys(decoded, {
          'schema',
          'projectId',
          'buildingId',
          'levelId',
          'baseVersion',
          'compositionKey',
          'apartments',
          'relations'
        })) {
      invalid();
    }
    if (decoded['schema'] != generatorVersion ||
        decoded['projectId'] != projectId.value ||
        decoded['buildingId'] != buildingId.value ||
        decoded['levelId'] != levelId.value ||
        decoded['compositionKey'] != compositionKey ||
        decoded['baseVersion'] is! int ||
        (decoded['baseVersion'] as int) < 0) {
      invalid();
    }
    final slots = decoded['apartments'];
    if (slots is! List || slots.length != apartments.length) invalid();
    final keys = <String>{};
    for (final raw in slots) {
      if (raw is! Map<String, dynamic> ||
          !_sameKeys(raw, {
            'key',
            'displayName',
            'candidateFingerprint',
            'transform',
            'accessSpaceId'
          })) {
        invalid();
      }
      final key = raw['key'];
      if (key is! String || !keys.add(key)) invalid();
      final child = apartments[key];
      final name = raw['displayName'];
      if (child == null ||
          name is! String ||
          name.isEmpty ||
          name != name.trim() ||
          raw['candidateFingerprint'] != child.sourceCandidateFingerprint ||
          raw['accessSpaceId'] != child.accessSpaceId.value) {
        invalid();
      }
      final transform = raw['transform'];
      if (transform is! Map<String, dynamic> ||
          !_sameKeys(transform, {'xMm', 'yMm', 'clockwiseQuarterTurns'}) ||
          transform['xMm'] != child.transform.xMm ||
          transform['yMm'] != child.transform.yMm ||
          transform['clockwiseQuarterTurns'] !=
              child.transform.clockwiseQuarterTurns) {
        invalid();
      }
    }
    final relations = decoded['relations'];
    final expectedRelations = {
      ...generatedAdjacencies.keys,
      ...removedGenerationKeys
    };
    if (relations is! List ||
        relations.any((key) => key is! String) ||
        relations.toSet().length != relations.length ||
        relations.length != expectedRelations.length ||
        !expectedRelations.containsAll(relations)) {
      invalid();
    }
  }
}

bool _sameKeys(Map<String, dynamic> value, Set<String> expected) =>
    value.length == expected.length && expected.containsAll(value.keys);

abstract final class LevelApartmentCompositionIntegrity {
  static void validateOrThrow(
      {required GenerationProvenanceRegistry registry,
      required ProjectId projectId,
      required ProjectEntityStores stores}) {
    final children = <GenerationId>{};
    final keys = <(LevelId, String)>{};
    final relations = <SpaceAdjacencyId>{};
    for (final entry in registry.levelCompositions.entries) {
      final value = entry.value;
      if (entry.key != value.generationId ||
          value.projectId != projectId ||
          stores.levels[value.levelId]?.buildingId != value.buildingId ||
          registry.manifests.containsKey(value.generationId) ||
          !keys.add((value.levelId, value.compositionKey))) {
        _fail();
      }
      for (final child in value.apartments.values) {
        final manifest = registry.manifests[child.generationId];
        if (!children.add(child.generationId) ||
            manifest == null ||
            manifest.projectId != projectId ||
            manifest.levelId != value.levelId ||
            manifest.buildingId != value.buildingId ||
            manifest.apartmentZoneId != child.apartmentZoneId ||
            manifest.selectedCandidateFingerprint !=
                child.sourceCandidateFingerprint ||
            stores.zones[child.apartmentZoneId]?.levelId != value.levelId ||
            stores.spaces[child.accessSpaceId]?.levelId != value.levelId) {
          _fail();
        }
      }
      for (final id in value.generatedAdjacencies.values) {
        final adjacency = stores.adjacencies[id];
        if (!relations.add(id) ||
            adjacency == null ||
            stores.spaces[adjacency.spaceAId]?.levelId != value.levelId ||
            stores.spaces[adjacency.spaceBId]?.levelId != value.levelId) {
          _fail();
        }
      }
    }
  }

  static Never _fail() => throw const ApartmentCompositionException(
      'p10.apartments.invalid-lineage');
}

String _sha(String value) {
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(value)) {
    throw ArgumentError('Expected a canonical SHA-256 fingerprint.');
  }
  return value;
}
