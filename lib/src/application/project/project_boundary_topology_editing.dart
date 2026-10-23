import 'dart:math' as math;

import '../../domain/boundary_geometry_integrity.dart';
import '../../domain/boundary_topology.dart';
import '../../domain/project_aggregate.dart';
import '../../domain/project_entity_stores_copy.dart';
import '../../domain/project_identity.dart';
import 'project_mutation.dart';

/// P7A-4.5 application boundary for topology-preserving boundary edits.
///
/// Pointer devices, touch, stylus and keyboard must normalize their interaction
/// into these millimetre-domain operations. This layer never accepts wall
/// ordinals, Flutter offsets or platform pointer identities.
abstract interface class ProjectBoundaryTopologyEditingPort {
  CanonicalBoundaryTopologyEditSession begin({
    required SpaceId spaceId,
    required LocalProjectVersion expectedVersion,
  });
}

final class ProjectBoundaryTopologyEditingService
    implements ProjectBoundaryTopologyEditingPort {
  const ProjectBoundaryTopologyEditingService(this._mutations);

  final ProjectMutationSession _mutations;

  @override
  CanonicalBoundaryTopologyEditSession begin({
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
    final space = current.index.space(spaceId);
    if (space == null) {
      throw BoundaryTopologyEditingException(
        code: BoundaryTopologyEditingIssueCode.spaceNotFound,
        spaceId: spaceId,
        message: 'Canonical Space $spaceId does not exist.',
      );
    }
    final topology = current.index.boundary(spaceId);
    if (topology == null) {
      throw BoundaryTopologyEditingException(
        code: BoundaryTopologyEditingIssueCode.topologyMissing,
        spaceId: spaceId,
        message: 'Canonical Space $spaceId has no boundary topology.',
      );
    }
    topology.validateOrThrow();
    BoundaryGeometryIntegrity.validateOrThrow(topology);
    return CanonicalBoundaryTopologyEditSession._(
      mutations: _mutations,
      spaceId: spaceId,
      expectedVersion: expectedVersion,
      source: topology,
    );
  }
}

enum BoundaryTopologyEditingIssueCode {
  spaceNotFound,
  topologyMissing,
  edgeNotFound,
  geometryTooShort,
  identityChangingEditRequiresHostMigration,
}

final class BoundaryTopologyEditingException implements Exception {
  const BoundaryTopologyEditingException({
    required this.code,
    required this.spaceId,
    required this.message,
    this.edgeId,
  });

  final BoundaryTopologyEditingIssueCode code;
  final SpaceId spaceId;
  final BoundaryEdgeId? edgeId;
  final String message;

  @override
  String toString() => '${code.name}: $message';
}

final class BoundaryTopologyEditPreview {
  const BoundaryTopologyEditPreview({
    required this.expectedVersion,
    required this.spaceId,
    required this.topology,
    required this.lineage,
  });

  final LocalProjectVersion expectedVersion;
  final SpaceId spaceId;
  final SpaceBoundaryTopology topology;
  final BoundaryTopologyChangeSet lineage;
}

final class BoundaryTopologyEditCommit {
  const BoundaryTopologyEditCommit({
    required this.mutation,
    required this.lineage,
  });

  final ProjectMutationResult mutation;
  final BoundaryTopologyChangeSet lineage;
}

/// One canonical edit transaction: begin -> preview -> validate -> commit/cancel.
///
/// P7A-4.5 deliberately permits topology-preserving geometry edits only. Edge
/// split/merge/create/remove already have explicit lineage semantics in the
/// domain, but committing those operations is fail-closed until P7A-5 can
/// migrate every hosted object atomically.
final class CanonicalBoundaryTopologyEditSession {
  CanonicalBoundaryTopologyEditSession._({
    required ProjectMutationSession mutations,
    required this.spaceId,
    required this.expectedVersion,
    required SpaceBoundaryTopology source,
  })  : _mutations = mutations,
        _source = source,
        _preview = source;

  static const int minimumEdgeLengthMm = 300;

  final ProjectMutationSession _mutations;
  final SpaceId spaceId;
  final LocalProjectVersion expectedVersion;
  final SpaceBoundaryTopology _source;
  SpaceBoundaryTopology _preview;

  SpaceBoundaryTopology get source => _source;
  SpaceBoundaryTopology get previewTopology => _preview;
  bool get dirty => !_sameTopology(_source, _preview);

  BoundaryTopologyEditPreview previewMoveVertex({
    required BoundaryEdgeId outgoingEdgeId,
    required BoundaryPointMm target,
  }) {
    _requireCurrentVersion();
    final index = _preview.orderedEdgeIds.indexOf(outgoingEdgeId);
    if (index < 0) {
      throw BoundaryTopologyEditingException(
        code: BoundaryTopologyEditingIssueCode.edgeNotFound,
        spaceId: spaceId,
        edgeId: outgoingEdgeId,
        message: 'Outgoing boundary edge $outgoingEdgeId does not exist in '
            'Space $spaceId.',
      );
    }
    final vertices = _vertices(_preview);
    vertices[index] = target;
    _preview = _buildPreservingIdentity(vertices);
    return _previewResult();
  }

  BoundaryTopologyEditPreview previewMoveEdgeNormal({
    required BoundaryEdgeId edgeId,
    required int distanceMm,
  }) {
    _requireCurrentVersion();
    final index = _preview.orderedEdgeIds.indexOf(edgeId);
    if (index < 0) {
      throw BoundaryTopologyEditingException(
        code: BoundaryTopologyEditingIssueCode.edgeNotFound,
        spaceId: spaceId,
        edgeId: edgeId,
        message: 'Boundary edge $edgeId does not exist in Space $spaceId.',
      );
    }
    if (distanceMm == 0) return _previewResult();

    final vertices = _vertices(_preview);
    final a = vertices[index];
    final nextIndex = (index + 1) % vertices.length;
    final b = vertices[nextIndex];
    final dx = (b.xMm - a.xMm).toDouble();
    final dy = (b.yMm - a.yMm).toDouble();
    final length = math.sqrt(dx * dx + dy * dy);
    if (length == 0) {
      throw BoundaryTopologyEditingException(
        code: BoundaryTopologyEditingIssueCode.geometryTooShort,
        spaceId: spaceId,
        edgeId: edgeId,
        message: 'Boundary edge $edgeId has zero length.',
      );
    }

    final offsetX = (-dy / length * distanceMm).round();
    final offsetY = (dx / length * distanceMm).round();
    vertices[index] = BoundaryPointMm(
      xMm: a.xMm + offsetX,
      yMm: a.yMm + offsetY,
    );
    vertices[nextIndex] = BoundaryPointMm(
      xMm: b.xMm + offsetX,
      yMm: b.yMm + offsetY,
    );
    _preview = _buildPreservingIdentity(vertices);
    return _previewResult();
  }

  void cancel() {
    _preview = _source;
  }

  BoundaryTopologyEditCommit? commit() {
    _requireCurrentVersion();
    if (!dirty) return null;
    final lineage = _preservedLineage(_preview);
    final command = _ReplaceBoundaryTopologyCommand(
      spaceId: spaceId,
      topology: _preview,
    );
    final result = _mutations.commit(
      ProjectMutationRequest(
        expectedVersion: expectedVersion,
        command: command,
      ),
    );
    if (result == null) return null;
    return BoundaryTopologyEditCommit(mutation: result, lineage: lineage);
  }

  BoundaryTopologyEditPreview _previewResult() => BoundaryTopologyEditPreview(
        expectedVersion: expectedVersion,
        spaceId: spaceId,
        topology: _preview,
        lineage: _preservedLineage(_preview),
      );

  SpaceBoundaryTopology _buildPreservingIdentity(
    List<BoundaryPointMm> vertices,
  ) {
    final ids = _preview.orderedEdgeIds;
    final edges = <BoundaryEdgeId, ProjectBoundaryEdge>{
      for (var index = 0; index < ids.length; index++)
        ids[index]: ProjectBoundaryEdge(
          id: ids[index],
          spaceId: spaceId,
          start: vertices[index],
          end: vertices[(index + 1) % vertices.length],
        ),
    };
    final candidate = SpaceBoundaryTopology(
      spaceId: spaceId,
      orderedEdgeIds: ids,
      edges: edges,
    );
    candidate.validateOrThrow();
    BoundaryGeometryIntegrity.validateOrThrow(candidate);
    _requireMinimumEdgeLength(candidate);
    return candidate;
  }

  void _requireMinimumEdgeLength(SpaceBoundaryTopology topology) {
    final minimumSquared = minimumEdgeLengthMm * minimumEdgeLengthMm;
    for (final edgeId in topology.orderedEdgeIds) {
      final edge = topology.edges[edgeId]!;
      final dx = edge.end.xMm - edge.start.xMm;
      final dy = edge.end.yMm - edge.start.yMm;
      if (dx * dx + dy * dy < minimumSquared) {
        throw BoundaryTopologyEditingException(
          code: BoundaryTopologyEditingIssueCode.geometryTooShort,
          spaceId: spaceId,
          edgeId: edgeId,
          message: 'Boundary edge $edgeId is shorter than '
              '${minimumEdgeLengthMm}mm.',
        );
      }
    }
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

final class _ReplaceBoundaryTopologyCommand implements ProjectCommand {
  const _ReplaceBoundaryTopologyCommand({
    required this.spaceId,
    required this.topology,
  });

  final SpaceId spaceId;
  final SpaceBoundaryTopology topology;

  @override
  String get commandType => 'p7a.moveBoundaryGeometry';

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) {
    if (current.index.space(spaceId) == null) {
      throw BoundaryTopologyEditingException(
        code: BoundaryTopologyEditingIssueCode.spaceNotFound,
        spaceId: spaceId,
        message: 'Canonical Space $spaceId no longer exists.',
      );
    }
    final currentTopology = current.index.boundary(spaceId);
    if (currentTopology == null) {
      throw BoundaryTopologyEditingException(
        code: BoundaryTopologyEditingIssueCode.topologyMissing,
        spaceId: spaceId,
        message: 'Canonical Space $spaceId no longer owns boundary topology.',
      );
    }
    _requireSameIdentitySet(currentTopology, topology);
    topology.validateOrThrow();
    BoundaryGeometryIntegrity.validateOrThrow(topology);

    return ProjectCommandCandidate.fromState(
      state: ProjectMutableState(
        engineeringMetadata: current.engineeringMetadata,
        stores: current.stores.copyWith(
          boundaries: <SpaceId, SpaceBoundaryTopology>{
            ...current.stores.boundaries,
            spaceId: topology,
          },
        ),
      ),
      affectedEntityIds: <EntityId>{spaceId, ...topology.orderedEdgeIds},
    );
  }
}

void _requireSameIdentitySet(
  SpaceBoundaryTopology before,
  SpaceBoundaryTopology after,
) {
  final sameOrder =
      before.orderedEdgeIds.length == after.orderedEdgeIds.length &&
          List.generate(
            before.orderedEdgeIds.length,
            (index) => index,
          ).every(
            (index) =>
                before.orderedEdgeIds[index] == after.orderedEdgeIds[index],
          );
  final sameIds =
      before.edges.keys.toSet().length == after.edges.keys.toSet().length &&
          before.edges.keys.toSet().containsAll(after.edges.keys);
  if (!sameOrder || !sameIds) {
    throw BoundaryTopologyEditingException(
      code: BoundaryTopologyEditingIssueCode
          .identityChangingEditRequiresHostMigration,
      spaceId: before.spaceId,
      message: 'P7A-4.5 refuses split/merge/create/remove until P7A-5 can '
          'migrate hosted objects atomically.',
    );
  }
}

List<BoundaryPointMm> _vertices(SpaceBoundaryTopology topology) =>
    <BoundaryPointMm>[
      for (final edgeId in topology.orderedEdgeIds)
        topology.edges[edgeId]!.start,
    ];

BoundaryTopologyChangeSet _preservedLineage(
  SpaceBoundaryTopology topology,
) =>
    BoundaryTopologyChangeSet(<BoundaryEdgeLineage>[
      for (final edgeId in topology.orderedEdgeIds)
        BoundaryEdgeLineage.preserved(edgeId),
    ]);

bool _sameTopology(SpaceBoundaryTopology a, SpaceBoundaryTopology b) {
  if (a.spaceId != b.spaceId ||
      a.orderedEdgeIds.length != b.orderedEdgeIds.length) {
    return false;
  }
  for (var i = 0; i < a.orderedEdgeIds.length; i++) {
    if (a.orderedEdgeIds[i] != b.orderedEdgeIds[i]) return false;
    final left = a.edges[a.orderedEdgeIds[i]];
    final right = b.edges[b.orderedEdgeIds[i]];
    if (left == null || right == null) return false;
    if (left.id != right.id ||
        left.spaceId != right.spaceId ||
        left.start != right.start ||
        left.end != right.end) {
      return false;
    }
  }
  return true;
}
