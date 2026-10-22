import '../../application/project/project_snapshot.dart';
import '../../domain/boundary_edge_identity_registry.dart';
import '../../domain/boundary_host_migration.dart';
import '../../domain/boundary_host_registry.dart';
import '../../domain/boundary_topology.dart';
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
/// - v3: P6 SpaceUsage, openings, adjacency and overlay classifications;
/// - v4: P7A stable boundary topology and durable edge-owner tombstones;
/// - v5: P7A-5 durable hosted-object ownership by BoundaryEdgeId.
final class CanonicalProjectDocumentCodec implements ProjectDocumentCodec {
  const CanonicalProjectDocumentCodec();

  static const int schemaVersion = 5;
  static const int _schemaV1 = 1;
  static const int _schemaV2 = 2;
  static const int _schemaV3 = 3;
  static const int _schemaV4 = 4;

  @override
  int get currentSchemaVersion => schemaVersion;

  @override
  ProjectDocument encode(ProjectSnapshot snapshot) {
    final stores = snapshot.aggregate.stores;
    final identityRegistry = snapshot
        .aggregate.engineeringMetadata.boundaryEdgeIdentityRegistry
        .registerActiveBoundaries(stores.boundaries);
    final hostedRegistry =
        snapshot.aggregate.engineeringMetadata.boundaryHostedObjectRegistry;
    hostedRegistry.validateAgainst(stores.boundaries);
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
        'boundaryEdgeIdentityRegistry': _encodeBoundaryIdentityRegistry(
          identityRegistry,
        ),
        'boundaryHostedObjectRegistry': _encodeBoundaryHostedObjectRegistry(
          hostedRegistry,
        ),
        'sites': _encodeSites(stores),
        'buildings': _encodeBuildings(stores),
        'levels': _encodeLevels(stores),
        'zones': _encodeZones(stores),
        'spaces': _encodeSpaces(stores),
        'openings': _encodeOpenings(stores),
        'adjacencies': _encodeAdjacencies(stores),
        'overlays': _encodeOverlays(stores),
        'boundaries': _encodeBoundaries(stores),
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
          usage: _enumByName(SpaceUsage.values, json['usage'], 'space.usage'),
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
          kind: _enumByName(OpeningKind.values, json['kind'], 'opening.kind'),
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
        final openingId = _nullableString(
          json['openingId'],
          'adjacency.openingId',
        );
        adjacencies[id] = ProjectSpaceAdjacencyEntity(
          id: id,
          spaceAId: SpaceId(_string(json['spaceAId'], 'adjacency.spaceAId')),
          spaceBId: SpaceId(_string(json['spaceBId'], 'adjacency.spaceBId')),
          kind: _enumByName(
            SpaceAdjacencyKind.values,
            json['kind'],
            'adjacency.kind',
          ),
          openingId: openingId == null ? null : OpeningId(openingId),
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

      final boundaries = _decodeBoundaries(migrated.payload['boundaries']);
      final identityRegistry = _decodeBoundaryIdentityRegistry(
        migrated.payload['boundaryEdgeIdentityRegistry'],
      );
      _requireRegistryCoversActiveBoundaries(identityRegistry, boundaries);
      final hostedRegistry = _decodeBoundaryHostedObjectRegistry(
        migrated.payload['boundaryHostedObjectRegistry'],
      );
      hostedRegistry.validateAgainst(boundaries);

      final aggregate = ProjectAggregateRoot(
        id: projectId,
        siteId: siteId,
        version: localVersion,
        engineeringMetadata: ProjectEngineeringMetadata(
          projectNorth: projectNorth,
          boundaryEdgeIdentityRegistry: identityRegistry,
          boundaryHostedObjectRegistry: hostedRegistry,
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
          boundaries: boundaries,
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
    } on BoundaryEdgeIdentityOwnershipException catch (error) {
      throw FormatException('Invalid boundary edge identity registry: $error');
    } on BoundaryHostedRegistryException catch (error) {
      throw FormatException('Invalid boundary hosted-object registry: $error');
    } on BoundaryTopologyValidationException catch (error) {
      throw FormatException('Invalid persisted boundary topology: $error');
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
    if (migrated.schemaVersion == _schemaV3) {
      migrated = _migrateV3ToV4(migrated);
    }
    if (migrated.schemaVersion == _schemaV4) {
      migrated = _migrateV4ToV5(migrated);
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
      schemaVersion: _schemaV3,
      payload: <String, Object?>{
        ...document.payload,
        'spaces': spaces,
        'openings': const <Object?>[],
        'adjacencies': const <Object?>[],
        'overlays': const <Object?>[],
      },
    );
  }

  static ProjectDocument _migrateV3ToV4(ProjectDocument document) =>
      ProjectDocument(
        schemaVersion: _schemaV4,
        payload: <String, Object?>{
          ...document.payload,
          'boundaries': const <Object?>[],
          'boundaryEdgeIdentityRegistry': const <Object?>[],
        },
      );

  static ProjectDocument _migrateV4ToV5(ProjectDocument document) =>
      ProjectDocument(
        schemaVersion: schemaVersion,
        payload: <String, Object?>{
          ...document.payload,
          'boundaryHostedObjectRegistry': const <Object?>[],
        },
      );

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

  static List<Object?> _encodeBoundaries(ProjectEntityStores stores) {
    final values = stores.boundaries.values.toList()
      ..sort((a, b) => a.spaceId.value.compareTo(b.spaceId.value));
    return <Object?>[
      for (final topology in values)
        <String, Object?>{
          'spaceId': topology.spaceId.value,
          'orderedEdgeIds': _sortedPreservingOrder(topology.orderedEdgeIds),
          'edges': <Object?>[
            for (final edgeId in topology.orderedEdgeIds)
              _encodeBoundaryEdge(topology.edges[edgeId]!),
          ],
        },
    ];
  }

  static Map<String, Object?> _encodeBoundaryEdge(ProjectBoundaryEdge edge) =>
      <String, Object?>{
        'id': edge.id.value,
        'spaceId': edge.spaceId.value,
        'start': <String, Object?>{
          'xMm': edge.start.xMm,
          'yMm': edge.start.yMm,
        },
        'end': <String, Object?>{
          'xMm': edge.end.xMm,
          'yMm': edge.end.yMm,
        },
      };

  static List<Object?> _encodeBoundaryIdentityRegistry(
    BoundaryEdgeIdentityRegistry registry,
  ) {
    final entries = registry.owners.entries.toList()
      ..sort((a, b) => a.key.value.compareTo(b.key.value));
    return <Object?>[
      for (final entry in entries)
        <String, Object?>{
          'edgeId': entry.key.value,
          'spaceId': entry.value.value,
        },
    ];
  }

  static List<Object?> _encodeBoundaryHostedObjectRegistry(
    BoundaryHostedObjectRegistry registry,
  ) {
    final entries = registry.references.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return <Object?>[
      for (final entry in entries)
        <String, Object?>{
          'objectKey': entry.key,
          'objectKind': entry.value.objectKind.name,
          'spaceId': entry.value.host.spaceId.value,
          'edgeId': entry.value.host.edgeId.value,
          'geometryKind': entry.value.geometryKind.name,
          'startOffsetMm': entry.value.startOffsetMm,
          'endOffsetMm': entry.value.endOffsetMm,
        },
    ];
  }

  static Map<SpaceId, SpaceBoundaryTopology> _decodeBoundaries(Object? value) {
    final result = <SpaceId, SpaceBoundaryTopology>{};
    for (final raw in _list(value, 'boundaries')) {
      final json = _map(raw, 'boundary');
      final spaceId = SpaceId(_string(json['spaceId'], 'boundary.spaceId'));
      if (result.containsKey(spaceId)) {
        throw FormatException('Duplicate boundary owner $spaceId.');
      }
      final orderedEdgeIds = _uniqueStringList(
        json['orderedEdgeIds'],
        'boundary.orderedEdgeIds',
      ).map(BoundaryEdgeId.new).toList(growable: false);
      final edges = <BoundaryEdgeId, ProjectBoundaryEdge>{};
      for (final edgeRaw in _list(json['edges'], 'boundary.edges')) {
        final edgeJson = _map(edgeRaw, 'boundary.edge');
        final edgeId = BoundaryEdgeId(
          _string(edgeJson['id'], 'boundary.edge.id'),
        );
        if (edges.containsKey(edgeId)) {
          throw FormatException('Duplicate boundary edge id $edgeId.');
        }
        final edgeSpaceId = SpaceId(
          _string(edgeJson['spaceId'], 'boundary.edge.spaceId'),
        );
        edges[edgeId] = ProjectBoundaryEdge(
          id: edgeId,
          spaceId: edgeSpaceId,
          start: _boundaryPoint(edgeJson['start'], 'boundary.edge.start'),
          end: _boundaryPoint(edgeJson['end'], 'boundary.edge.end'),
        );
      }
      final topology = SpaceBoundaryTopology(
        spaceId: spaceId,
        orderedEdgeIds: orderedEdgeIds,
        edges: edges,
      );
      topology.validateOrThrow();
      result[spaceId] = topology;
    }
    return Map.unmodifiable(result);
  }

  static BoundaryEdgeIdentityRegistry _decodeBoundaryIdentityRegistry(
    Object? value,
  ) {
    final owners = <BoundaryEdgeId, SpaceId>{};
    for (final raw in _list(value, 'boundaryEdgeIdentityRegistry')) {
      final json = _map(raw, 'boundaryEdgeIdentityRegistry.entry');
      final edgeId = BoundaryEdgeId(
        _string(json['edgeId'], 'boundaryEdgeIdentityRegistry.edgeId'),
      );
      final spaceId = SpaceId(
        _string(json['spaceId'], 'boundaryEdgeIdentityRegistry.spaceId'),
      );
      if (owners.containsKey(edgeId)) {
        throw FormatException(
          'boundaryEdgeIdentityRegistry contains duplicate edge id $edgeId.',
        );
      }
      owners[edgeId] = spaceId;
    }
    return BoundaryEdgeIdentityRegistry(owners);
  }

  static BoundaryHostedObjectRegistry _decodeBoundaryHostedObjectRegistry(
    Object? value,
  ) {
    final references = <String, BoundaryHostedReference>{};
    for (final raw in _list(value, 'boundaryHostedObjectRegistry')) {
      final json = _map(raw, 'boundaryHostedObjectRegistry.entry');
      final objectKey = _string(
        json['objectKey'],
        'boundaryHostedObjectRegistry.objectKey',
      );
      if (references.containsKey(objectKey)) {
        throw FormatException(
          'boundaryHostedObjectRegistry contains duplicate object key '
          '$objectKey.',
        );
      }
      final objectKind = _enumByName(
        BoundaryHostedObjectKind.values,
        json['objectKind'],
        'boundaryHostedObjectRegistry.objectKind',
      );
      final geometryKind = _enumByName(
        BoundaryHostGeometryKind.values,
        json['geometryKind'],
        'boundaryHostedObjectRegistry.geometryKind',
      );
      final host = BoundaryEdgeHostRef(
        spaceId: SpaceId(
          _string(json['spaceId'], 'boundaryHostedObjectRegistry.spaceId'),
        ),
        edgeId: BoundaryEdgeId(
          _string(json['edgeId'], 'boundaryHostedObjectRegistry.edgeId'),
        ),
      );
      final startOffset = _nullableInt(
        json['startOffsetMm'],
        'boundaryHostedObjectRegistry.startOffsetMm',
      );
      final endOffset = _nullableInt(
        json['endOffsetMm'],
        'boundaryHostedObjectRegistry.endOffsetMm',
      );
      references[objectKey] = switch (geometryKind) {
        BoundaryHostGeometryKind.point => () {
            if (startOffset == null || endOffset != null) {
              throw FormatException(
                'Point hosted object $objectKey requires startOffsetMm and '
                'forbids endOffsetMm.',
              );
            }
            return BoundaryHostedReference.point(
              objectKey: objectKey,
              objectKind: objectKind,
              host: host,
              offsetMm: startOffset,
            );
          }(),
        BoundaryHostGeometryKind.interval => () {
            if (startOffset == null || endOffset == null) {
              throw FormatException(
                'Interval hosted object $objectKey requires both offsets.',
              );
            }
            return BoundaryHostedReference.interval(
              objectKey: objectKey,
              objectKind: objectKind,
              host: host,
              startOffsetMm: startOffset,
              endOffsetMm: endOffset,
            );
          }(),
        BoundaryHostGeometryKind.wholeEdge => () {
            if (startOffset != null || endOffset != null) {
              throw FormatException(
                'Whole-edge hosted object $objectKey cannot carry offsets.',
              );
            }
            return BoundaryHostedReference.wholeEdge(
              objectKey: objectKey,
              objectKind: objectKind,
              host: host,
            );
          }(),
      };
    }
    return BoundaryHostedObjectRegistry(references);
  }

  static void _requireRegistryCoversActiveBoundaries(
    BoundaryEdgeIdentityRegistry registry,
    Map<SpaceId, SpaceBoundaryTopology> boundaries,
  ) {
    for (final topology in boundaries.values) {
      for (final edgeId in topology.edges.keys) {
        final registeredOwner = registry.ownerOf(edgeId);
        if (registeredOwner == null) {
          throw FormatException(
            'Active boundary edge $edgeId is missing from '
            'boundaryEdgeIdentityRegistry.',
          );
        }
        if (registeredOwner != topology.spaceId) {
          throw FormatException(
            'Active boundary edge $edgeId belongs to ${topology.spaceId} but '
            'registry owner is $registeredOwner.',
          );
        }
      }
    }
  }

  static BoundaryPointMm _boundaryPoint(Object? value, String field) {
    final json = _map(value, field);
    return BoundaryPointMm(
      xMm: _int(json['xMm'], '$field.xMm'),
      yMm: _int(json['yMm'], '$field.yMm'),
    );
  }
}

List<String> _sortedIds(Iterable<EntityId> ids) {
  final values = ids.map((id) => id.value).toList()..sort();
  return List<String>.unmodifiable(values);
}

List<String> _sortedPreservingOrder(Iterable<EntityId> ids) =>
    List<String>.unmodifiable(ids.map((id) => id.value));

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

T _enumByName<T extends Enum>(List<T> values, Object? value, String field) {
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

int? _nullableInt(Object? value, String field) {
  if (value == null) return null;
  return _int(value, field);
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
