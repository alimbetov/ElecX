import '../../domain/project_aggregate.dart';
import '../../domain/project_entity_stores_copy.dart';
import '../../domain/project_identity.dart';
import '../../domain/slab_topology.dart';
import 'project_authoring_error.dart';
import 'project_mutation.dart';

/// Creates one physical slab as a canonical project entity.
final class CreateSlabCommand implements ProjectCommand {
  const CreateSlabCommand({required this.slab});

  final ProjectSlab slab;

  @override
  String get commandType => 'project.slab.create';

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) {
    if (current.stores.slabs.containsKey(slab.id)) {
      throw ProjectAuthoringException(
        code: ProjectAuthoringIssueCode.slabAlreadyExists,
        entityId: slab.id,
        message: 'Slab ${slab.id} already exists.',
      );
    }
    final slabs = Map<SlabId, ProjectSlab>.from(current.stores.slabs)
      ..[slab.id] = slab;
    return ProjectCommandCandidate.fromState(
      state: ProjectMutableState(
        engineeringMetadata: current.engineeringMetadata,
        stores: current.stores.copyWith(slabs: slabs),
      ),
      affectedEntityIds: <EntityId>[
        slab.id,
        slab.buildingId,
        if (slab.belowLevelId != null) slab.belowLevelId!,
        if (slab.aboveLevelId != null) slab.aboveLevelId!,
      ],
    );
  }
}

/// Replaces the complete physical definition of one existing slab while
/// preserving [SlabId]. Referential and topology invariants are enforced by the
/// canonical aggregate validator before commit.
final class UpdateSlabCommand implements ProjectCommand {
  const UpdateSlabCommand({required this.slab});

  final ProjectSlab slab;

  @override
  String get commandType => 'project.slab.update';

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) {
    final before = current.index.slab(slab.id);
    if (before == null) {
      throw ProjectAuthoringException(
        code: ProjectAuthoringIssueCode.slabNotFound,
        entityId: slab.id,
        message: 'Slab ${slab.id} does not exist.',
      );
    }
    final slabs = Map<SlabId, ProjectSlab>.from(current.stores.slabs)
      ..[slab.id] = slab;
    return ProjectCommandCandidate.fromState(
      state: ProjectMutableState(
        engineeringMetadata: current.engineeringMetadata,
        stores: current.stores.copyWith(slabs: slabs),
      ),
      affectedEntityIds: <EntityId>{
        slab.id,
        before.buildingId,
        slab.buildingId,
        if (before.belowLevelId != null) before.belowLevelId!,
        if (before.aboveLevelId != null) before.aboveLevelId!,
        if (slab.belowLevelId != null) slab.belowLevelId!,
        if (slab.aboveLevelId != null) slab.aboveLevelId!,
      },
    );
  }
}

/// Removes one physical slab. Level/building entities are deliberately not
/// cascaded; removing the slab only releases their physical-boundary blocker.
final class RemoveSlabCommand implements ProjectCommand {
  const RemoveSlabCommand({required this.slabId});

  final SlabId slabId;

  @override
  String get commandType => 'project.slab.remove';

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) {
    final slab = current.index.slab(slabId);
    if (slab == null) {
      throw ProjectAuthoringException(
        code: ProjectAuthoringIssueCode.slabNotFound,
        entityId: slabId,
        message: 'Slab $slabId does not exist.',
      );
    }
    final slabs = Map<SlabId, ProjectSlab>.from(current.stores.slabs)
      ..remove(slab.id);
    return ProjectCommandCandidate.fromState(
      state: ProjectMutableState(
        engineeringMetadata: current.engineeringMetadata,
        stores: current.stores.copyWith(slabs: slabs),
      ),
      affectedEntityIds: <EntityId>[
        slab.id,
        slab.buildingId,
        if (slab.belowLevelId != null) slab.belowLevelId!,
        if (slab.aboveLevelId != null) slab.aboveLevelId!,
      ],
    );
  }
}
