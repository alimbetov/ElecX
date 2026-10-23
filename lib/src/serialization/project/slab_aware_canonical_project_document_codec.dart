import '../../application/project/project_snapshot.dart';
import '../../domain/boundary_topology.dart';
import '../../domain/project_aggregate.dart';
import '../../domain/project_identity.dart';
import '../../domain/slab_topology.dart';
import 'canonical_project_document_codec.dart';
import 'project_document_codec.dart';

/// Schema-v8 additive persistence layer for canonical physical slabs.
///
/// The proven v1-v7 codec remains authoritative for all pre-slab fields and
/// migrations. This decorator owns only the `slabs` payload introduced by v8,
/// which keeps the vertical-topology migration independent from the frozen P7A
/// wall persistence contract.
final class SlabAwareCanonicalProjectDocumentCodec
    implements ProjectDocumentCodec {
  const SlabAwareCanonicalProjectDocumentCodec();

  static const int schemaVersion = 8;
  static const int _legacySchemaVersion = 7;

  static const CanonicalProjectDocumentCodec _legacy =
      CanonicalProjectDocumentCodec();

  @override
  int get currentSchemaVersion => schemaVersion;

  @override
  ProjectDocument encode(ProjectSnapshot snapshot) {
    final legacy = _legacy.encode(snapshot);
    return ProjectDocument(
      schemaVersion: schemaVersion,
      payload: <String, Object?>{
        ...legacy.payload,
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

    if (document.schemaVersion <= _legacySchemaVersion) {
      return _legacy.decode(document);
    }

    final slabs = _decodeSlabs(document.payload['slabs']);
    final legacyPayload = Map<String, Object?>.of(document.payload)
      ..remove('slabs');
    final legacySnapshot = _legacy.decode(
      ProjectDocument(
        schemaVersion: _legacySchemaVersion,
        payload: legacyPayload,
      ),
    );
    final stores = legacySnapshot.aggregate.stores;

    try {
      final aggregate = ProjectAggregateRoot(
        id: legacySnapshot.id,
        siteId: legacySnapshot.siteId,
        version: legacySnapshot.localVersion,
        engineeringMetadata: legacySnapshot.aggregate.engineeringMetadata,
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
      return legacySnapshot.copyWith(aggregate: aggregate);
    } on ProjectAggregateValidationException catch (error) {
      throw FormatException('Invalid canonical slab graph: $error');
    } on ArgumentError catch (error) {
      throw FormatException('Invalid canonical slab value: $error');
    }
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
