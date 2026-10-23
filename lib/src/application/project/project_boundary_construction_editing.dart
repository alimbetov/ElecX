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
  }) =>
      setWallConstructions(
        profiles: {
          BoundaryEdgeHostRef(spaceId: spaceId, edgeId: edgeId): profile,
        },
        expectedVersion: expectedVersion,
      );

  /// Commits one physical-construction change spanning every explicitly known
  /// face of the same wall as one canonical transaction.
  ///
  /// Production routing uses this when an existing penetration proves that two
  /// BoundaryEdgeId hosts represent opposite faces of one physical wall. The
  /// caller decides that relationship; this service never guesses adjacency
  /// from coincident geometry.
  ProjectMutationResult? setWallConstructions({
    required Map<BoundaryEdgeHostRef, BoundaryConstructionProfile> profiles,
    required LocalProjectVersion expectedVersion,
  }) {
    if (profiles.isEmpty) return null;
    for (final entry in profiles.entries) {
      if (entry.value.kind != BoundaryConstructionKind.wall) {
        throw ArgumentError(
          'BoundaryEdgeId construction ${entry.key.edgeId} must be a wall.',
        );
      }
    }
    return _mutations.commit(
      ProjectMutationRequest(
        expectedVersion: expectedVersion,
        command: _SetBoundaryConstructionsCommand(profiles),
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

final class _SetBoundaryConstructionsCommand implements ProjectCommand {
  _SetBoundaryConstructionsCommand(
    Map<BoundaryEdgeHostRef, BoundaryConstructionProfile> profiles,
  ) : profiles = Map.unmodifiable(profiles);

  final Map<BoundaryEdgeHostRef, BoundaryConstructionProfile> profiles;

  @override
  String get commandType => 'p7b.setBoundaryConstruction';

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) {
    var registry = current.engineeringMetadata.boundaryConstructionRegistry;
    var changed = false;
    final affected = <EntityId>{};
    for (final entry in profiles.entries) {
      _requireActiveOwnedEdge(current, entry.key.spaceId, entry.key.edgeId);
      affected
        ..add(entry.key.spaceId)
        ..add(entry.key.edgeId);
      if (registry[entry.key] == entry.value) continue;
      registry = registry.put(entry.key, entry.value);
      changed = true;
    }
    if (!changed) {
      return ProjectCommandCandidate.fromState(
        state: ProjectMutableState.fromProject(current),
      );
    }
    return ProjectCommandCandidate.fromState(
      state: ProjectMutableState(
        engineeringMetadata: current.engineeringMetadata
            .withBoundaryConstructionRegistry(registry),
        stores: current.stores,
      ),
      affectedEntityIds: affected,
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
