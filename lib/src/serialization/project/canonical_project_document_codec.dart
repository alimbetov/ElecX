import '../../application/project/project_snapshot.dart';
import '../../domain/project_aggregate.dart';
import '../../domain/project_identity.dart';
import '../../domain/project_orientation.dart';
import '../../domain/project_space_semantics.dart';
import 'project_document_codec.dart';

/// Canonical multi-building persistence codec.
///
/// Schema history:
/// - v1: structural multi-building aggregate;
/// - v2: canonical project engineering orientation;
/// - v3: P6 SpaceUsage, openings, adjacency and overlay classifications.
///
/// P6 intentionally persists no wall index or durable wall host. Exact opening
/// hosting belongs to P7 BoundaryEdgeId/edge-lineage migration.
final class CanonicalProjectDocumentCodec implements ProjectDocumentCodec {
  const CanonicalProjectDocumentCodec();

  static const int schemaVersion = 3;
  static const int _schemaV1 = 1;
  static const int _schemaV2 = 2;

  @override
  int get currentSchemaVersion => schemaVersion;

  @override
  ProjectDocument encode(ProjectSnapshot snapshot) {
    final stores = snapshot.aggregate.stores;
    return ProjectDocument(
      schemaVersion: schemaVersion,
      payload: <String, Object?>{
        'metadata': <String, Object?>{
          'projectId': snapshot.id.value,
          'siteId': snapshot.siteId.value,
          'name': snapshot.name,
          'createdAt': snapshot.createdAt.toUtc().toIso8601String(),
          'updatedAt': snapshot.updatedAt.toUtc().toIso8601String(),
          'localVersion': snapshot.localVersion.value,
        },
        'projectOrientation': <String, Object?>{
          'projectNorthMilliDegrees': snapshot.aggregate.engineeringMetadata
              .projectNorth?.milliDegreesClockwiseFromPositiveY,
        },
        'sites': _encodeSites(stores),
        'buildings': _encodeBuildings(stores),
        'levels': _encodeLevels(stores),
        'zones': _encodeZones(stores),
        'spaces': _encodeSpaces(stores),
        'openings': _encodeOpenings(stores),
        'adjacencies': _encodeAdjacencies(stores),
        'overlays': _encodeOverlays(stores),
      },
    );
  }

  @override
  ProjectSnapshot decode(ProjectDocument document) {
    final migrated = _migrateToCurrent(document);

    try {
      final metadata = _map(migrated.payload['metadata'], 'metadata');
      final orientation = _map(
        migrated.payload['projectOrientation'],
        'projectOrientation',
      );
      final projectId = ProjectId(_string(metadata['projectId'], 'projectId'));
      final siteId = SiteId(_string(metadata['siteId'], 'siteId'));
      final name = _string(metadata['name'], 'name');
      final createdAt = _dateTime(metadata['createdAt'], 'createdAt');
      final updatedAt = _dateTime(metadata['updatedAt'], 'updatedAt');
      final localVersion = LocalProjectVersion(
        _int(metadata['localVersion'], 'localVersion'),
      );
      final projectNorth = _projectNorth(
        orientation['projectNorthMilliDegrees'],
      );

      final sites = <SiteId, ProjectSiteEntity>{};
      for (final raw in _list(migrated.payload['sites'], 'sites')) {
        final json = _map(raw, 'site');
        final id = SiteId(_string(json['id'], 'site.id'));
        if (sites.containsKey(id)) {
          throw FormatException('Duplicate site id $id.');
        }
        sites[id] = ProjectSiteEntity(
          id: id,
          name: _string(json['name'], 'site.name'),
          buildingIds: _uniqueStringList(
            json['buildingIds'],
            'site.buildingIds',
          ).map(BuildingId.new),
        );
      }

      final buildings = <BuildingId, ProjectBuildingEntity>{};
      for (final raw in _list(migrated.payload['buildings'], 'buildings')) {
        final json = _map(raw, 'building');
        final id = BuildingId(_string(json['id'], 'building.id'));
        if (buildings.containsKey(id)) {
          throw FormatException('Duplicate building id $id.');
        }
        buildings[id] = ProjectBuildingEntity(
          id: id,
          siteId: SiteId(_string(json['siteId'], 'building.siteId')),
          name: _string(json['name'], 'building.name'),
          displayOrder: _int(json['displayOrder'], 'building.displayOrder'),
          levelIds: _uniqueStringList(
            json['levelIds'],
            'building.levelIds',
          ).map(LevelId.new),
        );
      }

      final levels = <LevelId, ProjectLevelEntity>{};
      for (final raw in _list(migrated.payload['levels'], 'levels')) {
        final json = _map(raw, 'level');
        final id = LevelId(_string(json['id'], 'level.id'));
        if (levels.containsKey(id)) {
          throw FormatException('Duplicate level id $id.');
        }
        levels[id] = ProjectLevelEntity(
          id: id,
          buildingId: BuildingId(
            _string(json['buildingId'], 'level.buildingId'),
          ),
          name: _string(json['name'], 'level.name'),
          levelNumber: _int(json['levelNumber'], 'level.levelNumber'),
          displayOrder: _int(json['displayOrder'], 'level.displayOrder'),
          elevationMm: _int(json['elevationMm'], 'level.elevationMm'),
          zoneIds: _uniqueStringList(
            json['zoneIds'],
            'level.zoneIds',
          ).map(ZoneId.new),
          spaceIds: _uniqueStringList(
            json['spaceIds'],
            'level.spaceIds',
          ).map(SpaceId.new),
        );
      }

      final zones = <ZoneId, ProjectStructuralZoneEntity>{};
      for (final raw in _list(migrated.payload['zones'], 'zones')) {
        final json = _map(raw, 'zone');
        final id = ZoneId(_string(json['id'], 'zone.id'));
        if (zones.containsKey(id)) {
          throw FormatException('Duplicate zone id $id.');
        }
        zones[id] = ProjectStructuralZoneEntity(
          id: id,
          levelId: LevelId(_string(json['levelId'], 'zone.levelId')),
          name: _string(json['name'], 'zone.name'),
          spaceIds: _uniqueStringList(
            json['spaceIds'],
            'zone.spaceIds',
          ).map(SpaceId.new),
        );
      }

      final spaces = <SpaceId, ProjectSpaceEntity>{};
      for (final raw in _list(migrated.payload['spaces'], 'spaces')) {
        final json = _map(raw, 'space');
        final id = SpaceId(_string(json['id'], 'space.id'));
        if (spaces.containsKey(id)) {
          throw FormatException('Duplicate space id $id.');
        }
        spaces[id] = ProjectSpaceEntity(
          id: id,
          levelId: LevelId(_string(json['levelId'], 'space.levelId')),
          name: _string(json['name'], 'space.name'),
          usage: _enumByName(
            SpaceUsage.values,
            json['usage'],
            'space.usage',
          ),
        );
      }

      final openings = <OpeningId, ProjectOpeningEntity>{};
      for (final raw in _list(migrated.payload['openings'], 'openings')) {
        final json = _map(raw, 'opening');
        final id = OpeningId(_string(json['id'], 'opening.id'));
        if (openings.containsKey(id)) {
          throw FormatException('Duplicate opening id $id.');
        }
        openings[id] = ProjectOpeningEntity(
          id: id,
          levelId: LevelId(_string(json['levelId'], 'opening.levelId')),
          kind: _enumByName(
            OpeningKind.values,
            json['kind'],
            'opening.kind',
          ),
          connectedSpaceIds: _uniqueStringList(
            json['connectedSpaceIds'],
            'opening.connectedSpaceIds',
          ).map(SpaceId.new),
          widthMm: _int(json['widthMm'], 'opening.widthMm'),
          heightMm: _int(json['heightMm'], 'opening.heightMm'),
          baseElevationMm: _int(
            json['baseElevationMm'],
            'opening.baseElevationMm',
          ),
        );
      }

      final adjacencies = <SpaceAdjacencyId, ProjectSpaceAdjacencyEntity>{};
      for (final raw in _list(migrated.payload['adjacencies'], 'adjacencies')) {
        final json = _map(raw, 'adjacency');
        final id = SpaceAdjacencyId(_string(json['id'], 'adjacency.id'));
        if (adjacencies.containsKey(id)) {
          throw FormatException('Duplicate adjacency id $id.');
        }
        adjacencies[id] = ProjectSpaceAdjacencyEntity(
          id: id,
          spaceAId: SpaceId(_string(json['spaceAId'], 'adjacency.spaceAId')),
          spaceBId: SpaceId(_string(json['spaceBId'], 'adjacency.spaceBId')),
          kind: _enumByName(
            SpaceAdjacencyKind.values,
            json['kind'],
            'adjacency.kind',
          ),
          openingId: _nullableString(json['openingId'], 'adjacency.openingId')
              ?.let(OpeningId.new),
        );
      }

      final overlays =
          <OverlayClassificationId, ProjectOverlayClassificationEntity>{};
      for (final raw in _list(migrated.payload['overlays'], 'overlays')) {
        final json = _map(raw, 'overlay');
        final id = OverlayClassificationId(_string(json['id'], 'overlay.id'));
        if (overlays.containsKey(id)) {
          throw FormatException('Duplicate overlay id $id.');
        }
        overlays[id] = ProjectOverlayClassificationEntity(
          id: id,
          name: _string(json['name'], 'overlay.name'),
          discipline: _enumByName(
            OverlayDiscipline.values,
            json['discipline'],
            'overlay.discipline',
          ),
          kind: _enumByName(
            OverlayClassificationKind.values,
            json['kind'],
            'overlay.kind',
          ),
          spaceIds: _uniqueStringList(
            json['spaceIds'],
            'overlay.spaceIds',
          ).map(SpaceId.new),
        );
      }

      final aggregate = ProjectAggregateRoot(
        id: projectId,
        siteId: siteId,
        version: localVersion,
        engineeringMetadata: ProjectEngineeringMetadata(
          projectNorth: projectNorth,
        ),
        stores: ProjectEntityStores(
          sites: sites,
          buildings: buildings,
          levels: levels,
          zones: zones,
          spaces: spaces,
          openings: openings,
          adjacencies: adjacencies,
          overlays: overlays,
        ),
      );

      return ProjectSnapshot(
        aggregate: aggregate,
        name: name,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
    } on FormatException {
      rethrow;
    } on ArgumentError catch (error) {
      throw FormatException('Invalid canonical ElecX project value: $error');
    } on ProjectAggregateValidationException catch (error) {
      throw FormatException('Invalid canonical ElecX project graph: $error');
    }
  }

  static ProjectDocument _migrateToCurrent(ProjectDocument document) {
    if (document.schemaVersion == schemaVersion) {
      return document;
    }
    if (document.schemaVersion < _schemaV1 ||
        document.schemaVersion > schemaVersion) {
      throw FormatException(
        'Unsupported canonical ElecX project schema '
        '${document.schemaVersion}; supported versions are '
        '$_schemaV1..$schemaVersion.',
      );
    }

    var migrated = document;
    if (migrated.schemaVersion == _schemaV1) {
      migrated = _migrateV1ToV2(migrated);
    }
    if (migrated.schemaVersion == _schemaV2) {
      migrated = _migrateV2ToV3(migrated);
    }
    return migrated;
  }

  static ProjectDocument _migrateV1ToV2(ProjectDocument document) =>
      ProjectDocument(
        schemaVersion: _schemaV2,
        payload: <String, Object?>{
          ...document.payload,
          'projectOrientation': <String, Object?>{
            'projectNorthMilliDegrees': null,
          },
        },
      );

  static ProjectDocument _migrateV2ToV3(ProjectDocument document) {
    final spaces = <Object?>[
      for (final raw in _list(document.payload['spaces'], 'spaces'))
        <String, Object?>{
          ..._map(raw, 'space'),
          'usage': SpaceUsage.unknown.name,
        },
    ];
    return ProjectDocument(
      schemaVersion: schemaVersion,
      payload: <String, Object?>{
        ...document.payload,
        'spaces': spaces,
        'openings': const <Object?>[],
        'adjacencies': const <Object?>[],
        'overlays': const <Object?>[],
      },
    );
  }

  static ProjectEngineeringNorth? _projectNorth(Object? value) {
    if (value == null) return null;
    if (value is! int) {
      throw const FormatException(
        'projectOrientation.projectNorthMilliDegrees must be an integer or null.',
      );
    }
    try {
      return ProjectEngineeringNorth.fromNormalizedMilliDegrees(value);
    } on RangeError catch (error) {
      throw FormatException(
        'projectOrientation.projectNorthMilliDegrees is out of range: $error',
      );
    }
  }

  static List<Object?> _encodeSites(ProjectEntityStores stores) {
    final values = stores.sites.values.toList()
      ..sort((a, b) => a.id.value.compareTo(b.id.value));
    return <Object?>[
      for (final site in values)
        <String, Object?>{
          'id': site.id.value,
          'name': site.name,
          'buildingIds': _sortedIds(site.buildingIds),
        },
    ];
  }

  static List<Object?> _encodeBuildings(ProjectEntityStores stores) {
    final values = stores.buildings.values.toList()
      ..sort((a, b) {
        final order = a.displayOrder.compareTo(b.displayOrder);
        return order != 0 ? order : a.id.value.compareTo(b.id.value);
      });
    return <Object?>[
      for (final building in values)
        <String, Object?>{
          'id': building.id.value,
          'siteId': building.siteId.value,
          'name': building.name,
          'displayOrder': building.displayOrder,
          'levelIds': _sortedIds(building.levelIds),
        },
    ];
  }

  static List<Object?> _encodeLevels(ProjectEntityStores stores) {
    final values = stores.levels.values.toList()
      ..sort((a, b) {
        final building = a.buildingId.value.compareTo(b.buildingId.value);
        if (building != 0) return building;
        final order = a.displayOrder.compareTo(b.displayOrder);
        return order != 0 ? order : a.id.value.compareTo(b.id.value);
      });
    return <Object?>[
      for (final level in values)
        <String, Object?>{
          'id': level.id.value,
          'buildingId': level.buildingId.value,
          'name': level.name,
          'levelNumber': level.levelNumber,
          'displayOrder': level.displayOrder,
          'elevationMm': level.elevationMm,
          'zoneIds': _sortedIds(level.zoneIds),
          'spaceIds': _sortedIds(level.spaceIds),
        },
    ];
  }

  static List<Object?> _encodeZones(ProjectEntityStores stores) {
    final values = stores.zones.values.toList()
      ..sort((a, b) => a.id.value.compareTo(b.id.value));
    return <Object?>[
      for (final zone in values)
        <String, Object?>{
          'id': zone.id.value,
          'levelId': zone.levelId.value,
          'name': zone.name,
          'spaceIds': _sortedIds(zone.spaceIds),
        },
    ];
  }

  static List<Object?> _encodeSpaces(ProjectEntityStores stores) {
    final values = stores.spaces.values.toList()
      ..sort((a, b) => a.id.value.compareTo(b.id.value));
    return <Object?>[
      for (final space in values)
        <String, Object?>{
          'id': space.id.value,
          'levelId': space.levelId.value,
          'name': space.name,
          'usage': space.usage.name,
        },
    ];
  }

  static List<Object?> _encodeOpenings(ProjectEntityStores stores) {
    final values = stores.openings.values.toList()
      ..sort((a, b) => a.id.value.compareTo(b.id.value));
    return <Object?>[
      for (final opening in values)
        <String, Object?>{
          'id': opening.id.value,
          'levelId': opening.levelId.value,
          'kind': opening.kind.name,
          'connectedSpaceIds': _sortedIds(opening.connectedSpaceIds),
          'widthMm': opening.widthMm,
          'heightMm': opening.heightMm,
          'baseElevationMm': opening.baseElevationMm,
        },
    ];
  }

  static List<Object?> _encodeAdjacencies(ProjectEntityStores stores) {
    final values = stores.adjacencies.values.toList()
      ..sort((a, b) => a.id.value.compareTo(b.id.value));
    return <Object?>[
      for (final adjacency in values)
        <String, Object?>{
          'id': adjacency.id.value,
          'spaceAId': adjacency.spaceAId.value,
          'spaceBId': adjacency.spaceBId.value,
          'kind': adjacency.kind.name,
          'openingId': adjacency.openingId?.value,
        },
    ];
  }

  static List<Object?> _encodeOverlays(ProjectEntityStores stores) {
    final values = stores.overlays.values.toList()
      ..sort((a, b) => a.id.value.compareTo(b.id.value));
    return <Object?>[
      for (final overlay in values)
        <String, Object?>{
          'id': overlay.id.value,
          'name': overlay.name,
          'discipline': overlay.discipline.name,
          'kind': overlay.kind.name,
          'spaceIds': _sortedIds(overlay.spaceIds),
        },
    ];
  }
}

List<String> _sortedIds(Iterable<EntityId> ids) {
  final values = ids.map((id) => id.value).toList()..sort();
  return List<String>.unmodifiable(values);
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

List<String> _uniqueStringList(Object? value, String field) {
  final result = <String>[];
  final seen = <String>{};
  for (final item in _list(value, field)) {
    final id = _string(item, field);
    if (!seen.add(id)) {
      throw FormatException('$field contains duplicate id $id.');
    }
    result.add(id);
  }
  return result;
}

T _enumByName<T extends Enum>(
  List<T> values,
  Object? value,
  String field,
) {
  final raw = _string(value, field);
  for (final candidate in values) {
    if (candidate.name == raw) return candidate;
  }
  throw FormatException('$field contains unsupported value $raw.');
}

String? _nullableString(Object? value, String field) {
  if (value == null) return null;
  return _string(value, field);
}

String _string(Object? value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$field must be a non-empty string.');
  }
  return value;
}

int _int(Object? value, String field) {
  if (value is! int) {
    throw FormatException('$field must be an integer.');
  }
  return value;
}

DateTime _dateTime(Object? value, String field) {
  final raw = _string(value, field);
  final hasExplicitZone = raw.endsWith('Z') ||
      raw.endsWith('z') ||
      RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(raw);
  if (!hasExplicitZone) {
    throw FormatException('$field must include an explicit UTC/offset zone.');
  }
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) {
    throw FormatException('$field must be an ISO-8601 timestamp.');
  }
  return parsed.toUtc();
}

extension _NullableStringMap<T> on String? {
  R? let<R>(R Function(String value) transform) {
    final value = this;
    return value == null ? null : transform(value);
  }
}
