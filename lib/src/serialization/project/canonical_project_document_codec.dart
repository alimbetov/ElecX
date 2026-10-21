import '../../application/project/project_snapshot.dart';
import '../../domain/project_aggregate.dart';
import '../../domain/project_identity.dart';
import 'project_document_codec.dart';

/// Canonical multi-building persistence codec introduced by P2D-1.
///
/// This schema is intentionally separate from the transitional editor JSON
/// schema. It persists the authoritative P1 aggregate without duplicating
/// building state inside both Site and Workspace representations.
final class CanonicalProjectDocumentCodec implements ProjectDocumentCodec {
  const CanonicalProjectDocumentCodec();

  static const int schemaVersion = 1;

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
        'sites': _encodeSites(stores),
        'buildings': _encodeBuildings(stores),
        'levels': _encodeLevels(stores),
        'zones': _encodeZones(stores),
        'spaces': _encodeSpaces(stores),
      },
    );
  }

  @override
  ProjectSnapshot decode(ProjectDocument document) {
    if (document.schemaVersion != schemaVersion) {
      throw FormatException(
        'Unsupported canonical ElecX project schema ${document.schemaVersion}; '
        'expected $schemaVersion.',
      );
    }

    try {
      final metadata = _map(document.payload['metadata'], 'metadata');
      final projectId = ProjectId(_string(metadata['projectId'], 'projectId'));
      final siteId = SiteId(_string(metadata['siteId'], 'siteId'));
      final name = _string(metadata['name'], 'name');
      final createdAt = _dateTime(metadata['createdAt'], 'createdAt');
      final updatedAt = _dateTime(metadata['updatedAt'], 'updatedAt');
      final localVersion = LocalProjectVersion(
        _int(metadata['localVersion'], 'localVersion'),
      );

      final sites = <SiteId, ProjectSiteEntity>{};
      for (final raw in _list(document.payload['sites'], 'sites')) {
        final json = _map(raw, 'site');
        final id = SiteId(_string(json['id'], 'site.id'));
        if (sites.containsKey(id)) {
          throw FormatException('Duplicate site id $id.');
        }
        sites[id] = ProjectSiteEntity(
          id: id,
          name: _string(json['name'], 'site.name'),
          buildingIds: _stringList(json['buildingIds'], 'site.buildingIds')
              .map(BuildingId.new),
        );
      }

      final buildings = <BuildingId, ProjectBuildingEntity>{};
      for (final raw in _list(document.payload['buildings'], 'buildings')) {
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
          levelIds: _stringList(json['levelIds'], 'building.levelIds')
              .map(LevelId.new),
        );
      }

      final levels = <LevelId, ProjectLevelEntity>{};
      for (final raw in _list(document.payload['levels'], 'levels')) {
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
          zoneIds: _stringList(json['zoneIds'], 'level.zoneIds').map(ZoneId.new),
          spaceIds:
              _stringList(json['spaceIds'], 'level.spaceIds').map(SpaceId.new),
        );
      }

      final zones = <ZoneId, ProjectStructuralZoneEntity>{};
      for (final raw in _list(document.payload['zones'], 'zones')) {
        final json = _map(raw, 'zone');
        final id = ZoneId(_string(json['id'], 'zone.id'));
        if (zones.containsKey(id)) {
          throw FormatException('Duplicate zone id $id.');
        }
        zones[id] = ProjectStructuralZoneEntity(
          id: id,
          levelId: LevelId(_string(json['levelId'], 'zone.levelId')),
          name: _string(json['name'], 'zone.name'),
          spaceIds:
              _stringList(json['spaceIds'], 'zone.spaceIds').map(SpaceId.new),
        );
      }

      final spaces = <SpaceId, ProjectSpaceEntity>{};
      for (final raw in _list(document.payload['spaces'], 'spaces')) {
        final json = _map(raw, 'space');
        final id = SpaceId(_string(json['id'], 'space.id'));
        if (spaces.containsKey(id)) {
          throw FormatException('Duplicate space id $id.');
        }
        spaces[id] = ProjectSpaceEntity(
          id: id,
          levelId: LevelId(_string(json['levelId'], 'space.levelId')),
          name: _string(json['name'], 'space.name'),
        );
      }

      final aggregate = ProjectAggregateRoot(
        id: projectId,
        siteId: siteId,
        version: localVersion,
        stores: ProjectEntityStores(
          sites: sites,
          buildings: buildings,
          levels: levels,
          zones: zones,
          spaces: spaces,
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

List<String> _stringList(Object? value, String field) => <String>[
      for (final item in _list(value, field)) _string(item, field),
    ];

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
