import '../../domain/boundary_topology.dart';
import '../../domain/project_aggregate.dart';
import '../../domain/project_identity.dart';
import '../../domain/vertical_core.dart';
import 'project_mutation.dart';
import 'project_vertical_core_commands.dart';

final class CreateVerticalCoreRequest {
  const CreateVerticalCoreRequest({
    required this.buildingId,
    required this.kind,
    required this.levelIds,
    required this.footprint,
    this.name,
  });

  final BuildingId buildingId;
  final VerticalCoreKind kind;
  final Set<LevelId> levelIds;
  final List<BoundaryPointMm> footprint;
  final String? name;
}

final class UpdateVerticalCoreRequest {
  const UpdateVerticalCoreRequest({
    required this.verticalCoreId,
    required this.buildingId,
    required this.kind,
    required this.levelIds,
    required this.footprint,
    this.name,
  });

  final VerticalCoreId verticalCoreId;
  final BuildingId buildingId;
  final VerticalCoreKind kind;
  final Set<LevelId> levelIds;
  final List<BoundaryPointMm> footprint;
  final String? name;
}

final class ProjectVerticalCoreAuthoringResult {
  const ProjectVerticalCoreAuthoringResult({
    required this.verticalCoreId,
    required this.project,
    required this.changeSet,
  });

  final VerticalCoreId verticalCoreId;
  final ProjectAggregateRoot project;
  final ProjectChangeSet changeSet;
}

/// Application boundary for stable riser/shaft ownership.
///
/// The session shares [ProjectMutationSession] with structure/slab authoring,
/// therefore create/update/remove participate in one canonical version stream
/// and the same undo/redo history.
final class ProjectVerticalCoreAuthoringSession {
  const ProjectVerticalCoreAuthoringSession({
    required ProjectMutationSession mutations,
    required EntityIdFactory idFactory,
  })  : _mutations = mutations,
        _idFactory = idFactory;

  final ProjectMutationSession _mutations;
  final EntityIdFactory _idFactory;

  ProjectAggregateRoot get project => _mutations.current;

  ProjectVerticalCoreAuthoringResult create(
    CreateVerticalCoreRequest input, {
    LocalProjectVersion? expectedVersion,
  }) {
    final id = _idFactory.newVerticalCoreId();
    final core = ProjectVerticalCore(
      id: id,
      buildingId: input.buildingId,
      kind: input.kind,
      levelIds: input.levelIds,
      footprint: input.footprint,
      name: input.name,
    );
    final result = _requireCommit(
      _mutations.commit(
        ProjectMutationRequest(
          expectedVersion: expectedVersion ?? project.version,
          command: CreateVerticalCoreCommand(verticalCore: core),
        ),
      ),
      'project.verticalCore.create',
    );
    return ProjectVerticalCoreAuthoringResult(
      verticalCoreId: id,
      project: result.project,
      changeSet: result.changeSet,
    );
  }

  ProjectVerticalCoreAuthoringResult update(
    UpdateVerticalCoreRequest input, {
    LocalProjectVersion? expectedVersion,
  }) {
    final core = ProjectVerticalCore(
      id: input.verticalCoreId,
      buildingId: input.buildingId,
      kind: input.kind,
      levelIds: input.levelIds,
      footprint: input.footprint,
      name: input.name,
    );
    final result = _requireCommit(
      _mutations.commit(
        ProjectMutationRequest(
          expectedVersion: expectedVersion ?? project.version,
          command: UpdateVerticalCoreCommand(verticalCore: core),
        ),
      ),
      'project.verticalCore.update',
    );
    return ProjectVerticalCoreAuthoringResult(
      verticalCoreId: core.id,
      project: result.project,
      changeSet: result.changeSet,
    );
  }

  ProjectVerticalCoreAuthoringResult remove(
    VerticalCoreId verticalCoreId, {
    LocalProjectVersion? expectedVersion,
  }) {
    final result = _requireCommit(
      _mutations.commit(
        ProjectMutationRequest(
          expectedVersion: expectedVersion ?? project.version,
          command: RemoveVerticalCoreCommand(verticalCoreId: verticalCoreId),
        ),
      ),
      'project.verticalCore.remove',
    );
    return ProjectVerticalCoreAuthoringResult(
      verticalCoreId: verticalCoreId,
      project: result.project,
      changeSet: result.changeSet,
    );
  }

  ProjectMutationResult _requireCommit(
    ProjectMutationResult? result,
    String commandType,
  ) {
    if (result == null) {
      throw StateError('$commandType unexpectedly produced an empty mutation.');
    }
    return result;
  }
}
