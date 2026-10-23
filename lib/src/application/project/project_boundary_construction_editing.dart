import '../../domain/boundary_construction_registry.dart';
import '../../domain/boundary_host_migration.dart';
import '../../domain/project_aggregate.dart';
import '../../domain/project_identity.dart';
import 'project_mutation.dart';

/// Canonical application boundary for authoring physical wall construction.
///
/// Thickness/material changes are root engineering metadata mutations. They
/// participate in LocalProjectVersion, undo/redo and persistence exactly like
/// Project North and canonical wall-host metadata.
final class ProjectBoundaryConstructionEditingService {
  const ProjectBoundaryConstructionEditingService(this._mutations);

  final ProjectMutationSession _mutations;

  ProjectMutationResult? setWallConstruction({
    required SpaceId spaceId,
    required BoundaryEdgeId edgeId,
    required BoundaryConstructionProfile profile,
    required LocalProjectVersion expectedVersion,
  }) {
    if (profile.kind != BoundaryConstructionKind.wall) {
      throw ArgumentError('BoundaryEdgeId construction must be a wall.');
    }
    return _mutations.commit(
      ProjectMutationRequest(
        expectedVersion: expectedVersion,
        command: _SetBoundaryConstructionCommand(
          spaceId: spaceId,
          edgeId: edgeId,
          profile: profile,
        ),
      ),
    );
  }

  ProjectMutationResult? clearWallConstruction({
    required SpaceId spaceId,
    required BoundaryEdgeId edgeId,
    required LocalProjectVersion expectedVersion,
  }) =>
      _mutations.commit(
        ProjectMutationRequest(
          expectedVersion: expectedVersion,
          command: _ClearBoundaryConstructionCommand(
            spaceId: spaceId,
            edgeId: edgeId,
          ),
        ),
      );
}

final class _SetBoundaryConstructionCommand implements ProjectCommand {
  const _SetBoundaryConstructionCommand({
    required this.spaceId,
    required this.edgeId,
    required this.profile,
  });

  final SpaceId spaceId;
  final BoundaryEdgeId edgeId;
  final BoundaryConstructionProfile profile;

  @override
  String get commandType => 'p7b.setBoundaryConstruction';

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) {
    _requireActiveOwnedEdge(current, spaceId, edgeId);
    final host = BoundaryEdgeHostRef(spaceId: spaceId, edgeId: edgeId);
    final registry = current.engineeringMetadata.boundaryConstructionRegistry;
    if (registry[host] == profile) {
      return ProjectCommandCandidate.fromState(
        state: ProjectMutableState.fromProject(current),
      );
    }
    return ProjectCommandCandidate.fromState(
      state: ProjectMutableState(
        engineeringMetadata: current.engineeringMetadata
            .withBoundaryConstructionRegistry(registry.put(host, profile)),
        stores: current.stores,
      ),
      affectedEntityIds: {spaceId, edgeId},
    );
  }
}

final class _ClearBoundaryConstructionCommand implements ProjectCommand {
  const _ClearBoundaryConstructionCommand({
    required this.spaceId,
    required this.edgeId,
  });

  final SpaceId spaceId;
  final BoundaryEdgeId edgeId;

  @override
  String get commandType => 'p7b.clearBoundaryConstruction';

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) {
    _requireActiveOwnedEdge(current, spaceId, edgeId);
    final host = BoundaryEdgeHostRef(spaceId: spaceId, edgeId: edgeId);
    final registry = current.engineeringMetadata.boundaryConstructionRegistry;
    if (registry[host] == null) {
      return ProjectCommandCandidate.fromState(
        state: ProjectMutableState.fromProject(current),
      );
    }
    return ProjectCommandCandidate.fromState(
      state: ProjectMutableState(
        engineeringMetadata: current.engineeringMetadata
            .withBoundaryConstructionRegistry(registry.remove(host)),
        stores: current.stores,
      ),
      affectedEntityIds: {spaceId, edgeId},
    );
  }
}

void _requireActiveOwnedEdge(
  ProjectAggregateRoot project,
  SpaceId spaceId,
  BoundaryEdgeId edgeId,
) {
  final topology = project.index.boundary(spaceId);
  final edge = topology?.edges[edgeId];
  if (topology == null || edge == null || edge.spaceId != spaceId) {
    throw StateError(
      'Boundary edge $edgeId is not active and owned by Space $spaceId.',
    );
  }
}
