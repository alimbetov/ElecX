import '../../domain/project_aggregate.dart';
import '../../domain/project_entity_stores_copy.dart';
import '../../domain/project_identity.dart';
import '../../domain/project_space_semantics.dart';
import 'project_authoring_error.dart';
import 'project_mutation.dart';

final class SetSpaceUsageCommand implements ProjectCommand {
  const SetSpaceUsageCommand({required this.spaceId, required this.usage});

  final SpaceId spaceId;
  final SpaceUsage usage;

  @override
  String get commandType => 'project.space.usage.set';

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) {
    final space = _requireSpace(current, spaceId);
    final spaces = Map<SpaceId, ProjectSpaceEntity>.from(current.stores.spaces);
    spaces[space.id] = ProjectSpaceEntity(
      id: space.id,
      levelId: space.levelId,
      name: space.name,
      usage: usage,
    );
    return _candidate(current, spaces: spaces, affected: <EntityId>[space.id]);
  }
}

final class CreateOpeningCommand implements ProjectCommand {
  const CreateOpeningCommand({required this.opening});

  final ProjectOpeningEntity opening;

  @override
  String get commandType => 'project.opening.create';

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) {
    if (current.stores.openings.containsKey(opening.id)) {
      throw ProjectAuthoringException(
        code: ProjectAuthoringIssueCode.openingAlreadyExists,
        entityId: opening.id,
        message: 'Opening ${opening.id} already exists.',
      );
    }
    final openings = Map<OpeningId, ProjectOpeningEntity>.from(
      current.stores.openings,
    )..[opening.id] = opening;
    return _candidate(
      current,
      openings: openings,
      affected: <EntityId>[opening.id, ...opening.connectedSpaceIds],
    );
  }
}

final class UpdateOpeningCommand implements ProjectCommand {
  const UpdateOpeningCommand({required this.opening});

  final ProjectOpeningEntity opening;

  @override
  String get commandType => 'project.opening.update';

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) {
    final before = _requireOpening(current, opening.id);
    if (!_sameOpeningPayload(before, opening)) {
      final boundaryBlockers = _openingBoundaryBlockers(current, before);
      if (boundaryBlockers.isNotEmpty) {
        throw ProjectAuthoringException(
          code: ProjectAuthoringIssueCode.openingHasBoundaryDependencies,
          entityId: opening.id,
          relatedEntityId: boundaryBlockers.first,
          blockingEntityIds: Set<EntityId>.unmodifiable(boundaryBlockers),
          message: 'Opening ${opening.id} cannot be changed through the P6 '
              'semantic command while durable boundary hosts reference it. '
              'Use a host-aware P7 mutation.',
        );
      }
    }
    final openings = Map<OpeningId, ProjectOpeningEntity>.from(
      current.stores.openings,
    )..[opening.id] = opening;
    return _candidate(
      current,
      openings: openings,
      affected: <EntityId>[
        opening.id,
        ...before.connectedSpaceIds,
        ...opening.connectedSpaceIds,
      ],
    );
  }
}

final class RemoveOpeningCommand implements ProjectCommand {
  const RemoveOpeningCommand({required this.openingId});

  final OpeningId openingId;

  @override
  String get commandType => 'project.opening.remove';

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) {
    final opening = _requireOpening(current, openingId);
    final blockers = current.stores.adjacencies.values
        .where((adjacency) => adjacency.openingId == opening.id)
        .map((adjacency) => adjacency.id)
        .toSet();
    if (blockers.isNotEmpty) {
      throw ProjectAuthoringException(
        code: ProjectAuthoringIssueCode.spaceHasSemanticDependencies,
        entityId: opening.id,
        relatedEntityId: blockers.first,
        blockingEntityIds: Set<EntityId>.unmodifiable(blockers),
        message: 'Opening ${opening.id} cannot be removed while adjacency '
            'entities reference it.',
      );
    }
    final boundaryBlockers = _openingBoundaryBlockers(current, opening);
    if (boundaryBlockers.isNotEmpty) {
      throw ProjectAuthoringException(
        code: ProjectAuthoringIssueCode.openingHasBoundaryDependencies,
        entityId: opening.id,
        relatedEntityId: boundaryBlockers.first,
        blockingEntityIds: Set<EntityId>.unmodifiable(boundaryBlockers),
        message: 'Opening ${opening.id} cannot be removed while durable '
            'boundary hosts reference it. Detach the P7 host first.',
      );
    }
    final openings = Map<OpeningId, ProjectOpeningEntity>.from(
      current.stores.openings,
    )..remove(opening.id);
    return _candidate(
      current,
      openings: openings,
      affected: <EntityId>[opening.id, ...opening.connectedSpaceIds],
    );
  }
}

final class CreateAdjacencyCommand implements ProjectCommand {
  const CreateAdjacencyCommand({required this.adjacency});

  final ProjectSpaceAdjacencyEntity adjacency;

  @override
  String get commandType => 'project.adjacency.create';

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) {
    if (current.stores.adjacencies.containsKey(adjacency.id)) {
      throw ProjectAuthoringException(
        code: ProjectAuthoringIssueCode.adjacencyAlreadyExists,
        entityId: adjacency.id,
        message: 'Adjacency ${adjacency.id} already exists.',
      );
    }
    final adjacencies = Map<SpaceAdjacencyId, ProjectSpaceAdjacencyEntity>.from(
      current.stores.adjacencies,
    )..[adjacency.id] = adjacency;
    return _candidate(
      current,
      adjacencies: adjacencies,
      affected: <EntityId>[
        adjacency.id,
        adjacency.spaceAId,
        adjacency.spaceBId,
        if (adjacency.openingId != null) adjacency.openingId!,
      ],
    );
  }
}

final class UpdateAdjacencyCommand implements ProjectCommand {
  const UpdateAdjacencyCommand({required this.adjacency});

  final ProjectSpaceAdjacencyEntity adjacency;

  @override
  String get commandType => 'project.adjacency.update';

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) {
    final before = _requireAdjacency(current, adjacency.id);
    final adjacencies = Map<SpaceAdjacencyId, ProjectSpaceAdjacencyEntity>.from(
      current.stores.adjacencies,
    )..[adjacency.id] = adjacency;
    return _candidate(
      current,
      adjacencies: adjacencies,
      affected: <EntityId>[
        adjacency.id,
        before.spaceAId,
        before.spaceBId,
        adjacency.spaceAId,
        adjacency.spaceBId,
        if (before.openingId != null) before.openingId!,
        if (adjacency.openingId != null) adjacency.openingId!,
      ],
    );
  }
}

final class RemoveAdjacencyCommand implements ProjectCommand {
  const RemoveAdjacencyCommand({required this.adjacencyId});

  final SpaceAdjacencyId adjacencyId;

  @override
  String get commandType => 'project.adjacency.remove';

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) {
    final adjacency = _requireAdjacency(current, adjacencyId);
    final adjacencies = Map<SpaceAdjacencyId, ProjectSpaceAdjacencyEntity>.from(
      current.stores.adjacencies,
    )..remove(adjacency.id);
    return _candidate(
      current,
      adjacencies: adjacencies,
      affected: <EntityId>[
        adjacency.id,
        adjacency.spaceAId,
        adjacency.spaceBId,
        if (adjacency.openingId != null) adjacency.openingId!,
      ],
    );
  }
}

final class CreateOverlayClassificationCommand implements ProjectCommand {
  const CreateOverlayClassificationCommand({required this.overlay});

  final ProjectOverlayClassificationEntity overlay;

  @override
  String get commandType => 'project.overlay.create';

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) {
    if (current.stores.overlays.containsKey(overlay.id)) {
      throw ProjectAuthoringException(
        code: ProjectAuthoringIssueCode.overlayAlreadyExists,
        entityId: overlay.id,
        message: 'Overlay ${overlay.id} already exists.',
      );
    }
    final overlays =
        Map<OverlayClassificationId, ProjectOverlayClassificationEntity>.from(
      current.stores.overlays,
    )..[overlay.id] = overlay;
    return _candidate(
      current,
      overlays: overlays,
      affected: <EntityId>[overlay.id, ...overlay.spaceIds],
    );
  }
}

final class RenameOverlayClassificationCommand implements ProjectCommand {
  RenameOverlayClassificationCommand({
    required this.overlayId,
    required this.name,
  }) {
    if (name.trim().isEmpty) {
      throw ArgumentError.value(
        name,
        'name',
        'Overlay name must be non-empty.',
      );
    }
  }

  final OverlayClassificationId overlayId;
  final String name;

  @override
  String get commandType => 'project.overlay.rename';

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) {
    final overlay = _requireOverlay(current, overlayId);
    final overlays =
        Map<OverlayClassificationId, ProjectOverlayClassificationEntity>.from(
      current.stores.overlays,
    );
    overlays[overlay.id] = ProjectOverlayClassificationEntity(
      id: overlay.id,
      name: name,
      discipline: overlay.discipline,
      kind: overlay.kind,
      spaceIds: overlay.spaceIds,
    );
    return _candidate(
      current,
      overlays: overlays,
      affected: <EntityId>[overlay.id],
    );
  }
}

final class AssignSpaceToOverlayCommand implements ProjectCommand {
  const AssignSpaceToOverlayCommand({
    required this.overlayId,
    required this.spaceId,
  });

  final OverlayClassificationId overlayId;
  final SpaceId spaceId;

  @override
  String get commandType => 'project.overlay.space.assign';

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) {
    final overlay = _requireOverlay(current, overlayId);
    _requireSpace(current, spaceId);
    final overlays =
        Map<OverlayClassificationId, ProjectOverlayClassificationEntity>.from(
      current.stores.overlays,
    );
    overlays[overlay.id] = ProjectOverlayClassificationEntity(
      id: overlay.id,
      name: overlay.name,
      discipline: overlay.discipline,
      kind: overlay.kind,
      spaceIds: <SpaceId>{...overlay.spaceIds, spaceId},
    );
    return _candidate(
      current,
      overlays: overlays,
      affected: <EntityId>[overlay.id, spaceId],
    );
  }
}

final class RemoveSpaceFromOverlayCommand implements ProjectCommand {
  const RemoveSpaceFromOverlayCommand({
    required this.overlayId,
    required this.spaceId,
  });

  final OverlayClassificationId overlayId;
  final SpaceId spaceId;

  @override
  String get commandType => 'project.overlay.space.remove';

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) {
    final overlay = _requireOverlay(current, overlayId);
    _requireSpace(current, spaceId);
    final overlays =
        Map<OverlayClassificationId, ProjectOverlayClassificationEntity>.from(
      current.stores.overlays,
    );
    overlays[overlay.id] = ProjectOverlayClassificationEntity(
      id: overlay.id,
      name: overlay.name,
      discipline: overlay.discipline,
      kind: overlay.kind,
      spaceIds: <SpaceId>{...overlay.spaceIds}..remove(spaceId),
    );
    return _candidate(
      current,
      overlays: overlays,
      affected: <EntityId>[overlay.id, spaceId],
    );
  }
}

final class RemoveOverlayClassificationCommand implements ProjectCommand {
  const RemoveOverlayClassificationCommand({required this.overlayId});

  final OverlayClassificationId overlayId;

  @override
  String get commandType => 'project.overlay.remove';

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) {
    final overlay = _requireOverlay(current, overlayId);
    final overlays =
        Map<OverlayClassificationId, ProjectOverlayClassificationEntity>.from(
      current.stores.overlays,
    )..remove(overlay.id);
    return _candidate(
      current,
      overlays: overlays,
      affected: <EntityId>[overlay.id, ...overlay.spaceIds],
    );
  }
}

ProjectCommandCandidate _candidate(
  ProjectAggregateRoot current, {
  Map<SpaceId, ProjectSpaceEntity>? spaces,
  Map<OpeningId, ProjectOpeningEntity>? openings,
  Map<SpaceAdjacencyId, ProjectSpaceAdjacencyEntity>? adjacencies,
  Map<OverlayClassificationId, ProjectOverlayClassificationEntity>? overlays,
  required Iterable<EntityId> affected,
}) =>
    ProjectCommandCandidate.fromState(
      state: ProjectMutableState(
        engineeringMetadata: current.engineeringMetadata,
        stores: current.stores.copyWith(
          spaces: spaces,
          openings: openings,
          adjacencies: adjacencies,
          overlays: overlays,
        ),
      ),
      affectedEntityIds: affected,
    );

Set<EntityId> _openingBoundaryBlockers(
  ProjectAggregateRoot current,
  ProjectOpeningEntity opening,
) {
  final registry = current.engineeringMetadata.boundaryHostedObjectRegistry;
  return <EntityId>{
    for (final spaceId in opening.connectedSpaceIds)
      if (registry.openingHost(opening.id, spaceId) case final host?)
        host.host.edgeId,
  };
}

bool _sameOpeningPayload(ProjectOpeningEntity a, ProjectOpeningEntity b) =>
    a.id == b.id &&
    a.levelId == b.levelId &&
    a.kind == b.kind &&
    a.connectedSpaceIds.length == b.connectedSpaceIds.length &&
    a.connectedSpaceIds.containsAll(b.connectedSpaceIds) &&
    a.widthMm == b.widthMm &&
    a.heightMm == b.heightMm &&
    a.baseElevationMm == b.baseElevationMm;

ProjectSpaceEntity _requireSpace(ProjectAggregateRoot current, SpaceId id) {
  final value = current.index.space(id);
  if (value == null) {
    throw ProjectAuthoringException(
      code: ProjectAuthoringIssueCode.spaceNotFound,
      entityId: id,
      message: 'Space $id does not exist.',
    );
  }
  return value;
}

ProjectOpeningEntity _requireOpening(
  ProjectAggregateRoot current,
  OpeningId id,
) {
  final value = current.index.opening(id);
  if (value == null) {
    throw ProjectAuthoringException(
      code: ProjectAuthoringIssueCode.openingNotFound,
      entityId: id,
      message: 'Opening $id does not exist.',
    );
  }
  return value;
}

ProjectSpaceAdjacencyEntity _requireAdjacency(
  ProjectAggregateRoot current,
  SpaceAdjacencyId id,
) {
  final value = current.index.adjacency(id);
  if (value == null) {
    throw ProjectAuthoringException(
      code: ProjectAuthoringIssueCode.adjacencyNotFound,
      entityId: id,
      message: 'Adjacency $id does not exist.',
    );
  }
  return value;
}

ProjectOverlayClassificationEntity _requireOverlay(
  ProjectAggregateRoot current,
  OverlayClassificationId id,
) {
  final value = current.index.overlay(id);
  if (value == null) {
    throw ProjectAuthoringException(
      code: ProjectAuthoringIssueCode.overlayNotFound,
      entityId: id,
      message: 'Overlay $id does not exist.',
    );
  }
  return value;
}
