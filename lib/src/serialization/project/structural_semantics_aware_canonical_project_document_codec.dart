import '../../application/project/project_snapshot.dart';
import '../../domain/project_aggregate.dart';
import '../../domain/project_identity.dart';
import 'project_document_codec.dart';
import 'vertical_core_aware_canonical_project_document_codec.dart';

/// Schema-v10 additive persistence for P4 structural semantics.
///
/// v9 remains authoritative for all existing hierarchy, P6/P7A semantics,
/// SlabId and VerticalCore payloads. v10 adds only attributes that were
/// previously absent from canonical persistence:
///
/// - Level.kind
/// - Level.floorToFloorHeightMm
/// - StructuralZone.kind
/// - Space.type
///
/// Documents from v1..v9 migrate deterministically to `unknown` structural
/// classifications and the historical 3000 mm floor-to-floor default. No
/// semantic classification is guessed from labels or SpaceUsage.
final class StructuralSemanticsAwareCanonicalProjectDocumentCodec
    implements ProjectDocumentCodec {
  const StructuralSemanticsAwareCanonicalProjectDocumentCodec();

  static const int schemaVersion = 10;
  static const int _legacySchemaVersion = 9;

  static const VerticalCoreAwareCanonicalProjectDocumentCodec _legacy =
      VerticalCoreAwareCanonicalProjectDocumentCodec();

  @override
  int get currentSchemaVersion => schemaVersion;

  @override
  ProjectDocument encode(ProjectSnapshot snapshot) {
    final legacy = _legacy.encode(snapshot);
    final stores = snapshot.aggregate.stores;

    return ProjectDocument(
      schemaVersion: schemaVersion,
      payload: <String, Object?>{
        ...legacy.payload,
        'levels': _augmentEntities(
          legacy.payload['levels'],
          'levels',
          (json) {
            final id = LevelId(_string(json['id'], 'level.id'));
            final level = stores.levels[id];
            if (level == null) {
              throw StateError('Persisted level payload references missing $id.');
            }
            return <String, Object?>{
              ...json,
              'kind': level.kind.name,
              'floorToFloorHeightMm': level.floorToFloorHeightMm,
            };
          },
        ),
        'zones': _augmentEntities(
          legacy.payload['zones'],
          'zones',
          (json) {
            final id = ZoneId(_string(json['id'], 'zone.id'));
            final zone = stores.zones[id];
            if (zone == null) {
              throw StateError('Persisted zone payload references missing $id.');
            }
            return <String, Object?>{...json, 'kind': zone.kind.name};
          },
        ),
        'spaces': _augmentEntities(
          legacy.payload['spaces'],
          'spaces',
          (json) {
            final id = SpaceId(_string(json['id'], 'space.id'));
            final space = stores.spaces[id];
            if (space == null) {
              throw StateError('Persisted space payload references missing $id.');
            }
            return <String, Object?>{...json, 'type': space.type.name};
          },
        ),
      },
    );
  }

  @override
  ProjectSnapshot decode(ProjectDocument document) {
    if (document.schemaVersion < 1 || document.schemaVersion > schemaVersion) {
      throw FormatException(
        'Unsupported canonical ElecX project schema '
        '${document.schemaVersion}; supported versions are 1..$schemaVersion.',
      );
    }

    if (document.schemaVersion <= _legacySchemaVersion) {
      return _legacy.decode(document);
    }

    final levelSemantics = _decodeLevelSemantics(document.payload['levels']);
    final zoneKinds = _decodeZoneKinds(document.payload['zones']);
    final spaceTypes = _decodeSpaceTypes(document.payload['spaces']);

    final legacySnapshot = _legacy.decode(
      ProjectDocument(
        schemaVersion: _legacySchemaVersion,
        payload: document.payload,
      ),
    );
    final stores = legacySnapshot.aggregate.stores;

    _requireExactKeys('levels', stores.levels.keys, levelSemantics.keys);
    _requireExactKeys('zones', stores.zones.keys, zoneKinds.keys);
    _requireExactKeys('spaces', stores.spaces.keys, spaceTypes.keys);

    try {
      final levels = <LevelId, ProjectLevelEntity>{
        for (final entry in stores.levels.entries)
          entry.key: ProjectLevelEntity(
            id: entry.value.id,
            buildingId: entry.value.buildingId,
            name: entry.value.name,
            levelNumber: entry.value.levelNumber,
            displayOrder: entry.value.displayOrder,
            elevationMm: entry.value.elevationMm,
            kind: levelSemantics[entry.key]!.kind,
            floorToFloorHeightMm:
                levelSemantics[entry.key]!.floorToFloorHeightMm,
            zoneIds: entry.value.zoneIds,
            spaceIds: entry.value.spaceIds,
          ),
      };
      final zones = <ZoneId, ProjectStructuralZoneEntity>{
        for (final entry in stores.zones.entries)
          entry.key: ProjectStructuralZoneEntity(
            id: entry.value.id,
            levelId: entry.value.levelId,
            name: entry.value.name,
            kind: zoneKinds[entry.key]!,
            spaceIds: entry.value.spaceIds,
          ),
      };
      final spaces = <SpaceId, ProjectSpaceEntity>{
        for (final entry in stores.spaces.entries)
          entry.key: ProjectSpaceEntity(
            id: entry.value.id,
            levelId: entry.value.levelId,
            name: entry.value.name,
            type: spaceTypes[entry.key]!,
            usage: entry.value.usage,
          ),
      };

      final aggregate = ProjectAggregateRoot(
        id: legacySnapshot.id,
        siteId: legacySnapshot.siteId,
        version: legacySnapshot.localVersion,
        engineeringMetadata: legacySnapshot.aggregate.engineeringMetadata,
        stores: ProjectEntityStores(
          sites: stores.sites,
          buildings: stores.buildings,
          levels: levels,
          slabs: stores.slabs,
          verticalCores: stores.verticalCores,
          zones: zones,
          spaces: spaces,
          openings: stores.openings,
          adjacencies: stores.adjacencies,
          overlays: stores.overlays,
          boundaries: stores.boundaries,
        ),
      );
      return legacySnapshot.copyWith(aggregate: aggregate);
    } on ProjectAggregateValidationException catch (error) {
      throw FormatException('Invalid canonical P4 structural graph: $error');
    } on ArgumentError catch (error) {
      throw FormatException('Invalid canonical P4 structural value: $error');
    }
  }

  static List<Object?> _augmentEntities(
    Object? value,
    String field,
    Map<String, Object?> Function(Map<String, Object?> json) transform,
  ) {
    final source = _list(value, field);
    return <Object?>[
      for (final raw in source) transform(_map(raw, '$field[]')),
    ];
  }

  static Map<LevelId, _LevelSemantics> _decodeLevelSemantics(Object? value) {
    final result = <LevelId, _LevelSemantics>{};
    for (final raw in _list(value, 'levels')) {
      final json = _map(raw, 'level');
      final id = LevelId(_string(json['id'], 'level.id'));
      if (result.containsKey(id)) {
        throw FormatException('Duplicate level id $id in v10 semantics.');
      }
      result[id] = _LevelSemantics(
        kind: _enumByName(
          ProjectLevelKind.values,
          json['kind'],
          'level.kind',
        ),
        floorToFloorHeightMm: _positiveInt(
          json['floorToFloorHeightMm'],
          'level.floorToFloorHeightMm',
        ),
      );
    }
    return Map.unmodifiable(result);
  }

  static Map<ZoneId, ProjectStructuralZoneKind> _decodeZoneKinds(Object? value) {
    final result = <ZoneId, ProjectStructuralZoneKind>{};
    for (final raw in _list(value, 'zones')) {
      final json = _map(raw, 'zone');
      final id = ZoneId(_string(json['id'], 'zone.id'));
      if (result.containsKey(id)) {
        throw FormatException('Duplicate zone id $id in v10 semantics.');
      }
      result[id] = _enumByName(
        ProjectStructuralZoneKind.values,
        json['kind'],
        'zone.kind',
      );
    }
    return Map.unmodifiable(result);
  }

  static Map<SpaceId, ProjectSpaceType> _decodeSpaceTypes(Object? value) {
    final result = <SpaceId, ProjectSpaceType>{};
    for (final raw in _list(value, 'spaces')) {
      final json = _map(raw, 'space');
      final id = SpaceId(_string(json['id'], 'space.id'));
      if (result.containsKey(id)) {
        throw FormatException('Duplicate space id $id in v10 semantics.');
      }
      result[id] = _enumByName(
        ProjectSpaceType.values,
        json['type'],
        'space.type',
      );
    }
    return Map.unmodifiable(result);
  }

  static void _requireExactKeys<T extends EntityId>(
    String field,
    Iterable<T> canonical,
    Iterable<T> semantic,
  ) {
    final left = canonical.toSet();
    final right = semantic.toSet();
    if (left.length != right.length || !left.containsAll(right)) {
      throw FormatException(
        '$field structural-semantics payload does not match canonical IDs.',
      );
    }
  }
}

final class _LevelSemantics {
  const _LevelSemantics({
    required this.kind,
    required this.floorToFloorHeightMm,
  });

  final ProjectLevelKind kind;
  final int floorToFloorHeightMm;
}

Map<String, Object?> _map(Object? value, String field) {
  if (value is! Map) {
    throw FormatException('$field must be an object.');
  }
  return value.map((key, item) => MapEntry(key.toString(), item));
}

List<Object?> _list(Object? value, String field) {
  if (value is! List) {
    throw FormatException('$field must be an array.');
  }
  return value.cast<Object?>();
}

String _string(Object? value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$field must be a non-empty string.');
  }
  return value;
}

int _positiveInt(Object? value, String field) {
  if (value is! int || value <= 0) {
    throw FormatException('$field must be a positive integer.');
  }
  return value;
}

T _enumByName<T extends Enum>(List<T> values, Object? value, String field) {
  final raw = _string(value, field);
  for (final candidate in values) {
    if (candidate.name == raw) return candidate;
  }
  throw FormatException('$field contains unsupported value $raw.');
}
