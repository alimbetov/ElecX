import '../../application/project/project_snapshot.dart';
import '../../domain/boundary_host_migration.dart';
import '../../domain/boundary_host_registry.dart';
import '../../domain/boundary_topology.dart';
import '../../domain/project_aggregate.dart';
import '../../domain/project_identity.dart';
import '../../domain/project_service_anchor.dart';
import 'project_document_codec.dart';
import 'site_composition_aware_canonical_project_document_codec.dart';

/// v18 persists P10.10 architectural anchors and restores their physical wall
/// bindings into the existing P7 registry. No second physical host store exists.
final class ServiceAnchorAwareCanonicalProjectDocumentCodec
    implements ProjectDocumentCodec {
  const ServiceAnchorAwareCanonicalProjectDocumentCodec();
  static const schemaVersion = 18;
  static const _base = SiteCompositionAwareCanonicalProjectDocumentCodec();
  @override
  int get currentSchemaVersion => schemaVersion;
  @override
  ProjectDocument encode(ProjectSnapshot snapshot) {
    final project = snapshot.aggregate;
    final anchors = project.engineeringMetadata.siteLayout.serviceAnchors;
    final base = _base.encode(_withoutAnchors(snapshot));
    return ProjectDocument(schemaVersion: schemaVersion, payload: {
      ...base.payload,
      'serviceAnchors': {
        'schemaVersion': 1,
        'anchors': [
          for (final id
              in anchors.keys.toList()
                ..sort((a, b) => a.value.compareTo(b.value)))
            {
              'anchor': anchors[id]!.toCanonicalJson(),
              'wallBinding': anchors[id] is ProjectBoundaryServiceAnchor
                  ? () {
                      final host = project
                          .engineeringMetadata.boundaryHostedObjectRegistry
                          .serviceEntryHost(id)!;
                      return ServiceAnchorBoundaryBinding(
                              host: host.host, offsetMm: host.startOffsetMm!)
                          .toCanonicalJson();
                    }()
                  : null,
            },
        ]
      },
    });
  }

  @override
  ProjectSnapshot decode(ProjectDocument document) {
    if (document.schemaVersion < 1 || document.schemaVersion > schemaVersion) {
      throw const FormatException(
          'Unsupported canonical service-anchor schema.');
    }
    if (document.schemaVersion < schemaVersion) {
      if (document.payload.containsKey('serviceAnchors')) {
        throw const FormatException('Service anchors require schema v18.');
      }
      return _base.decode(document);
    }
    try {
      final root = _map(
          document.payload['serviceAnchors'], {'schemaVersion', 'anchors'});
      if (_int(root['schemaVersion']) != 1) {
        throw const FormatException(
            'Unsupported service-anchor schema version.');
      }
      final base = _base.decode(ProjectDocument(
          schemaVersion: 17,
          payload: {...document.payload}..remove('serviceAnchors')));
      final anchors = <ServiceEntryId, ProjectServiceAnchor>{};
      var hosts =
          base.aggregate.engineeringMetadata.boundaryHostedObjectRegistry;
      for (final raw in _list(root['anchors'])) {
        final entry = _map(raw, {'anchor', 'wallBinding'});
        final json = _map(entry['anchor']);
        final common = <String>{'id', 'siteId', 'name', 'kind', 'hostType'};
        final type = _string(json['hostType']);
        final expected = switch (type) {
          'site' => {...common, 'xMm', 'yMm', 'servedBuildingIds'},
          'space' => {
              ...common,
              'buildingId',
              'levelId',
              'spaceId',
              'xMm',
              'yMm',
              'heightMm'
            },
          'boundary' => {
              ...common,
              'buildingId',
              'levelId',
              'spaceId',
              'heightMm'
            },
          _ => throw const FormatException(
              'Unsupported service-anchor host type.'),
        };
        _map(json, expected);
        final id = ServiceEntryId(_string(json['id']));
        if (anchors.containsKey(id) ||
            base.aggregate.engineeringMetadata.siteLayout.sharedAnchors
                .containsKey(id)) {
          throw const FormatException('Duplicate ServiceEntryId.');
        }
        final siteId = SiteId(_string(json['siteId']));
        final name = _string(json['name']);
        final kinds = ProjectServiceAnchorKind.values
            .where((k) => k.name == json['kind'])
            .toList();
        if (kinds.length != 1) {
          throw const FormatException('Unsupported service-anchor kind.');
        }
        final kind = kinds.single;
        if (type == 'site') {
          final served = _list(json['servedBuildingIds'])
              .map((v) => BuildingId(_string(v)))
              .toList();
          if (served.toSet().length != served.length) {
            throw const FormatException('Duplicate served BuildingId.');
          }
          anchors[id] = ProjectSiteServiceAnchor(
              id: id,
              siteId: siteId,
              name: name,
              kind: kind,
              point: BoundaryPointMm(
                  xMm: _int(json['xMm']), yMm: _int(json['yMm'])),
              servedBuildingIds: served);
        } else {
          final buildingId = BuildingId(_string(json['buildingId']));
          final levelId = LevelId(_string(json['levelId']));
          final spaceId = SpaceId(_string(json['spaceId']));
          final height = _int(json['heightMm']);
          if (type == 'space') {
            anchors[id] = ProjectSpaceServiceAnchor(
                id: id,
                siteId: siteId,
                name: name,
                kind: kind,
                buildingId: buildingId,
                levelId: levelId,
                spaceId: spaceId,
                heightMm: height,
                point: BoundaryPointMm(
                    xMm: _int(json['xMm']), yMm: _int(json['yMm'])));
          } else {
            anchors[id] = ProjectBoundaryServiceAnchor(
                id: id,
                siteId: siteId,
                name: name,
                kind: kind,
                buildingId: buildingId,
                levelId: levelId,
                spaceId: spaceId,
                heightMm: height);
            final binding =
                _map(entry['wallBinding'], {'spaceId', 'edgeId', 'offsetMm'});
            final key = BoundaryHostedObjectRegistry.serviceEntryObjectKey(id);
            if (hosts.references.containsKey(key)) {
              throw const FormatException(
                  'Conflicting physical host identity.');
            }
            hosts = hosts.putServiceEntry(
                id: id,
                host: BoundaryEdgeHostRef(
                    spaceId: SpaceId(_string(binding['spaceId'])),
                    edgeId: BoundaryEdgeId(_string(binding['edgeId']))),
                offsetMm: _int(binding['offsetMm']));
          }
        }
        if (type != 'boundary' && entry['wallBinding'] != null) {
          throw const FormatException(
              'Only a boundary entry may own a wall binding.');
        }
      }
      final project = base.aggregate;
      return base.copyWith(
          aggregate: ProjectAggregateRoot(
              id: project.id,
              siteId: project.siteId,
              version: project.version,
              stores: project.stores,
              engineeringMetadata: project.engineeringMetadata.copyWith(
                  siteLayout: project.engineeringMetadata.siteLayout
                      .copyWith(serviceAnchors: anchors),
                  boundaryHostedObjectRegistry: hosts)));
    } on FormatException {
      rethrow;
    } on ArgumentError catch (error) {
      throw FormatException('Malformed service anchor: $error');
    } on BoundaryHostedRegistryException catch (error) {
      throw FormatException('Invalid service-entry wall binding: $error');
    } on ServiceAnchorException catch (error) {
      throw FormatException(error.code);
    } on ProjectAggregateValidationException catch (error) {
      throw FormatException('Invalid anchor ownership: $error');
    }
  }

  static ProjectSnapshot _withoutAnchors(ProjectSnapshot snapshot) {
    final project = snapshot.aggregate;
    var hosts = project.engineeringMetadata.boundaryHostedObjectRegistry;
    for (final anchor
        in project.engineeringMetadata.siteLayout.serviceAnchors.values) {
      if (anchor is ProjectBoundaryServiceAnchor) {
        hosts = hosts.remove(
            BoundaryHostedObjectRegistry.serviceEntryObjectKey(anchor.id));
      }
    }
    return snapshot.copyWith(
        aggregate: ProjectAggregateRoot(
            id: project.id,
            siteId: project.siteId,
            version: project.version,
            stores: project.stores,
            engineeringMetadata: project.engineeringMetadata.copyWith(
                siteLayout: project.engineeringMetadata.siteLayout
                    .copyWith(serviceAnchors: {}),
                boundaryHostedObjectRegistry: hosts)));
  }
}

Map<String, Object?> _map(Object? raw, [Set<String>? expected]) {
  if (raw is! Map || raw.keys.any((k) => k is! String)) {
    throw const FormatException('Expected an object.');
  }
  final result = Map<String, Object?>.from(raw);
  if (expected != null &&
      (result.length != expected.length ||
          !expected.containsAll(result.keys))) {
    throw const FormatException('Unknown or missing service-anchor field.');
  }
  return result;
}

List<Object?> _list(Object? raw) {
  if (raw is! List) throw const FormatException('Expected an array.');
  return List<Object?>.from(raw);
}

String _string(Object? raw) {
  if (raw is! String || raw.trim().isEmpty) {
    throw const FormatException('Expected a non-empty string.');
  }
  return raw;
}

int _int(Object? raw) {
  if (raw is! int) throw const FormatException('Expected an integer.');
  return raw;
}
