import 'dart:convert';

import 'boundary_topology.dart';
import 'project_aggregate.dart';
import 'project_identity.dart';
import 'semantic_sha256.dart';

/// P10 parent evidence in the existing generation registry. Canonical stores
/// remain the sole geometry/host authority; only field hashes are retained here.
final class CompositionGeneratedEntity {
  CompositionGeneratedEntity(
      {required this.id,
      required Map<String, String> baseline,
      Set<String> overrides = const {},
      this.removed = false})
      : baseline = Map.unmodifiable(baseline),
        overrides = Set.unmodifiable(overrides) {
    if (baseline.isEmpty ||
        baseline.values.any((v) => !_sha.hasMatch(v)) ||
        !baseline.keys.toSet().containsAll(overrides)) {
      throw ArgumentError('Invalid composition field evidence.');
    }
  }
  final EntityId id;
  final Map<String, String> baseline;
  final Set<String> overrides;
  final bool removed;
  CompositionGeneratedEntity reconcile(Map<String, Object?>? fields) {
    if (removed && fields != null) {
      throw StateError('p10.provenance.tombstone-reused');
    }
    return CompositionGeneratedEntity(
        id: id,
        baseline: baseline,
        removed: fields == null,
        overrides: {
          ...overrides,
          if (fields != null)
            for (final e in baseline.entries)
              if (compositionHash(fields[e.key]) != e.value) e.key
        });
  }

  Map<String, Object?> toJson() => {
        'id': compositionEntityIdJson(id),
        'baseline': {
          for (final k in baseline.keys.toList()..sort()) k: baseline[k]
        },
        'overrides': overrides.toList()..sort(),
        'removed': removed,
      };
}

final class CompositionGenerationManifest {
  CompositionGenerationManifest(
      {required this.id,
      required this.projectId,
      required this.siteId,
      required this.commandType,
      required this.canonicalEvidence,
      required Map<String, CompositionGeneratedEntity> entities,
      required Map<GenerationId, String> children})
      : entities = Map.unmodifiable(entities),
        children = Map.unmodifiable(children) {
    final evidence = compositionObject(jsonDecode(canonicalEvidence), {
      'generatorVersion',
      'request',
      'requestFingerprint',
      'candidateFingerprint',
      'templates'
    });
    if (evidence['generatorVersion'] is! String ||
        (evidence['generatorVersion'] as String).trim().isEmpty ||
        evidence['request'] is! String ||
        evidence['requestFingerprint'] !=
            semanticSha256Hex(evidence['request'] as String) ||
        !_sha.hasMatch(evidence['candidateFingerprint'] as String? ?? '') ||
        evidence['templates'] is! Map ||
        !commandType.startsWith('p10.') ||
        this.entities.values.map((e) => e.id).toSet().length !=
            this.entities.length ||
        this.entities.keys.any((k) => k.trim().isEmpty) ||
        this.children.values.any((v) => !_sha.hasMatch(v))) {
      throw ArgumentError('Invalid composition manifest.');
    }
    for (final raw in (evidence['templates'] as Map).values) {
      final t = compositionObject(
          raw, {'id', 'version', 'catalogVersion', 'fingerprint'});
      if (t['id'] is! String ||
          (t['id'] as String).trim().isEmpty ||
          t['version'] is! int ||
          (t['version'] as int) < 1 ||
          t['catalogVersion'] is! int ||
          (t['catalogVersion'] as int) < 1 ||
          !_sha.hasMatch(t['fingerprint'] as String? ?? '')) {
        throw ArgumentError('Invalid exact template binding.');
      }
    }
  }
  final GenerationId id;
  final ProjectId projectId;
  final SiteId siteId;
  final String commandType;
  final String canonicalEvidence;
  final Map<String, CompositionGeneratedEntity> entities;

  /// Existing P10.5 parent IDs (which retain the original P9 child manifests).
  final Map<GenerationId, String> children;
  CompositionGenerationManifest reconcile(ProjectAggregateRoot project) =>
      CompositionGenerationManifest(
          id: id,
          projectId: projectId,
          siteId: siteId,
          commandType: commandType,
          canonicalEvidence: canonicalEvidence,
          children: children,
          entities: {
            for (final e in entities.entries)
              e.key: e.value
                  .reconcile(compositionEntityFields(project, e.value.id))
          });
  String get immutableFingerprint => compositionHash({
        'projectId': projectId.value,
        'siteId': siteId.value,
        'commandType': commandType,
        'canonicalEvidence': canonicalEvidence,
        'entities': {
          for (final k in entities.keys.toList()..sort())
            k: {
              'id': compositionEntityIdJson(entities[k]!.id),
              'baseline': {
                for (final f in entities[k]!.baseline.keys.toList()..sort())
                  f: entities[k]!.baseline[f]
              }
            }
        },
        'children': {
          for (final k
              in children.keys.toList()
                ..sort((a, b) => a.value.compareTo(b.value)))
            k.value: children[k]
        }
      });
  Map<String, Object?> toJson() => {
        'immutableFingerprint': immutableFingerprint,
        'id': id.value,
        'projectId': projectId.value,
        'siteId': siteId.value,
        'commandType': commandType,
        'canonicalEvidence': canonicalEvidence,
        'entities': {
          for (final k in entities.keys.toList()..sort())
            k: entities[k]!.toJson()
        },
        'children': {
          for (final k
              in children.keys.toList()
                ..sort((a, b) => a.value.compareTo(b.value)))
            k.value: children[k]
        },
      };
  bool sameAs(CompositionGenerationManifest other) =>
      jsonEncode(toJson()) == jsonEncode(other.toJson());
}

abstract final class CompositionProvenanceIntegrity {
  static void validate(ProjectAggregateRoot project) {
    final registry = project.engineeringMetadata.generationProvenanceRegistry;
    final owned = <EntityId>{};
    final children = <GenerationId>{};
    for (final e in registry.compositions.entries) {
      final m = e.value;
      if (e.key != m.id ||
          m.projectId != project.id ||
          m.siteId != project.siteId ||
          registry.manifests.containsKey(m.id) ||
          registry.levelCompositions.containsKey(m.id)) {
        _fail();
      }
      for (final child in m.children.entries) {
        final floor = registry.levelCompositions[child.key];
        if (!children.add(child.key) ||
            floor == null ||
            floor.candidateFingerprint != child.value ||
            !m.entities.values.map((e) => e.id).toSet().containsAll([
              for (final apartment in floor.apartments.values)
                ...?registry
                    .manifests[apartment.generationId]?.generatedEntityIds
            ])) {
          _fail();
        }
      }
      for (final entity in m.entities.values) {
        if (!owned.add(entity.id)) _fail();
        final fields = compositionEntityFields(project, entity.id);
        if (entity.removed != (fields == null)) _fail();
        if (fields != null) {
          if (fields.length != entity.baseline.length ||
              !fields.keys.toSet().containsAll(entity.baseline.keys)) {
            _fail();
          }
          for (final f in fields.entries) {
            if (compositionHash(f.value) != entity.baseline[f.key] &&
                !entity.overrides.contains(f.key)) {
              _fail();
            }
          }
        }
      }
    }
  }

  static Never _fail() => throw StateError('p10.provenance.invalid-lineage');
}

final _sha = RegExp(r'^[0-9a-f]{64}$');
String compositionHash(Object? value) => semanticSha256Hex(jsonEncode(value));
List<String> _ids(Iterable<EntityId> ids) =>
    ids.map((id) => id.value).toList()..sort();
List<Object?> _points(Iterable<BoundaryPointMm> points) => [
      for (final p in points) [p.xMm, p.yMm]
    ];
Map<String, Object?>? compositionEntityFields(
    ProjectAggregateRoot p, EntityId id) {
  final s = p.stores;
  if (id is BuildingId) {
    final e = s.buildings[id];
    if (e == null) return null;
    return {
      'name': e.name,
      'siteId': e.siteId.value,
      'displayOrder': e.displayOrder,
      'levels': _ids(e.levelIds),
      'placement':
          p.engineeringMetadata.siteLayout.placements[id]?.toCanonicalJson()
    };
  }
  if (id is LevelId) {
    final e = s.levels[id];
    if (e == null) return null;
    return {
      'name': e.name,
      'buildingId': e.buildingId.value,
      'levelNumber': e.levelNumber,
      'kind': e.kind.name,
      'elevationMm': e.elevationMm,
      'heightMm': e.floorToFloorHeightMm,
      'order': e.displayOrder,
      'zones': _ids(e.zoneIds),
      'spaces': _ids(e.spaceIds)
    };
  }
  if (id is ZoneId) {
    final e = s.zones[id];
    if (e == null) return null;
    return {
      'name': e.name,
      'levelId': e.levelId.value,
      'kind': e.kind.name,
      'spaces': _ids(e.spaceIds)
    };
  }
  if (id is SpaceId) {
    final e = s.spaces[id];
    if (e == null) return null;
    return {
      'name': e.name,
      'levelId': e.levelId.value,
      'type': e.type.name,
      'usage': e.usage.name
    };
  }
  if (id is BoundaryEdgeId) {
    final e = p.index.boundaryEdges[id];
    if (e == null) return null;
    return {
      'spaceId': e.spaceId.value,
      'start': [e.start.xMm, e.start.yMm],
      'end': [e.end.xMm, e.end.yMm]
    };
  }
  if (id is OpeningId) {
    final e = s.openings[id];
    if (e == null) return null;
    return {
      'levelId': e.levelId.value,
      'kind': e.kind.name,
      'spaces': _ids(e.connectedSpaceIds),
      'widthMm': e.widthMm,
      'heightMm': e.heightMm,
      'baseElevationMm': e.baseElevationMm
    };
  }
  if (id is SpaceAdjacencyId) {
    final e = s.adjacencies[id];
    if (e == null) return null;
    return {
      'spaces': _ids(e.spaceIds),
      'kind': e.kind.name,
      'openingId': e.openingId?.value
    };
  }
  if (id is SlabId) {
    final e = s.slabs[id];
    if (e == null) return null;
    return {
      'buildingId': e.buildingId.value,
      'kind': e.kind.name,
      'below': e.belowLevelId?.value,
      'above': e.aboveLevelId?.value,
      'bottomElevationMm': e.bottomElevationMm,
      'thicknessMm': e.thicknessMm,
      'materialId': e.materialId,
      'footprint': _points(e.footprint)
    };
  }
  if (id is VerticalCoreId) {
    final e = s.verticalCores[id];
    if (e == null) return null;
    return {
      'buildingId': e.buildingId.value,
      'name': e.name,
      'kind': e.kind.name,
      'usage': e.usage.name,
      'levels': _ids(e.levelIds),
      'footprint': _points(e.footprint),
      'hosts': {
        for (final k
            in e.hostSpaceIdsByLevel.keys.toList()
              ..sort((a, b) => a.value.compareTo(b.value)))
          k.value: e.hostSpaceIdsByLevel[k]!.value
      }
    };
  }
  if (id is ServiceEntryId) {
    final layout = p.engineeringMetadata.siteLayout;
    final a = layout.serviceAnchors[id];
    final shared = layout.sharedAnchors[id];
    if (a == null && shared == null) return null;
    final host =
        p.engineeringMetadata.boundaryHostedObjectRegistry.serviceEntryHost(id);
    return {
      ...(a?.toCanonicalJson() ?? shared!.toCanonicalJson()),
      'wallBinding': host == null
          ? null
          : {
              'spaceId': host.host.spaceId.value,
              'edgeId': host.host.edgeId.value,
              'offsetMm': host.startOffsetMm
            }
    };
  }
  if (id is TypicalFloorDefinitionId) {
    return p.engineeringMetadata.generationProvenanceRegistry
        .typicalFloorDefinitions[id]
        ?.toCanonicalJson();
  }
  return null;
}

Map<String, Object?> compositionEntityIdJson(EntityId id) => {
      'kind': switch (id) {
        BuildingId() => 'building',
        LevelId() => 'level',
        ZoneId() => 'zone',
        SpaceId() => 'space',
        BoundaryEdgeId() => 'boundaryEdge',
        OpeningId() => 'opening',
        SpaceAdjacencyId() => 'adjacency',
        SlabId() => 'slab',
        VerticalCoreId() => 'verticalCore',
        ServiceEntryId() => 'serviceEntry',
        TypicalFloorDefinitionId() => 'typicalFloorDefinition',
        _ => throw ArgumentError('Unsupported composition identity')
      },
      'value': id.value
    };
EntityId compositionEntityIdFromJson(Object? raw) {
  final j = compositionObject(raw, {'kind', 'value'});
  final v = j['value'];
  if (v is! String || v.trim().isEmpty) {
    throw const FormatException('Invalid identity');
  }
  return switch (j['kind']) {
    'building' => BuildingId(v),
    'level' => LevelId(v),
    'zone' => ZoneId(v),
    'space' => SpaceId(v),
    'boundaryEdge' => BoundaryEdgeId(v),
    'opening' => OpeningId(v),
    'adjacency' => SpaceAdjacencyId(v),
    'slab' => SlabId(v),
    'verticalCore' => VerticalCoreId(v),
    'serviceEntry' => ServiceEntryId(v),
    'typicalFloorDefinition' => TypicalFloorDefinitionId(v),
    _ => throw const FormatException('Unsupported identity kind')
  };
}

Map<String, Object?> compositionObject(Object? raw, Set<String> keys) {
  if (raw is! Map ||
      raw.keys.any((k) => k is! String) ||
      raw.length != keys.length ||
      !keys.containsAll(raw.keys)) {
    throw const FormatException(
        'Unknown or missing composition provenance fields');
  }
  return Map<String, Object?>.from(raw);
}
