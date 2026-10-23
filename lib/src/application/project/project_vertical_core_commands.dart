import '../../domain/project_aggregate.dart';
import '../../domain/project_entity_stores_copy.dart';
import '../../domain/project_identity.dart';
import '../../domain/vertical_core.dart';
import 'project_authoring_error.dart';
import 'project_mutation.dart';

/// Creates one stable building-scoped vertical routing volume.
final class CreateVerticalCoreCommand implements ProjectCommand {
  const CreateVerticalCoreCommand({required this.verticalCore});

  final ProjectVerticalCore verticalCore;

  @override
  String get commandType => 'project.verticalCore.create';

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) {
    if (current.stores.verticalCores.containsKey(verticalCore.id)) {
      throw ProjectAuthoringException(
        code: ProjectAuthoringIssueCode.verticalCoreAlreadyExists,
        entityId: verticalCore.id,
        message: 'Vertical core ${verticalCore.id} already exists.',
      );
    }
    final verticalCores =
        Map<VerticalCoreId, ProjectVerticalCore>.from(current.stores.verticalCores)
          ..[verticalCore.id] = verticalCore;
    return ProjectCommandCandidate.fromState(
      state: ProjectMutableState(
        engineeringMetadata: current.engineeringMetadata,
        stores: current.stores.copyWith(verticalCores: verticalCores),
      ),
      affectedEntityIds: <EntityId>{
        verticalCore.id,
        verticalCore.buildingId,
        ...verticalCore.levelIds,
      },
    );
  }
}

/// Replaces one existing core while preserving its stable [VerticalCoreId].
final class UpdateVerticalCoreCommand implements ProjectCommand {
  const UpdateVerticalCoreCommand({required this.verticalCore});

  final ProjectVerticalCore verticalCore;

  @override
  String get commandType => 'project.verticalCore.update';

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) {
    final before = current.index.verticalCore(verticalCore.id);
    if (before == null) {
      throw ProjectAuthoringException(
        code: ProjectAuthoringIssueCode.verticalCoreNotFound,
        entityId: verticalCore.id,
        message: 'Vertical core ${verticalCore.id} does not exist.',
      );
    }
    final verticalCores =
        Map<VerticalCoreId, ProjectVerticalCore>.from(current.stores.verticalCores)
          ..[verticalCore.id] = verticalCore;
    return ProjectCommandCandidate.fromState(
      state: ProjectMutableState(
        engineeringMetadata: current.engineeringMetadata,
        stores: current.stores.copyWith(verticalCores: verticalCores),
      ),
      affectedEntityIds: <EntityId>{
        verticalCore.id,
        before.buildingId,
        verticalCore.buildingId,
        ...before.levelIds,
        ...verticalCore.levelIds,
      },
    );
  }
}

/// Removes one core definition without deleting its levels or slabs.
final class RemoveVerticalCoreCommand implements ProjectCommand {
  const RemoveVerticalCoreCommand({required this.verticalCoreId});

  final VerticalCoreId verticalCoreId;

  @override
  String get commandType => 'project.verticalCore.remove';

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) {
    final core = current.index.verticalCore(verticalCoreId);
    if (core == null) {
      throw ProjectAuthoringException(
        code: ProjectAuthoringIssueCode.verticalCoreNotFound,
        entityId: verticalCoreId,
        message: 'Vertical core $verticalCoreId does not exist.',
      );
    }
    final verticalCores =
        Map<VerticalCoreId, ProjectVerticalCore>.from(current.stores.verticalCores)
          ..remove(core.id);
    return ProjectCommandCandidate.fromState(
      state: ProjectMutableState(
        engineeringMetadata: current.engineeringMetadata,
        stores: current.stores.copyWith(verticalCores: verticalCores),
      ),
      affectedEntityIds: <EntityId>{
        core.id,
        core.buildingId,
        ...core.levelIds,
      },
    );
  }
}
