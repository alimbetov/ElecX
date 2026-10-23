import '../../application/project/project_snapshot.dart';
import '../../domain/boundary_topology.dart';
import '../../domain/project_aggregate.dart';
import '../../domain/project_identity.dart';
import '../../domain/slab_topology.dart';
import 'canonical_project_document_codec.dart';
import 'project_document_codec.dart';

/// Schema-v9 additive persistence layer for canonical physical slabs.
///
/// Schema history compatibility is intentionally asymmetric because an earlier
/// development revision assigned schema 8 to slabs before the base canonical
/// codec later assigned schema 8 to Level kind/floor-to-floor semantics.
/// Consequently v8 has historical shapes both with and without persisted Level
/// semantics. Decode distinguishes them from the additive `slabs` field and,
/// for slab-v8, from the Level semantic fields themselves. New slab documents
/// always encode as v9, restoring one unambiguous meaning per schema number.
final class SlabAwareCanonicalProjectDocumentCodec
    implements ProjectDocumentCodec {
  const SlabAwareCanonicalProjectDocumentCodec();

  static const int schemaVersion = 9;
  static const int _baseSchemaVersion = 8;
  static const int _legacySlabSchemaVersion = 8;
  static const int _preLevelSemanticsSchemaVersion = 7;

  static const CanonicalProjectDocumentCodec _base =
      CanonicalProjectDocumentCodec();

  @override
  int get currentSchemaVersion => schemaVersion;

  @override
  ProjectDocument encode(ProjectSnapshot snapshot) {
    final base = _base.encode(snapshot);
    return ProjectDocument(
      schemaVersion: schemaVersion,
      payload: <String, Object?>{
        ...base.payload,
        'slabs': _encodeSlabs(snapshot.aggregate.stores.slabs),
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

    if (document.schemaVersion < _legacySlabSchemaVersion) {
      return _base.decode(document);
    }

    if (document.schemaVersion == _legacySlabSchemaVersion &&
        !document.payload.containsKey('slabs')) {
      // Unambiguous base-v8 document introduced for Level semantics.
      return _base.decode(document);
    }

    final slabs = _decodeSlabs(document.payload['slabs']);
    final basePayload = Map<String, Object?>.of(document.payload)
      ..remove('slabs');
    final baseVersion = document.schemaVersion == _legacySlabSchemaVersion &&
            !_hasPersistedLevelSemantics(basePayload['levels'])
        ? _preLevelSemanticsSchemaVersion
        : _baseSchemaVersion;
    final baseSnapshot = _base.decode(
      ProjectDocument(
        schemaVersion: baseVersion,
        payload: basePayload,
      ),
    );
    final stores = baseSnapshot.aggregate.stores;

    try {
      final aggregate = ProjectAggregateRoot(
        id: baseSnapshot.id,
        siteId: baseSnapshot.siteId,
        version: baseSnapshot.localVersion,
        engineeringMetadata: baseSnapshot.aggregate.engineeringMetadata,
        stores: ProjectEntityStores(
          sites: stores.sites,
          buildings: stores.buildings,
          levels: stores.levels,
          slabs: slabs,
          zones: stores.zones,
          spaces: stores.spaces,
          openings: stores.openings,
          adjacencies: stores.adjacencies,
          overlays: stores.overlays,
          boundaries: stores.boundaries,
        ),
      );
      return baseSnapshot.copyWith(aggregate: aggregate);
    } on ProjectAggregateValidationException catch (error) {
      throw FormatException('Invalid canonical slab graph: $error');
    } on ArgumentError catch (error) {
      throw FormatException('Invalid canonical slab value: $error');
    }
  }

  static bool _hasPersistedLevelSemantics(Object? value) {
    if (value is! List) return false;
    for (final raw in value) {
      if (raw is! Map) return false;
      if (!raw.containsKey('kind') ||
          !raw.containsKey('floorToFloorHeightMm')) {
        return false;
      }
    }
    return true;
  }

  static List<Object?> _encodeSlabs(Map<SlabId, ProjectSlab> slabs) {
    final values = slabs.values.toList()
      ..sort((a, b) => a.id.value.compareTo(b.id.value));
    return <Object?>[
      for (final slab in values)
        <String, Object?>{
          'id': slab.id.value,
          'buildingId': slab.buildingId.value,
          'kind': slab.kind.name,
          'belowLevelId': slab.belowLevelId?.value,
          'aboveLevelId': slab.aboveLevelId?.value,
          'bottomElevationMm': slab.bottomElevationMm,
          'thicknessMm': slab.thicknessMm,
          'materialId': slab.materialId,
          'footprint': <Object?>[
            for (final point in slab.footprint)
              <String, Object?>{'xMm': point.xMm, 'yMm': point.yMm},
          ],
        },
    ];
  }

  static Map<SlabId, ProjectSlab> _decodeSlabs(Object? value) {
    if (value is! List) {
      throw const FormatException('slabs must be an array.');
    }
    final slabs = <SlabId, ProjectSlab>{};
    for (final raw in value) {
      final json = _map(raw, 'slab');
      final id = SlabId(_string(json['id'], 'slab.id'));
      if (slabs.containsKey(id)) {
        throw FormatException('Duplicate slab id $id.');
      }
      final belowLevelId = _nullableString(
        json['belowLevelId'],
        'slab.belowLevelId',
      );
      final aboveLevelId = _nullableString(
        json['aboveLevelId'],
        'slab.aboveLevelId',
      );
      final footprint = <BoundaryPointMm>[
        for (final rawPoint in _list(json['footprint'], 'slab.footprint'))
          () {
            final point = _map(rawPoint, 'slab.footprint.point');
            return BoundaryPointMm(
              xMm: _int(point['xMm'], 'slab.footprint.point.xMm'),
              yMm: _int(point['yMm'], 'slab.footprint.point.yMm'),
            );
          }(),
      ];

      try {
        slabs[id] = ProjectSlab(
          id: id,
          buildingId: BuildingId(
            _string(json['buildingId'], 'slab.buildingId'),
          ),
          kind: _enumByName(SlabKind.values, json['kind'], 'slab.kind'),
          belowLevelId: belowLevelId == null ? null : LevelId(belowLevelId),
          aboveLevelId: aboveLevelId == null ? null : LevelId(aboveLevelId),
          bottomElevationMm: _int(
            json['bottomElevationMm'],
            'slab.bottomElevationMm',
          ),
          thicknessMm: _int(json['thicknessMm'], 'slab.thicknessMm'),
          materialId: _string(json['materialId'], 'slab.materialId'),
          footprint: footprint,
        );
      } on ArgumentError catch (error) {
        throw FormatException('Invalid slab $id: $error');
      }
    }
    return Map<SlabId, ProjectSlab>.unmodifiable(slabs);
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

String? _nullableString(Object? value, String field) {
  if (value == null) return null;
  return _string(value, field);
}

int _int(Object? value, String field) {
  if (value is! int) {
    throw FormatException('$field must be an integer.');
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
