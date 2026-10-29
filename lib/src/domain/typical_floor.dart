import 'dart:convert';

import 'generation_provenance.dart';
import 'project_aggregate.dart';
import 'project_identity.dart';
import 'semantic_sha256.dart';

enum TypicalFloorEntityKind {
  level,
  zone,
  space,
  boundaryEdge,
  opening,
  adjacency
}

/// Immutable lineage contract for one published floor pattern. The fingerprint
/// identifies its ID-free canonical content; live geometry remains exclusively
/// in ProjectEntityStores. This is not a mutable second floor graph.
final class TypicalFloorDefinition {
  TypicalFloorDefinition({
    required this.id,
    required this.buildingId,
    required this.templateId,
    required this.templateVersion,
    required String definitionKey,
    required String patternFingerprint,
    required Map<String, TypicalFloorEntityKind> entityKinds,
  })  : definitionKey = _key(definitionKey),
        patternFingerprint = _fingerprint(patternFingerprint),
        entityKinds = Map.unmodifiable(entityKinds) {
    if (templateVersion <= 0 ||
        this.entityKinds['level'] != TypicalFloorEntityKind.level ||
        this
                .entityKinds
                .values
                .where((kind) => kind == TypicalFloorEntityKind.level)
                .length !=
            1) {
      throw ArgumentError(
          'A floor definition requires one level slot and an exact template version.');
    }
    for (final key in this.entityKinds.keys) {
      if (_key(key) != key) {
        throw ArgumentError('Generation keys must be normalized.');
      }
    }
  }

  final TypicalFloorDefinitionId id;
  final BuildingId buildingId;
  final TemplateId templateId;
  final int templateVersion;
  final String definitionKey;
  final String patternFingerprint;
  final Map<String, TypicalFloorEntityKind> entityKinds;

  Map<String, Object?> toCanonicalJson() => {
        'id': id.value,
        'buildingId': buildingId.value,
        'templateId': templateId.value,
        'templateVersion': templateVersion,
        'definitionKey': definitionKey,
        'patternFingerprint': patternFingerprint,
        'entityKinds': {
          for (final key in entityKinds.keys.toList()..sort())
            key: entityKinds[key]!.name,
        },
      };

  bool sameAs(TypicalFloorDefinition other) =>
      jsonEncode(toCanonicalJson()) == jsonEncode(other.toCanonicalJson());
}

/// Per-level lineage over independent canonical identities. Detached instances
/// retain their identity/evidence even after their definition is removed.
final class TypicalFloorInstance {
  TypicalFloorInstance({
    required this.levelId,
    required this.definitionId,
    required String generationKey,
    required String patternFingerprint,
    required Map<String, EntityId> entities,
    this.detached = false,
    Map<String, Set<GenerationPropertyKey>> overriddenProperties = const {},
    Iterable<String> removedGenerationKeys = const [],
  })  : generationKey = _key(generationKey),
        patternFingerprint = _fingerprint(patternFingerprint),
        entities = Map.unmodifiable(entities),
        overriddenProperties = Map.unmodifiable({
          for (final entry in overriddenProperties.entries)
            entry.key: Set<GenerationPropertyKey>.unmodifiable(entry.value),
        }),
        removedGenerationKeys = Set.unmodifiable(removedGenerationKeys) {
    if (this.entities['level'] != levelId ||
        this.entities.values.toSet().length != this.entities.length ||
        this.entities.values.whereType<LevelId>().length != 1 ||
        this.removedGenerationKeys.contains('level')) {
      throw ArgumentError(
          'A floor instance must own independent entity slots and its LevelId.');
    }
    for (final entry in this.entities.entries) {
      if (_key(entry.key) != entry.key) {
        throw ArgumentError('Generation keys must be normalized.');
      }
      typicalFloorEntityKind(entry.value);
      if (this.removedGenerationKeys.contains(entry.key)) {
        throw ArgumentError('An active floor slot cannot also be removed.');
      }
    }
    for (final key in this.removedGenerationKeys) {
      if (_key(key) != key) {
        throw ArgumentError('Removed keys must be normalized.');
      }
    }
    for (final entry in this.overriddenProperties.entries) {
      if (!this.entities.containsKey(entry.key) || entry.value.isEmpty) {
        throw ArgumentError('Overrides must reference active floor slots.');
      }
    }
  }

  final LevelId levelId;
  final TypicalFloorDefinitionId definitionId;
  final String generationKey;
  final String patternFingerprint;
  final Map<String, EntityId> entities;
  final bool detached;
  final Map<String, Set<GenerationPropertyKey>> overriddenProperties;
  final Set<String> removedGenerationKeys;

  TypicalFloorInstance copyWith({
    bool? detached,
    Map<String, EntityId>? entities,
    Map<String, Set<GenerationPropertyKey>>? overriddenProperties,
    Set<String>? removedGenerationKeys,
  }) =>
      TypicalFloorInstance(
        levelId: levelId,
        definitionId: definitionId,
        generationKey: generationKey,
        patternFingerprint: patternFingerprint,
        entities: entities ?? this.entities,
        detached: detached ?? this.detached,
        overriddenProperties: overriddenProperties ?? this.overriddenProperties,
        removedGenerationKeys:
            removedGenerationKeys ?? this.removedGenerationKeys,
      );

  Map<String, Object?> toCanonicalJson() => {
        'levelId': levelId.value,
        'definitionId': definitionId.value,
        'generationKey': generationKey,
        'patternFingerprint': patternFingerprint,
        'detached': detached,
        'entities': {
          for (final key in entities.keys.toList()..sort())
            key: {
              'kind': typicalFloorEntityKind(entities[key]!).name,
              'value': entities[key]!.value
            },
        },
        'overriddenProperties': {
          for (final key in overriddenProperties.keys.toList()..sort())
            key: overriddenProperties[key]!
                .map((property) => property.name)
                .toList()
              ..sort(),
        },
        'removedGenerationKeys': removedGenerationKeys.toList()..sort(),
      };

  bool sameAs(TypicalFloorInstance other) =>
      jsonEncode(toCanonicalJson()) == jsonEncode(other.toCanonicalJson());
}

TypicalFloorEntityKind typicalFloorEntityKind(EntityId id) => switch (id) {
      LevelId() => TypicalFloorEntityKind.level,
      ZoneId() => TypicalFloorEntityKind.zone,
      SpaceId() => TypicalFloorEntityKind.space,
      BoundaryEdgeId() => TypicalFloorEntityKind.boundaryEdge,
      OpeningId() => TypicalFloorEntityKind.opening,
      SpaceAdjacencyId() => TypicalFloorEntityKind.adjacency,
      _ => throw ArgumentError('Unsupported typical-floor entity identity.'),
    };

final class TypicalFloorLineageException implements Exception {
  const TypicalFloorLineageException(this.code);
  final String code;

  @override
  String toString() => code;
}

/// Semantic comparison excludes floor naming, numbering, datum and persistent
/// identities. Relationships/geometry are expressed through stable local keys.
abstract final class TypicalFloorPattern {
  static String fingerprint({
    required ProjectEntityStores stores,
    required Map<String, EntityId> entities,
  }) {
    final reverse = {
      for (final entry in entities.entries) entry.value: entry.key
    };
    final boundaryEdges = {
      for (final boundary in stores.boundaries.values) ...boundary.edges,
    };
    String key(EntityId id) =>
        reverse[id] ??
        (throw const TypicalFloorLineageException(
            'p10.typical-floor.incomplete-pattern'));
    List<String> keys(Iterable<EntityId> ids) => ids.map(key).toList()..sort();
    Map<String, Object?> payload(EntityId id) {
      if (id is LevelId) {
        final level = stores.levels[id]!;
        return {
          'kind': 'level',
          'zones': keys(level.zoneIds),
          'spaces': keys(level.spaceIds),
          'openings': keys(stores.openings.values
              .where((opening) => opening.levelId == id)
              .map((opening) => opening.id)),
          'adjacencies': keys(stores.adjacencies.values
              .where((adjacency) =>
                  level.spaceIds.contains(adjacency.spaceAId) &&
                  level.spaceIds.contains(adjacency.spaceBId))
              .map((adjacency) => adjacency.id)),
        };
      }
      if (id is ZoneId) {
        final value = stores.zones[id]!;
        return {
          'kind': 'zone',
          'name': value.name,
          'zoneKind': value.kind.name,
          'spaces': keys(value.spaceIds)
        };
      }
      if (id is SpaceId) {
        final value = stores.spaces[id]!;
        return {
          'kind': 'space',
          'name': value.name,
          'type': value.type.name,
          'usage': value.usage.name,
          'boundary': stores.boundaries[id]?.orderedEdgeIds.map(key).toList()
        };
      }
      if (id is BoundaryEdgeId) {
        final edge = boundaryEdges[id]!;
        return {
          'kind': 'boundaryEdge',
          'space': key(edge.spaceId),
          'start': [edge.start.xMm, edge.start.yMm],
          'end': [edge.end.xMm, edge.end.yMm]
        };
      }
      if (id is OpeningId) {
        final value = stores.openings[id]!;
        return {
          'kind': 'opening',
          'openingKind': value.kind.name,
          'spaces': keys(value.connectedSpaceIds),
          'widthMm': value.widthMm,
          'heightMm': value.heightMm,
          'baseElevationMm': value.baseElevationMm
        };
      }
      if (id is SpaceAdjacencyId) {
        final value = stores.adjacencies[id]!;
        return {
          'kind': 'adjacency',
          'adjacencyKind': value.kind.name,
          'spaces': keys([value.spaceAId, value.spaceBId]),
          'opening': value.openingId == null ? null : key(value.openingId!)
        };
      }
      throw const TypicalFloorLineageException(
          'p10.typical-floor.unsupported-entity');
    }

    return semanticSha256Hex(jsonEncode({
      'schema': 'p10.typical-floor-pattern.v1',
      'entities': {
        for (final name in entities.keys.toList()..sort())
          name: payload(entities[name]!)
      },
    }));
  }
}

abstract final class TypicalFloorLineageIntegrity {
  static void validateOrThrow({
    required Map<TypicalFloorDefinitionId, TypicalFloorDefinition> definitions,
    required Map<LevelId, TypicalFloorInstance> instances,
    required ProjectEntityStores stores,
  }) {
    Never fail(String code) =>
        throw TypicalFloorLineageException('p10.typical-floor.$code');
    final definitionKeys = <(BuildingId, String, TemplateId, int)>{};
    for (final entry in definitions.entries) {
      if (entry.key != entry.value.id ||
          !stores.buildings.containsKey(entry.value.buildingId)) {
        fail('invalid-definition-owner');
      }
      final value = entry.value;
      if (!definitionKeys.add((
        value.buildingId,
        value.definitionKey,
        value.templateId,
        value.templateVersion
      ))) {
        fail('ambiguous-definition-key');
      }
    }
    if (instances.isEmpty) return;
    final owned = <EntityId>{};
    final edgeLevels = {
      for (final boundary in stores.boundaries.entries)
        for (final edgeId in boundary.value.edges.keys)
          edgeId: stores.spaces[boundary.key]?.levelId,
    };
    final generationKeys = <(BuildingId, String)>{};
    for (final entry in instances.entries) {
      final instance = entry.value;
      final level = stores.levels[entry.key];
      if (entry.key != instance.levelId || level == null) fail('missing-level');
      if (!generationKeys.add((level.buildingId, instance.generationKey))) {
        fail('duplicate-generation-key');
      }
      final definition = definitions[instance.definitionId];
      if (!instance.detached) {
        if (definition == null ||
            definition.buildingId != level.buildingId ||
            definition.patternFingerprint != instance.patternFingerprint) {
          fail('definition-mismatch');
        }
        final expectedKeys = {
          ...instance.entities.keys,
          ...instance.removedGenerationKeys
        };
        if (expectedKeys.length != definition.entityKinds.length ||
            !expectedKeys.containsAll(definition.entityKinds.keys)) {
          fail('pattern-keys-mismatch');
        }
        for (final entity in instance.entities.entries) {
          if (definition.entityKinds[entity.key] !=
              typicalFloorEntityKind(entity.value)) {
            fail('entity-kind-mismatch');
          }
        }
      }
      for (final id in instance.entities.values) {
        if (!owned.add(id)) fail('aliased-entity');
        final valid = switch (id) {
          LevelId() => id == level.id,
          ZoneId() => stores.zones[id]?.levelId == level.id,
          SpaceId() => stores.spaces[id]?.levelId == level.id,
          BoundaryEdgeId() => edgeLevels[id] == level.id,
          OpeningId() => stores.openings[id]?.levelId == level.id,
          SpaceAdjacencyId() =>
            stores.spaces[stores.adjacencies[id]?.spaceAId]?.levelId ==
                    level.id &&
                stores.spaces[stores.adjacencies[id]?.spaceBId]?.levelId ==
                    level.id,
          _ => false,
        };
        if (!valid) fail('foreign-or-missing-entity');
      }
      if (!instance.detached &&
          instance.overriddenProperties.isEmpty &&
          instance.removedGenerationKeys.isEmpty &&
          TypicalFloorPattern.fingerprint(
                  stores: stores, entities: instance.entities) !=
              instance.patternFingerprint) {
        fail('pattern-mismatch');
      }
    }
  }
}

String _key(String value) {
  final key = value.trim();
  if (key.isEmpty) {
    throw ArgumentError('A semantic generation key is required.');
  }
  return key;
}

String _fingerprint(String value) {
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(value)) {
    throw ArgumentError('A canonical SHA-256 fingerprint is required.');
  }
  return value;
}
