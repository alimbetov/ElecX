import '../../application/project/project_snapshot.dart';
import '../../domain/boundary_topology.dart';
import '../../domain/project_aggregate.dart';
import '../../domain/project_identity.dart';
import '../../domain/vertical_core.dart';
import 'project_document_codec.dart';
import 'slab_aware_canonical_project_document_codec.dart';

/// Schema-v10 additive persistence layer for canonical VerticalCore entities.
///
/// New slab documents use schema v9. Historical development builds also
/// emitted VerticalCore documents as v9 on top of the legacy slab-v8 shape.
/// Decode therefore accepts both v9 meanings and distinguishes the historical
/// VerticalCore shape by the additive `verticalCores` field. New documents are
/// always emitted as v10 so schema numbers are unambiguous going forward.
final class VerticalCoreAwareCanonicalProjectDocumentCodec
    implements ProjectDocumentCodec {
  const VerticalCoreAwareCanonicalProjectDocumentCodec();

  static const int schemaVersion = 10;
  static const int _slabSchemaVersion = 9;
  static const int _legacyVerticalCoreSchemaVersion = 9;
  static const int _legacySlabSchemaVersion = 8;

  static const SlabAwareCanonicalProjectDocumentCodec _slabs =
      SlabAwareCanonicalProjectDocumentCodec();

  @override
  int get currentSchemaVersion => schemaVersion;

  @override
  ProjectDocument encode(ProjectSnapshot snapshot) {
    final slabDocument = _slabs.encode(snapshot);
    return ProjectDocument(
      schemaVersion: schemaVersion,
      payload: <String, Object?>{
        ...slabDocument.payload,
        'verticalCores': _encodeVerticalCores(
          snapshot.aggregate.stores.verticalCores,
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

    if (document.schemaVersion < _legacyVerticalCoreSchemaVersion) {
      return _slabs.decode(document);
    }

    if (document.schemaVersion == _legacyVerticalCoreSchemaVersion &&
        !document.payload.containsKey('verticalCores')) {
      // New unambiguous slab-v9 document.
      return _slabs.decode(document);
    }

    final verticalCores =
        _decodeVerticalCores(document.payload['verticalCores']);
    final slabPayload = Map<String, Object?>.of(document.payload)
      ..remove('verticalCores');
    final slabVersion =
        document.schemaVersion == _legacyVerticalCoreSchemaVersion
            ? _legacySlabSchemaVersion
            : _slabSchemaVersion;
    final slabSnapshot = _slabs.decode(
      ProjectDocument(
        schemaVersion: slabVersion,
        payload: slabPayload,
      ),
    );
    final stores = slabSnapshot.aggregate.stores;

    try {
      final aggregate = ProjectAggregateRoot(
        id: slabSnapshot.id,
        siteId: slabSnapshot.siteId,
        version: slabSnapshot.localVersion,
        engineeringMetadata: slabSnapshot.aggregate.engineeringMetadata,
        stores: ProjectEntityStores(
          sites: stores.sites,
          buildings: stores.buildings,
          levels: stores.levels,
          slabs: stores.slabs,
          verticalCores: verticalCores,
          zones: stores.zones,
          spaces: stores.spaces,
          openings: stores.openings,
          adjacencies: stores.adjacencies,
          overlays: stores.overlays,
          boundaries: stores.boundaries,
        ),
      );
      return slabSnapshot.copyWith(aggregate: aggregate);
    } on ProjectAggregateValidationException catch (error) {
      throw FormatException('Invalid canonical VerticalCore graph: $error');
    } on ArgumentError catch (error) {
      throw FormatException('Invalid canonical VerticalCore value: $error');
    }
  }

  static List<Object?> _encodeVerticalCores(
    Map<VerticalCoreId, ProjectVerticalCore> verticalCores,
  ) {
    final values = verticalCores.values.toList()
      ..sort((a, b) => a.id.value.compareTo(b.id.value));
    return <Object?>[
      for (final core in values)
        <String, Object?>{
          'id': core.id.value,
          'buildingId': core.buildingId.value,
          'kind': core.kind.name,
          'name': core.name,
          'levelIds': <Object?>[
            for (final id
                in (core.levelIds.toList()
                  ..sort((a, b) => a.value.compareTo(b.value))))
              id.value,
          ],
          'footprint': <Object?>[
            for (final point in core.footprint)
              <String, Object?>{'xMm': point.xMm, 'yMm': point.yMm},
          ],
        },
    ];
  }

  static Map<VerticalCoreId, ProjectVerticalCore> _decodeVerticalCores(
    Object? value,
  ) {
    if (value is! List) {
      throw const FormatException('verticalCores must be an array.');
    }
    final verticalCores = <VerticalCoreId, ProjectVerticalCore>{};
    for (final raw in value) {
      final json = _map(raw, 'verticalCore');
      final id = VerticalCoreId(_string(json['id'], 'verticalCore.id'));
      if (verticalCores.containsKey(id)) {
        throw FormatException('Duplicate vertical core id $id.');
      }
      final levelIds = <LevelId>{
        for (final rawLevelId
            in _list(json['levelIds'], 'verticalCore.levelIds'))
          LevelId(_string(rawLevelId, 'verticalCore.levelIds[]')),
      };
      final footprint = <BoundaryPointMm>[
        for (final rawPoint
            in _list(json['footprint'], 'verticalCore.footprint'))
          () {
            final point = _map(rawPoint, 'verticalCore.footprint.point');
            return BoundaryPointMm(
              xMm: _int(point['xMm'], 'verticalCore.footprint.point.xMm'),
              yMm: _int(point['yMm'], 'verticalCore.footprint.point.yMm'),
            );
          }(),
      ];

      try {
        verticalCores[id] = ProjectVerticalCore(
          id: id,
          buildingId: BuildingId(
            _string(json['buildingId'], 'verticalCore.buildingId'),
          ),
          kind: _enumByName(
            VerticalCoreKind.values,
            json['kind'],
            'verticalCore.kind',
          ),
          levelIds: levelIds,
          footprint: footprint,
          name: _nullableString(json['name'], 'verticalCore.name'),
        );
      } on ArgumentError catch (error) {
        throw FormatException('Invalid vertical core $id: $error');
      }
    }
    return Map<VerticalCoreId, ProjectVerticalCore>.unmodifiable(verticalCores);
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
