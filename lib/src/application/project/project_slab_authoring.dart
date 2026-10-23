import '../../domain/boundary_topology.dart';
import '../../domain/project_aggregate.dart';
import '../../domain/project_identity.dart';
import '../../domain/slab_topology.dart';
import 'project_mutation.dart';
import 'project_slab_commands.dart';

final class CreateSlabRequest {
  const CreateSlabRequest({
    required this.buildingId,
    required this.kind,
    required this.bottomElevationMm,
    required this.thicknessMm,
    required this.materialId,
    required this.footprint,
    this.belowLevelId,
    this.aboveLevelId,
  });

  final BuildingId buildingId;
  final SlabKind kind;
  final LevelId? belowLevelId;
  final LevelId? aboveLevelId;
  final int bottomElevationMm;
  final int thicknessMm;
  final String materialId;
  final List<BoundaryPointMm> footprint;
}

final class UpdateSlabRequest {
  const UpdateSlabRequest({
    required this.slabId,
    required this.buildingId,
    required this.kind,
    required this.bottomElevationMm,
    required this.thicknessMm,
    required this.materialId,
    required this.footprint,
    this.belowLevelId,
    this.aboveLevelId,
  });

  final SlabId slabId;
  final BuildingId buildingId;
  final SlabKind kind;
  final LevelId? belowLevelId;
  final LevelId? aboveLevelId;
  final int bottomElevationMm;
  final int thicknessMm;
  final String materialId;
  final List<BoundaryPointMm> footprint;
}

final class ProjectSlabAuthoringResult {
  const ProjectSlabAuthoringResult({
    required this.slabId,
    required this.project,
    required this.changeSet,
  });

  final SlabId slabId;
  final ProjectAggregateRoot project;
  final ProjectChangeSet changeSet;
}

/// Application boundary for canonical physical slab ownership.
///
/// Identity allocation and mutation commit share the same project session used
/// by the rest of structure authoring. All stale-version, graph validation and
/// undo/redo semantics therefore remain centralized in [ProjectMutationSession].
final class ProjectSlabAuthoringSession {
  const ProjectSlabAuthoringSession({
    required ProjectMutationSession mutations,
    required EntityIdFactory idFactory,
  })  : _mutations = mutations,
        _idFactory = idFactory;

  final ProjectMutationSession _mutations;
  final EntityIdFactory _idFactory;

  ProjectAggregateRoot get project => _mutations.current;

  ProjectSlabAuthoringResult create(
    CreateSlabRequest input, {
    LocalProjectVersion? expectedVersion,
  }) {
    final id = _idFactory.newSlabId();
    final slab = ProjectSlab(
      id: id,
      buildingId: input.buildingId,
      kind: input.kind,
      belowLevelId: input.belowLevelId,
      aboveLevelId: input.aboveLevelId,
      bottomElevationMm: input.bottomElevationMm,
      thicknessMm: input.thicknessMm,
      materialId: input.materialId,
      footprint: input.footprint,
    );
    final result = _requireCommit(
      _mutations.commit(
        ProjectMutationRequest(
          expectedVersion: expectedVersion ?? project.version,
          command: CreateSlabCommand(slab: slab),
        ),
      ),
      'project.slab.create',
    );
    return ProjectSlabAuthoringResult(
      slabId: id,
      project: result.project,
      changeSet: result.changeSet,
    );
  }

  ProjectSlabAuthoringResult update(
    UpdateSlabRequest input, {
    LocalProjectVersion? expectedVersion,
  }) {
    final slab = ProjectSlab(
      id: input.slabId,
      buildingId: input.buildingId,
      kind: input.kind,
      belowLevelId: input.belowLevelId,
      aboveLevelId: input.aboveLevelId,
      bottomElevationMm: input.bottomElevationMm,
      thicknessMm: input.thicknessMm,
      materialId: input.materialId,
      footprint: input.footprint,
    );
    final result = _requireCommit(
      _mutations.commit(
        ProjectMutationRequest(
          expectedVersion: expectedVersion ?? project.version,
          command: UpdateSlabCommand(slab: slab),
        ),
      ),
      'project.slab.update',
    );
    return ProjectSlabAuthoringResult(
      slabId: slab.id,
      project: result.project,
      changeSet: result.changeSet,
    );
  }

  ProjectSlabAuthoringResult remove(
    SlabId slabId, {
    LocalProjectVersion? expectedVersion,
  }) {
    final result = _requireCommit(
      _mutations.commit(
        ProjectMutationRequest(
          expectedVersion: expectedVersion ?? project.version,
          command: RemoveSlabCommand(slabId: slabId),
        ),
      ),
      'project.slab.remove',
    );
    return ProjectSlabAuthoringResult(
      slabId: slabId,
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
