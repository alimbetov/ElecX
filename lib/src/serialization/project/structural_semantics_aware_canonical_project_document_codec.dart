import '../../application/project/project_snapshot.dart';
import '../../domain/project_aggregate.dart';
import '../../domain/project_identity.dart';
import 'project_document_codec.dart';
import 'vertical_core_aware_canonical_project_document_codec.dart';

/// Schema-v11 additive persistence for P4 structural semantics.
///
/// The lower codec chain owns:
///
/// - v8: Level.kind + Level.floorToFloorHeightMm;
/// - v9: SlabId topology;
/// - v10: VerticalCore topology.
///
/// This layer therefore owns only the structural semantics still absent below:
///
/// - StructuralZone.kind;
/// - Space.type.
///
/// A short-lived development build emitted these fields as schema v10 before
/// the underlying slab/VerticalCore schema-number collision was repaired. Such
/// documents remain readable: v10 is treated as historical P4 structural data
/// only when the additive zone/space fields are actually present. New writes
/// are always schema v11.
final class StructuralSemanticsAwareCanonicalProjectDocumentCodec
    implements ProjectDocumentCodec {
  const StructuralSemanticsAwareCanonicalProjectDocumentCodec();

  static const int schemaVersion = 11;
  static const int _verticalCoreSchemaVersion = 10;

  static const VerticalCoreAwareCanonicalProjectDocumentCodec _vertical =
      VerticalCoreAwareCanonicalProjectDocumentCodec();

  @override
  int get currentSchemaVersion => schemaVersion;

  @override
  ProjectDocument encode(ProjectSnapshot snapshot) {
    final vertical = _vertical.encode(snapshot);
    final stores = snapshot.aggregate.stores;

    return ProjectDocument(
      schemaVersion: schemaVersion,
      payload: <String, Object?>{
        ...vertical.payload,
        'zones': _augmentEntities(
          vertical.payload['zones'],
          'zones',
          (json) {
            final id = ZoneId(_string(json['id'], 'zone.id'));
            final zone = stores.zones[id];
            if (zone == null) {
              throw StateError(
                'Persisted zone payload references missing $id.',
              );
            }
            return <String, Object?>{...json, 'kind': zone.kind.name};
          },
        ),
        'spaces': _augmentEntities(
          vertical.payload['spaces'],
          'spaces',
          (json) {
            final id = SpaceId(_string(json['id'], 'space.id'));
            final space = stores.spaces[id];
            if (space == null) {
              throw StateError(
                'Persisted space payload references missing $id.',
              );
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

    if (document.schemaVersion < _verticalCoreSchemaVersion) {
      return _vertical.decode(document);
    }

    if (document.schemaVersion == _verticalCoreSchemaVersion &&
        !_containsHistoricalStructuralSemantics(document.payload)) {
      return _vertical.decode(document);
    }

    final zoneKinds = _decodeZoneKinds(document.payload['zones']);
    final spaceTypes = _decodeSpaceTypes(document.payload['spaces']);
    final verticalSnapshot = _vertical.decode(
      ProjectDocument(
        schemaVersion: _verticalCoreSchemaVersion,
        payload: document.payload,
      ),
    );
    final stores = verticalSnapshot.aggregate.stores;

    _requireExactKeys('zones', stores.zones.keys, zoneKinds.keys);
    _requireExactKeys('spaces', stores.spaces.keys, spaceTypes.keys);

    try {
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
        id: verticalSnapshot.id,
        siteId: verticalSnapshot.siteId,
        version: verticalSnapshot.localVersion,
        engineeringMetadata: verticalSnapshot.aggregate.engineeringMetadata,
        stores: ProjectEntityStores(
          sites: stores.sites,
          buildings: stores.buildings,
          levels: stores.levels,
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
      return verticalSnapshot.copyWith(aggregate: aggregate);
    } on ProjectAggregateValidationException catch (error) {
      throw FormatException('Invalid canonical P4 structural graph: $error');
    } on ArgumentError catch (error) {
      throw FormatException('Invalid canonical P4 structural value: $error');
    }
  }

  static bool _containsHistoricalStructuralSemantics(
    Map<String, Object?> payload,
  ) {
    final zones = _list(payload['zones'], 'zones');
    final spaces = _list(payload['spaces'], 'spaces');
    return zones.any((raw) => _map(raw, 'zone').containsKey('kind')) ||
        spaces.any((raw) => _map(raw, 'space').containsKey('type'));
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

  static Map<ZoneId, ProjectStructuralZoneKind> _decodeZoneKinds(Object? value) {
    final result = <ZoneId, ProjectStructuralZoneKind>{};
    for (final raw in _list(value, 'zones')) {
      final json = _map(raw, 'zone');
      final id = ZoneId(_string(json['id'], 'zone.id'));
      if (result.containsKey(id)) {
        throw FormatException('Duplicate zone id $id in structural semantics.');
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
        throw FormatException('Duplicate space id $id in structural semantics.');
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

T _enumByName<T extends Enum>(List<T> values, Object? value, String field) {
  final raw = _string(value, field);
  for (final candidate in values) {
    if (candidate.name == raw) return candidate;
  }
  throw FormatException('$field contains unsupported value $raw.');
}
