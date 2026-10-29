import '../../domain/physical_level_order.dart';
import '../../domain/project_aggregate.dart';
import '../../domain/project_entity_stores_copy.dart';
import '../../domain/project_identity.dart';
import '../../domain/slab_topology.dart';
import '../../domain/vertical_core.dart';
import '../../domain/vertical_core_continuity_validation.dart';
import '../../domain/vertical_core_project_validation.dart';
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
    _validateProjectOwnershipAndHosts(current, verticalCore);
    _validatePhysicalContinuity(current, verticalCore);
    final verticalCores = Map<VerticalCoreId, ProjectVerticalCore>.from(
        current.stores.verticalCores)
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
        ...verticalCore.hostSpaceIdsByLevel.values,
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
    _validateProjectOwnershipAndHosts(current, verticalCore);
    _validatePhysicalContinuity(current, verticalCore);
    final verticalCores = Map<VerticalCoreId, ProjectVerticalCore>.from(
        current.stores.verticalCores)
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
        ...before.hostSpaceIdsByLevel.values,
        ...verticalCore.hostSpaceIdsByLevel.values,
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
    final verticalCores = Map<VerticalCoreId, ProjectVerticalCore>.from(
        current.stores.verticalCores)
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
        ...core.hostSpaceIdsByLevel.values,
      },
    );
  }
}

void _validateProjectOwnershipAndHosts(
  ProjectAggregateRoot current,
  ProjectVerticalCore verticalCore,
) {
  final issues = VerticalCoreProjectValidator.validate(
    verticalCores: <VerticalCoreId, ProjectVerticalCore>{
      verticalCore.id: verticalCore,
    },
    buildingExists: current.stores.buildings.containsKey,
    levelBuildingResolver: (levelId) =>
        current.stores.levels[levelId]?.buildingId,
    spaceLevelResolver: (spaceId) => current.stores.spaces[spaceId]?.levelId,
  );
  if (issues.isEmpty) return;

  final issue = issues.first;
  throw ProjectAuthoringException(
    code: ProjectAuthoringIssueCode.verticalCoreUnresolvedPhysicalTopology,
    entityId: verticalCore.id,
    relatedEntityId: issue.relatedEntityId,
    blockingEntityIds: {
      if (issue.relatedEntityId case final EntityId id) id,
    },
    message: issue.message,
  );
}

void _validatePhysicalContinuity(
  ProjectAggregateRoot current,
  ProjectVerticalCore verticalCore,
) {
  final issues = VerticalCoreContinuityValidator.validate(
    verticalCores: <VerticalCoreId, ProjectVerticalCore>{
      verticalCore.id: verticalCore,
    },
    buildingLevelIdsResolver: (buildingId) =>
        current.stores.buildings[buildingId]?.levelIds,
    levelPlacementResolver: (levelId) {
      final level = current.stores.levels[levelId];
      if (level == null) return null;
      return PhysicalLevelPlacement(
        levelId: level.id,
        buildingId: level.buildingId,
        elevationMm: level.elevationMm,
      );
    },
    physicalAdjacencyResolver: (buildingId) sync* {
      for (final slab in current.stores.slabs.values) {
        if (slab.buildingId != buildingId || slab.kind != SlabKind.interLevel) {
          continue;
        }
        final below = slab.belowLevelId;
        final above = slab.aboveLevelId;
        if (below == null || above == null) continue;
        yield PhysicalLevelAdjacency(
          buildingId: buildingId,
          belowLevelId: below,
          aboveLevelId: above,
        );
      }
    },
  );
  if (issues.isEmpty) return;

  final issue = issues.first;
  throw ProjectAuthoringException(
    code: switch (issue.code) {
      VerticalCoreContinuityIssueCode.unresolvedPhysicalTopology =>
        ProjectAuthoringIssueCode.verticalCoreUnresolvedPhysicalTopology,
      VerticalCoreContinuityIssueCode.ambiguousPhysicalLevelOrder =>
        ProjectAuthoringIssueCode.verticalCoreAmbiguousPhysicalLevelOrder,
      VerticalCoreContinuityIssueCode.nonContiguousLevelRange =>
        ProjectAuthoringIssueCode.verticalCoreNonContiguousLevelRange,
    },
    entityId: verticalCore.id,
    blockingEntityIds: verticalCore.levelIds,
    message: issue.message,
  );
}
