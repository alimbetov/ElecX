import '../../application/project/project_snapshot.dart';
import '../../domain/boundary_topology.dart';
import '../../domain/project_aggregate.dart';
import '../../domain/project_identity.dart';
import '../../domain/project_orientation.dart';
import '../../domain/project_site_layout.dart';
import 'common_core_aware_canonical_project_document_codec.dart';
import 'project_document_codec.dart';

/// v17 persists only Site placement/anchor metadata above the established v16
/// graph. Buildings, floors, geometry and P9 lineage retain their single owners.
final class SiteCompositionAwareCanonicalProjectDocumentCodec
    implements ProjectDocumentCodec {
  const SiteCompositionAwareCanonicalProjectDocumentCodec();
  static const schemaVersion = 17;
  static const _base = CommonCoreAwareCanonicalProjectDocumentCodec();
  @override
  int get currentSchemaVersion => schemaVersion;
  @override
  ProjectDocument encode(ProjectSnapshot snapshot) {
    if (snapshot
        .aggregate.engineeringMetadata.siteLayout.serviceAnchors.isNotEmpty) {
      throw const FormatException('Service anchors require schema v18.');
    }
    final base =
        _base.encode(_withLayout(snapshot, const ProjectSiteLayout.empty()));
    return ProjectDocument(schemaVersion: schemaVersion, payload: {
      ...base.payload,
      'siteLayout':
          snapshot.aggregate.engineeringMetadata.siteLayout.toCanonicalJson(),
    });
  }

  @override
  ProjectSnapshot decode(ProjectDocument document) {
    if (document.payload.containsKey('serviceAnchors')) {
      throw const FormatException('Service anchors require schema v18.');
    }
    if (document.schemaVersion < 1 || document.schemaVersion > schemaVersion) {
      throw const FormatException(
          'Unsupported canonical Site composition schema.');
    }
    if (document.schemaVersion < schemaVersion) {
      if (document.payload.containsKey('siteLayout')) {
        throw const FormatException('Site layout requires schema v17.');
      }
      return _base.decode(document);
    }
    try {
      final json = _map(document.payload['siteLayout'],
          {'schemaVersion', 'coordinateFrame', 'placements', 'sharedAnchors'});
      if (_int(json['schemaVersion']) != 1 ||
          json['coordinateFrame'] != 'building-local.v1') {
        throw const FormatException(
            'Unsupported Site coordinate frame/version.');
      }
      final placements = <BuildingId, ProjectBuildingSitePlacement>{};
      for (final raw in _list(json['placements'])) {
        final value = _map(raw, {
          'buildingId',
          'xMm',
          'yMm',
          'orientationMilliDegrees',
          'widthMm',
          'depthMm'
        });
        final id = BuildingId(_string(value['buildingId']));
        if (placements.containsKey(id)) {
          throw const FormatException('Duplicate placed BuildingId.');
        }
        placements[id] = ProjectBuildingSitePlacement(
            xMm: _int(value['xMm']),
            yMm: _int(value['yMm']),
            orientation: ProjectEngineeringNorth.fromNormalizedMilliDegrees(
                _int(value['orientationMilliDegrees'])),
            widthMm: _int(value['widthMm']),
            depthMm: _int(value['depthMm']));
      }
      final anchors = <ServiceEntryId, ProjectSharedSiteAnchor>{};
      for (final raw in _list(json['sharedAnchors'])) {
        final value = _map(raw, {
          'id',
          'siteId',
          'name',
          'kind',
          'xMm',
          'yMm',
          'servedBuildingIds'
        });
        final id = ServiceEntryId(_string(value['id']));
        if (anchors.containsKey(id)) {
          throw const FormatException('Duplicate shared anchor identity.');
        }
        final kind = ProjectSiteAnchorKind.values
            .where((k) => k.name == value['kind'])
            .toList();
        if (kind.length != 1) {
          throw const FormatException('Unknown shared Site anchor kind.');
        }
        final served = _list(value['servedBuildingIds'])
            .map((v) => BuildingId(_string(v)))
            .toList();
        if (served.toSet().length != served.length) {
          throw const FormatException('Duplicate served BuildingId.');
        }
        anchors[id] = ProjectSharedSiteAnchor(
            id: id,
            siteId: SiteId(_string(value['siteId'])),
            name: _string(value['name']),
            kind: kind.single,
            point: BoundaryPointMm(
                xMm: _int(value['xMm']), yMm: _int(value['yMm'])),
            servedBuildingIds: served);
      }
      final base = _base.decode(ProjectDocument(
          schemaVersion: 16,
          payload: {...document.payload}..remove('siteLayout')));
      return _withLayout(base,
          ProjectSiteLayout(placements: placements, sharedAnchors: anchors));
    } on FormatException {
      rethrow;
    } on ArgumentError catch (error) {
      throw FormatException('Malformed Site layout: $error');
    } on SiteLayoutException catch (error) {
      throw FormatException(error.code);
    } on ProjectAggregateValidationException catch (error) {
      throw FormatException('Invalid Site graph: $error');
    }
  }

  static ProjectSnapshot _withLayout(
      ProjectSnapshot snapshot, ProjectSiteLayout layout) {
    final project = snapshot.aggregate;
    return snapshot.copyWith(
        aggregate: ProjectAggregateRoot(
            id: project.id,
            siteId: project.siteId,
            version: project.version,
            stores: project.stores,
            engineeringMetadata:
                project.engineeringMetadata.copyWith(siteLayout: layout)));
  }
}

Map<String, Object?> _map(Object? raw, Set<String> expected) {
  if (raw is! Map || raw.keys.any((k) => k is! String)) {
    throw const FormatException('Expected an object.');
  }
  final value = Map<String, Object?>.from(raw);
  if (value.length != expected.length || !expected.containsAll(value.keys)) {
    throw const FormatException('Unknown or missing Site layout field.');
  }
  return value;
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
  if (raw is! int) {
    throw const FormatException('Expected an integer millimetre value.');
  }
  return raw;
}
