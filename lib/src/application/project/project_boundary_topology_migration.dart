import '../../domain/boundary_geometry_integrity.dart';
import '../../domain/boundary_host_registry.dart';
import '../../domain/boundary_topology.dart';
import '../../domain/boundary_wall_profile_registry.dart';
import '../../domain/project_aggregate.dart';
import '../../domain/project_identity.dart';
import 'project_mutation.dart';

/// P7A-5 application boundary for identity-changing topology edits.
///
/// Unlike the P7A-4.5 geometry editor, this service accepts explicit lineage
/// and atomically remaps canonical hosted-object ownership and wall-profile
/// payloads in the same P3 mutation as the topology replacement.
final class ProjectBoundaryTopologyMigrationService {
  const ProjectBoundaryTopologyMigrationService(this._mutations);

  final ProjectMutationSession _mutations;

  CanonicalBoundaryTopologyMigrationSession begin({
    required SpaceId spaceId,
    required LocalProjectVersion expectedVersion,
  }) {
    final current = _mutations.current;
    if (current.version != expectedVersion) {
      throw StaleProjectMutationException(
        expectedVersion: expectedVersion,
        currentVersion: current.version,
      );
    }
    final source = current.index.boundary(spaceId);
    if (source == null) {
      throw BoundaryTopologyMigrationException(
        code: BoundaryTopologyMigrationIssueCode.topologyMissing,
        message: 'Canonical Space $spaceId has no boundary topology.',
      );
    }
    source.validateOrThrow();
    BoundaryGeometryIntegrity.validateOrThrow(source);
    return CanonicalBoundaryTopologyMigrationSession._(
      mutations: _mutations,
      spaceId: spaceId,
      expectedVersion: expectedVersion,
      source: source,
      sourceRegistry: current.engineeringMetadata.boundaryHostedObjectRegistry,
      sourceProfiles: current.engineeringMetadata.boundaryWallProfileRegistry,
    );
  }
}

enum BoundaryTopologyMigrationIssueCode {
  topologyMissing,
  edgeNotFound,
  splitPointNotInterior,
  mergeEdgesNotAdjacent,
  tooFewResultEdges,
  lineageSourceCoverageMismatch,
  lineageResultCoverageMismatch,
}

final class BoundaryTopologyMigrationException implements Exception {
  const BoundaryTopologyMigrationException({
    required this.code,
    required this.message,
  });

  final BoundaryTopologyMigrationIssueCode code;
  final String message;

  @override
  String toString() => '${code.name}: $message';
}

final class BoundaryTopologyMigrationPreview {
  const BoundaryTopologyMigrationPreview({
    required this.topology,
    required this.lineage,
    required this.hostedObjects,
    required this.wallProfiles,
  });

  final SpaceBoundaryTopology topology;
  final BoundaryTopologyChangeSet lineage;
  final BoundaryHostedObjectRegistry hostedObjects;
  final BoundaryWallProfileRegistry wallProfiles;
}

final class BoundaryTopologyMigrationCommit {
  const BoundaryTopologyMigrationCommit({
    required this.mutation,
    required this.lineage,
  });

  final ProjectMutationResult mutation;
  final BoundaryTopologyChangeSet lineage;
}

final class CanonicalBoundaryTopologyMigrationSession {
  CanonicalBoundaryTopologyMigrationSession._({
    required ProjectMutationSession mutations,
    required this.spaceId,
    required this.expectedVersion,
    required SpaceBoundaryTopology source,
    required BoundaryHostedObjectRegistry sourceRegistry,
    required BoundaryWallProfileRegistry sourceProfiles,
  })  : _mutations = mutations,
        _source = source,
        _sourceRegistry = sourceRegistry,
        _sourceProfiles = sourceProfiles,
        _previewTopology = source,
        _previewRegistry = sourceRegistry,
        _previewProfiles = sourceProfiles;

  final ProjectMutationSession _mutations;
  final SpaceId spaceId;
  final LocalProjectVersion expectedVersion;
  final SpaceBoundaryTopology _source;
  final BoundaryHostedObjectRegistry _sourceRegistry;
  final BoundaryWallProfileRegistry _sourceProfiles;

  SpaceBoundaryTopology _previewTopology;
  BoundaryHostedObjectRegistry _previewRegistry;
  BoundaryWallProfileRegistry _previewProfiles;
  BoundaryTopologyChangeSet? _lineage;

  SpaceBoundaryTopology get source => _source;
  SpaceBoundaryTopology get previewTopology => _previewTopology;
  BoundaryHostedObjectRegistry get previewHostedObjects => _previewRegistry;
  BoundaryWallProfileRegistry get previewWallProfiles => _previewProfiles;
  BoundaryTopologyChangeSet? get previewLineage => _lineage;
  bool get dirty => _lineage != null;

  BoundaryTopologyMigrationPreview previewSplitEdge({
    required BoundaryEdgeId sourceEdgeId,
    required BoundaryPointMm splitPoint,
    required BoundaryEdgeId firstResultEdgeId,
    required BoundaryEdgeId secondResultEdgeId,
  }) {
    _requireCurrentVersion();
    final sourceEdge = _source.edges[sourceEdgeId];
    if (sourceEdge == null) {
      throw BoundaryTopologyMigrationException(
        code: BoundaryTopologyMigrationIssueCode.edgeNotFound,
        message: 'Source edge $sourceEdgeId does not exist.',
      );
    }
    if (splitPoint == sourceEdge.start ||
        splitPoint == sourceEdge.end ||
        !_pointOnSegment(sourceEdge, splitPoint)) {
      throw BoundaryTopologyMigrationException(
        code: BoundaryTopologyMigrationIssueCode.splitPointNotInterior,
        message: 'Split point must lie strictly inside $sourceEdgeId.',
      );
    }
    if (firstResultEdgeId == secondResultEdgeId ||
        _source.edges.containsKey(firstResultEdgeId) ||
        _source.edges.containsKey(secondResultEdgeId)) {
      throw ArgumentError(
        'Split result BoundaryEdgeIds must be new and distinct.',
      );
    }

    final first = ProjectBoundaryEdge(
      id: firstResultEdgeId,
      spaceId: spaceId,
      start: sourceEdge.start,
      end: splitPoint,
    );
    final second = ProjectBoundaryEdge(
      id: secondResultEdgeId,
      spaceId: spaceId,
      start: splitPoint,
      end: sourceEdge.end,
    );
    final ordered = <BoundaryEdgeId>[];
    final edges = Map<BoundaryEdgeId, ProjectBoundaryEdge>.from(_source.edges)
      ..remove(sourceEdgeId)
      ..[first.id] = first
      ..[second.id] = second;
    for (final id in _source.orderedEdgeIds) {
      if (id == sourceEdgeId) {
        ordered.add(first.id);
        ordered.add(second.id);
      } else {
        ordered.add(id);
      }
    }
    final topology = SpaceBoundaryTopology(
      spaceId: spaceId,
      orderedEdgeIds: ordered,
      edges: edges,
    );
    final lineage = BoundaryTopologyChangeSet([
      for (final id in _source.orderedEdgeIds)
        if (id != sourceEdgeId) BoundaryEdgeLineage.preserved(id),
      BoundaryEdgeLineage.split(
        sourceEdgeId: sourceEdgeId,
        resultEdgeIds: [first.id, second.id],
      ),
    ]);
    final profiles = _sourceProfiles.split(
      spaceId: spaceId,
      sourceEdge: sourceEdge,
      firstResultEdgeId: first.id,
      secondResultEdgeId: second.id,
      splitPoint: splitPoint,
    );
    return previewReplaceTopology(
      topology: topology,
      lineage: lineage,
      wallProfiles: profiles,
    );
  }

  BoundaryTopologyMigrationPreview previewMergeAdjacentEdges({
    required BoundaryEdgeId firstSourceEdgeId,
    required BoundaryEdgeId secondSourceEdgeId,
    required BoundaryEdgeId resultEdgeId,
  }) {
    _requireCurrentVersion();
    final firstIndex = _source.orderedEdgeIds.indexOf(firstSourceEdgeId);
    final secondIndex = _source.orderedEdgeIds.indexOf(secondSourceEdgeId);
    final first = _source.edges[firstSourceEdgeId];
    final second = _source.edges[secondSourceEdgeId];
    if (first == null || second == null) {
      throw BoundaryTopologyMigrationException(
        code: BoundaryTopologyMigrationIssueCode.edgeNotFound,
        message: 'Both source edges must exist before merge.',
      );
    }
    if (_source.orderedEdgeIds.length <= 3) {
      throw BoundaryTopologyMigrationException(
        code: BoundaryTopologyMigrationIssueCode.tooFewResultEdges,
        message: 'Merge would leave fewer than three boundary edges.',
      );
    }
    final expectedSecond = (firstIndex + 1) % _source.orderedEdgeIds.length;
    if (firstIndex < 0 ||
        secondIndex != expectedSecond ||
        first.end != second.start) {
      throw BoundaryTopologyMigrationException(
        code: BoundaryTopologyMigrationIssueCode.mergeEdgesNotAdjacent,
        message: '$firstSourceEdgeId and $secondSourceEdgeId are not an '
            'ordered adjacent pair.',
      );
    }
    if (_source.edges.containsKey(resultEdgeId)) {
      throw ArgumentError('Merged result BoundaryEdgeId must be new.');
    }

    final merged = ProjectBoundaryEdge(
      id: resultEdgeId,
      spaceId: spaceId,
      start: first.start,
      end: second.end,
    );
    final ordered = <BoundaryEdgeId>[];
    for (var index = 0; index < _source.orderedEdgeIds.length; index++) {
      if (index == firstIndex) {
        ordered.add(merged.id);
      } else if (index != secondIndex) {
        ordered.add(_source.orderedEdgeIds[index]);
      }
    }
    final edges = Map<BoundaryEdgeId, ProjectBoundaryEdge>.from(_source.edges)
      ..remove(first.id)
      ..remove(second.id)
      ..[merged.id] = merged;
    final topology = SpaceBoundaryTopology(
      spaceId: spaceId,
      orderedEdgeIds: ordered,
      edges: edges,
    );
    final lineage = BoundaryTopologyChangeSet([
      for (final id in _source.orderedEdgeIds)
        if (id != first.id && id != second.id)
          BoundaryEdgeLineage.preserved(id),
      BoundaryEdgeLineage.merged(
        sourceEdgeIds: [first.id, second.id],
        resultEdgeId: merged.id,
      ),
    ]);
    final profiles = _sourceProfiles.merge(
      spaceId: spaceId,
      firstSourceEdge: first,
      secondSourceEdge: second,
      resultEdgeId: merged.id,
    );
    return previewReplaceTopology(
      topology: topology,
      lineage: lineage,
      wallProfiles: profiles,
    );
  }

  /// General P7A-5 topology replacement used by create/remove-capable tools.
  /// Every pre-mutation and post-mutation edge must participate in lineage.
  BoundaryTopologyMigrationPreview previewReplaceTopology({
    required SpaceBoundaryTopology topology,
    required BoundaryTopologyChangeSet lineage,
    BoundaryWallProfileRegistry? wallProfiles,
  }) {
    _requireCurrentVersion();
    if (topology.spaceId != spaceId) {
      throw ArgumentError('Topology migration cannot change Space owner.');
    }
    topology.validateOrThrow();
    BoundaryGeometryIntegrity.validateOrThrow(topology);
    _requireLineageCoverage(_source, topology, lineage);

    final remapped = _sourceRegistry.remapSpace(
      before: _source,
      after: topology,
      lineage: lineage,
    );
    final profiles = wallProfiles ?? _sourceProfiles;
    _previewTopology = topology;
    _previewRegistry = remapped;
    _previewProfiles = profiles;
    _lineage = lineage;
    return BoundaryTopologyMigrationPreview(
      topology: topology,
      lineage: lineage,
      hostedObjects: remapped,
      wallProfiles: profiles,
    );
  }

  void cancel() {
    _previewTopology = _source;
    _previewRegistry = _sourceRegistry;
    _previewProfiles = _sourceProfiles;
    _lineage = null;
  }

  BoundaryTopologyMigrationCommit? commit() {
    _requireCurrentVersion();
    final lineage = _lineage;
    if (lineage == null) return null;
    final result = _mutations.commit(
      ProjectMutationRequest(
        expectedVersion: expectedVersion,
        command: _ReplaceBoundaryTopologyWithHostsCommand(
          spaceId: spaceId,
          topology: _previewTopology,
          hostedObjects: _previewRegistry,
          wallProfiles: _previewProfiles,
        ),
      ),
    );
    if (result == null) return null;
    return BoundaryTopologyMigrationCommit(mutation: result, lineage: lineage);
  }

  void _requireCurrentVersion() {
    final current = _mutations.current.version;
    if (current != expectedVersion) {
      throw StaleProjectMutationException(
        expectedVersion: expectedVersion,
        currentVersion: current,
      );
    }
  }
}

final class _ReplaceBoundaryTopologyWithHostsCommand implements ProjectCommand {
  const _ReplaceBoundaryTopologyWithHostsCommand({
    required this.spaceId,
    required this.topology,
    required this.hostedObjects,
    required this.wallProfiles,
  });

  final SpaceId spaceId;
  final SpaceBoundaryTopology topology;
  final BoundaryHostedObjectRegistry hostedObjects;
  final BoundaryWallProfileRegistry wallProfiles;

  @override
  String get commandType => 'p7a.migrateBoundaryTopologyAndHosts';

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) {
    final before = current.index.boundary(spaceId);
    if (before == null) {
      throw BoundaryTopologyMigrationException(
        code: BoundaryTopologyMigrationIssueCode.topologyMissing,
        message: 'Canonical Space $spaceId no longer owns boundary topology.',
      );
    }
    topology.validateOrThrow();
    BoundaryGeometryIntegrity.validateOrThrow(topology);

    final stores = current.stores;
    final boundaries = <SpaceId, SpaceBoundaryTopology>{
      ...stores.boundaries,
      spaceId: topology,
    };
    hostedObjects.validateAgainst(boundaries);
    wallProfiles.validateAgainst(boundaries);
    final metadata = current.engineeringMetadata
        .withBoundaryHostedObjectRegistry(hostedObjects)
        .withBoundaryWallProfileRegistry(wallProfiles);
    return ProjectCommandCandidate.fromState(
      state: ProjectMutableState(
        engineeringMetadata: metadata,
        stores: ProjectEntityStores(
          sites: stores.sites,
          buildings: stores.buildings,
          levels: stores.levels,
          zones: stores.zones,
          spaces: stores.spaces,
          openings: stores.openings,
          adjacencies: stores.adjacencies,
          overlays: stores.overlays,
          boundaries: boundaries,
        ),
      ),
      affectedEntityIds: <EntityId>{
        spaceId,
        ...before.orderedEdgeIds,
        ...topology.orderedEdgeIds,
      },
    );
  }
}

void _requireLineageCoverage(
  SpaceBoundaryTopology before,
  SpaceBoundaryTopology after,
  BoundaryTopologyChangeSet lineage,
) {
  final sourceIds = <BoundaryEdgeId>{
    for (final record in lineage.lineage) ...record.sourceEdgeIds,
  };
  final resultIds = <BoundaryEdgeId>{
    for (final record in lineage.lineage) ...record.resultEdgeIds,
  };
  final beforeIds = before.edges.keys.toSet();
  final afterIds = after.edges.keys.toSet();
  if (sourceIds.length != beforeIds.length ||
      !sourceIds.containsAll(beforeIds)) {
    throw const BoundaryTopologyMigrationException(
      code: BoundaryTopologyMigrationIssueCode.lineageSourceCoverageMismatch,
      message: 'Lineage must cover every pre-mutation boundary edge exactly.',
    );
  }
  if (resultIds.length != afterIds.length || !resultIds.containsAll(afterIds)) {
    throw const BoundaryTopologyMigrationException(
      code: BoundaryTopologyMigrationIssueCode.lineageResultCoverageMismatch,
      message: 'Lineage must cover every result boundary edge exactly.',
    );
  }
}

bool _pointOnSegment(ProjectBoundaryEdge edge, BoundaryPointMm point) {
  final dx = edge.end.xMm - edge.start.xMm;
  final dy = edge.end.yMm - edge.start.yMm;
  final px = point.xMm - edge.start.xMm;
  final py = point.yMm - edge.start.yMm;
  if (dx * py - dy * px != 0) return false;
  final dot = px * dx + py * dy;
  final lengthSquared = dx * dx + dy * dy;
  return dot > 0 && dot < lengthSquared;
}
