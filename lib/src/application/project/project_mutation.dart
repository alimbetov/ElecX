import '../../domain/boundary_edge_identity_registry.dart';
import '../../domain/boundary_topology.dart';
import '../../domain/generation_provenance.dart';
import '../../domain/level_apartment_composition.dart';
import '../../domain/project_aggregate.dart';
import '../../domain/project_entity_stores_copy.dart';
import '../../domain/project_identity.dart';
import '../../domain/project_orientation.dart';
import '../../domain/project_space_semantics.dart';
import '../../domain/slab_topology.dart';
import '../../domain/typical_floor.dart';
import '../../domain/vertical_core.dart';

abstract interface class ProjectCommand {
  String get commandType;

  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current);
}

final class ProjectMutableState {
  const ProjectMutableState({
    required this.engineeringMetadata,
    required this.stores,
  });

  final ProjectEngineeringMetadata engineeringMetadata;
  final ProjectEntityStores stores;

  factory ProjectMutableState.fromProject(ProjectAggregateRoot project) =>
      ProjectMutableState(
        engineeringMetadata: project.engineeringMetadata,
        stores: project.stores,
      );
}

/// Immutable candidate produced by one [ProjectCommand].
///
/// New P6+ commands must use [ProjectCommandCandidate.fromState]. The legacy
/// stores-only constructor remains source-compatible with P3/P4 commands and
/// preserves root engineering metadata plus semantic and P7A boundary stores.
/// This keeps older structural commands from accidentally erasing newer state.
final class ProjectCommandCandidate {
  ProjectCommandCandidate({
    required ProjectEntityStores stores,
    Iterable<EntityId> affectedEntityIds = const <EntityId>[],
  })  : _stores = stores,
        state = null,
        affectedEntityIds = Set<EntityId>.unmodifiable(affectedEntityIds);

  ProjectCommandCandidate.fromState({
    required this.state,
    Iterable<EntityId> affectedEntityIds = const <EntityId>[],
  })  : _stores = null,
        affectedEntityIds = Set<EntityId>.unmodifiable(affectedEntityIds);

  final ProjectMutableState? state;
  final ProjectEntityStores? _stores;
  final Set<EntityId> affectedEntityIds;

  ProjectEntityStores get stores => state?.stores ?? _stores!;

  ProjectMutableState resolveState(ProjectAggregateRoot current) {
    if (state != null) return state!;
    final legacy = _stores!;
    return ProjectMutableState(
      engineeringMetadata: current.engineeringMetadata,
      stores: current.stores.copyWith(
        sites: legacy.sites,
        buildings: legacy.buildings,
        levels: legacy.levels,
        zones: legacy.zones,
        spaces: legacy.spaces,
      ),
    );
  }
}

final class ProjectMutationRequest {
  const ProjectMutationRequest({
    required this.expectedVersion,
    required this.command,
  });

  final LocalProjectVersion expectedVersion;
  final ProjectCommand command;
}

enum ProjectChangeKind { command, undo, redo }

final class ProjectEntityDiff {
  ProjectEntityDiff({
    Iterable<EntityId> addedEntityIds = const <EntityId>[],
    Iterable<EntityId> updatedEntityIds = const <EntityId>[],
    Iterable<EntityId> removedEntityIds = const <EntityId>[],
  })  : addedEntityIds = Set<EntityId>.unmodifiable(addedEntityIds),
        updatedEntityIds = Set<EntityId>.unmodifiable(updatedEntityIds),
        removedEntityIds = Set<EntityId>.unmodifiable(removedEntityIds) {
    if (_hasOverlap(this.addedEntityIds, this.updatedEntityIds) ||
        _hasOverlap(this.addedEntityIds, this.removedEntityIds) ||
        _hasOverlap(this.updatedEntityIds, this.removedEntityIds)) {
      throw ArgumentError(
        'ProjectEntityDiff added/updated/removed entity sets must be disjoint.',
      );
    }
  }

  factory ProjectEntityDiff.between(
    ProjectEntityStores before,
    ProjectEntityStores after,
  ) {
    final added = <EntityId>{};
    final updated = <EntityId>{};
    final removed = <EntityId>{};

    _diffMap(before.sites, after.sites, _sameSite, added, updated, removed);
    _diffMap(
      before.buildings,
      after.buildings,
      _sameBuilding,
      added,
      updated,
      removed,
    );
    _diffMap(before.levels, after.levels, _sameLevel, added, updated, removed);
    _diffMap(before.slabs, after.slabs, _sameSlab, added, updated, removed);
    _diffMap(
      before.verticalCores,
      after.verticalCores,
      _sameVerticalCore,
      added,
      updated,
      removed,
    );
    _diffMap(before.zones, after.zones, _sameZone, added, updated, removed);
    _diffMap(before.spaces, after.spaces, _sameSpace, added, updated, removed);
    _diffMap(
      before.openings,
      after.openings,
      _sameOpening,
      added,
      updated,
      removed,
    );
    _diffMap(
      before.adjacencies,
      after.adjacencies,
      _sameAdjacency,
      added,
      updated,
      removed,
    );
    _diffMap(
      before.overlays,
      after.overlays,
      _sameOverlay,
      added,
      updated,
      removed,
    );
    _diffBoundaries(
      before.boundaries,
      after.boundaries,
      added,
      updated,
      removed,
    );

    return ProjectEntityDiff(
      addedEntityIds: added,
      updatedEntityIds: updated,
      removedEntityIds: removed,
    );
  }

  final Set<EntityId> addedEntityIds;
  final Set<EntityId> updatedEntityIds;
  final Set<EntityId> removedEntityIds;

  Set<EntityId> get affectedEntityIds => Set<EntityId>.unmodifiable({
        ...addedEntityIds,
        ...updatedEntityIds,
        ...removedEntityIds,
      });

  bool get isEmpty =>
      addedEntityIds.isEmpty &&
      updatedEntityIds.isEmpty &&
      removedEntityIds.isEmpty;
  bool get isNotEmpty => !isEmpty;
}

final class ProjectEngineeringMetadataDiff {
  const ProjectEngineeringMetadataDiff({
    required this.beforeProjectNorth,
    required this.afterProjectNorth,
    this.boundaryEdgeIdentityRegistryChanged = false,
    this.boundaryHostedObjectRegistryChanged = false,
    this.boundaryWallProfileRegistryChanged = false,
    this.boundaryConstructionRegistryChanged = false,
    this.generationProvenanceRegistryChanged = false,
    this.appliedEngineeringProposalRegistryChanged = false,
  });

  const ProjectEngineeringMetadataDiff.empty()
      : beforeProjectNorth = null,
        afterProjectNorth = null,
        boundaryEdgeIdentityRegistryChanged = false,
        boundaryHostedObjectRegistryChanged = false,
        boundaryWallProfileRegistryChanged = false,
        boundaryConstructionRegistryChanged = false,
        generationProvenanceRegistryChanged = false,
        appliedEngineeringProposalRegistryChanged = false;

  factory ProjectEngineeringMetadataDiff.between(
    ProjectEngineeringMetadata before,
    ProjectEngineeringMetadata after,
  ) =>
      ProjectEngineeringMetadataDiff(
        beforeProjectNorth: before.projectNorth,
        afterProjectNorth: after.projectNorth,
        boundaryEdgeIdentityRegistryChanged: !before
            .boundaryEdgeIdentityRegistry
            .sameAs(after.boundaryEdgeIdentityRegistry),
        boundaryHostedObjectRegistryChanged: !before
            .boundaryHostedObjectRegistry
            .sameAs(after.boundaryHostedObjectRegistry),
        boundaryWallProfileRegistryChanged: !before.boundaryWallProfileRegistry
            .sameAs(after.boundaryWallProfileRegistry),
        boundaryConstructionRegistryChanged: !before
            .boundaryConstructionRegistry
            .sameAs(after.boundaryConstructionRegistry),
        generationProvenanceRegistryChanged: !before
            .generationProvenanceRegistry
            .sameAs(after.generationProvenanceRegistry),
        appliedEngineeringProposalRegistryChanged: !before
            .appliedEngineeringProposalRegistry
            .sameAs(after.appliedEngineeringProposalRegistry),
      );

  final ProjectEngineeringNorth? beforeProjectNorth;
  final ProjectEngineeringNorth? afterProjectNorth;
  final bool boundaryEdgeIdentityRegistryChanged;
  final bool boundaryHostedObjectRegistryChanged;
  final bool boundaryWallProfileRegistryChanged;
  final bool boundaryConstructionRegistryChanged;
  final bool generationProvenanceRegistryChanged;
  final bool appliedEngineeringProposalRegistryChanged;

  bool get projectNorthChanged => beforeProjectNorth != afterProjectNorth;
  bool get isEmpty =>
      !projectNorthChanged &&
      !boundaryEdgeIdentityRegistryChanged &&
      !boundaryHostedObjectRegistryChanged &&
      !boundaryWallProfileRegistryChanged &&
      !boundaryConstructionRegistryChanged &&
      !generationProvenanceRegistryChanged &&
      !appliedEngineeringProposalRegistryChanged;
  bool get isNotEmpty => !isEmpty;
}

final class ProjectChangeSet {
  ProjectChangeSet({
    required this.kind,
    required this.commandType,
    required this.beforeVersion,
    required this.afterVersion,
    ProjectEntityDiff? diff,
    ProjectEntityDiff? entityDiff,
    this.engineeringMetadataDiff = const ProjectEngineeringMetadataDiff.empty(),
  }) : entityDiff = entityDiff ?? diff ?? ProjectEntityDiff() {
    if (diff != null && entityDiff != null) {
      throw ArgumentError('Specify either diff or entityDiff, not both.');
    }
    if (commandType.trim().isEmpty) {
      throw ArgumentError.value(
        commandType,
        'commandType',
        'Must be non-empty.',
      );
    }
    if (afterVersion.value != beforeVersion.value + 1) {
      throw ArgumentError(
        'A committed ProjectChangeSet must advance LocalProjectVersion exactly '
        'once: $beforeVersion -> $afterVersion.',
      );
    }
    if (this.entityDiff.isEmpty && engineeringMetadataDiff.isEmpty) {
      throw ArgumentError(
        'A committed ProjectChangeSet must contain a non-empty canonical diff.',
      );
    }
  }

  final ProjectChangeKind kind;
  final String commandType;
  final LocalProjectVersion beforeVersion;
  final LocalProjectVersion afterVersion;
  final ProjectEntityDiff entityDiff;
  final ProjectEngineeringMetadataDiff engineeringMetadataDiff;

  ProjectEntityDiff get diff => entityDiff;
  Set<EntityId> get addedEntityIds => entityDiff.addedEntityIds;
  Set<EntityId> get updatedEntityIds => entityDiff.updatedEntityIds;
  Set<EntityId> get removedEntityIds => entityDiff.removedEntityIds;
  Set<EntityId> get affectedEntityIds => entityDiff.affectedEntityIds;
  bool get hasRootMetadataChanges => engineeringMetadataDiff.isNotEmpty;
}

final class ProjectMutationPreview {
  ProjectMutationPreview({
    required this.candidate,
    required this.commandType,
    ProjectEntityDiff? diff,
    ProjectEntityDiff? entityDiff,
    this.engineeringMetadataDiff = const ProjectEngineeringMetadataDiff.empty(),
    Iterable<EntityId> declaredAffectedEntityIds = const <EntityId>[],
  })  : entityDiff = entityDiff ?? diff ?? ProjectEntityDiff(),
        declaredAffectedEntityIds = Set<EntityId>.unmodifiable(
          declaredAffectedEntityIds,
        ) {
    if (diff != null && entityDiff != null) {
      throw ArgumentError('Specify either diff or entityDiff, not both.');
    }
  }

  final ProjectAggregateRoot candidate;
  final String commandType;
  final ProjectEntityDiff entityDiff;
  final ProjectEngineeringMetadataDiff engineeringMetadataDiff;
  final Set<EntityId> declaredAffectedEntityIds;

  ProjectEntityDiff get diff => entityDiff;
  Set<EntityId> get affectedEntityIds => entityDiff.affectedEntityIds;
  bool get hasChanges =>
      entityDiff.isNotEmpty || engineeringMetadataDiff.isNotEmpty;
}

final class ProjectMutationResult {
  const ProjectMutationResult({required this.project, required this.changeSet});

  final ProjectAggregateRoot project;
  final ProjectChangeSet changeSet;
}

final class StaleProjectMutationException implements Exception {
  const StaleProjectMutationException({
    required this.expectedVersion,
    required this.currentVersion,
  });

  final LocalProjectVersion expectedVersion;
  final LocalProjectVersion currentVersion;

  @override
  String toString() => 'Stale project mutation: expected local version '
      '$expectedVersion, current version is $currentVersion.';
}

final class ProjectCandidateValidationException implements Exception {
  ProjectCandidateValidationException(
    Iterable<ProjectAggregateValidationIssue> issues,
  ) : issues = List<ProjectAggregateValidationIssue>.unmodifiable(issues);

  final List<ProjectAggregateValidationIssue> issues;

  @override
  String toString() =>
      'Invalid project mutation candidate:\n${issues.join('\n')}';
}

final class BoundaryEdgeOwnershipException implements Exception {
  const BoundaryEdgeOwnershipException({
    required this.edgeId,
    required this.expectedSpaceId,
    required this.actualSpaceId,
  });

  final BoundaryEdgeId edgeId;
  final SpaceId expectedSpaceId;
  final SpaceId actualSpaceId;

  @override
  String toString() => 'Boundary edge $edgeId is permanently owned by '
      '$expectedSpaceId and cannot be reassigned to $actualSpaceId.';
}

abstract final class CandidateGraphValidator {
  static void validate({
    required ProjectAggregateRoot current,
    required ProjectCommandCandidate candidate,
  }) {
    final state = candidate.resolveState(current);
    final issues = ProjectAggregateValidator.validate(
      rootSiteId: current.siteId,
      stores: state.stores,
    );
    if (issues.isNotEmpty) {
      throw ProjectCandidateValidationException(issues);
    }
    state.engineeringMetadata.boundaryHostedObjectRegistry.validateAgainst(
      state.stores.boundaries,
    );
    state.engineeringMetadata.boundaryWallProfileRegistry.validateAgainst(
      state.stores.boundaries,
    );
    state.engineeringMetadata.boundaryConstructionRegistry.validateAgainst(
      state.stores.boundaries,
    );
    state.engineeringMetadata.generationProvenanceRegistry.validateOrThrow(
      projectId: current.id,
      entityExists: (id) => _entityExists(state.stores, id),
    );
    TypicalFloorLineageIntegrity.validateOrThrow(
      definitions: state.engineeringMetadata.generationProvenanceRegistry
          .typicalFloorDefinitions,
      instances:
          state.engineeringMetadata.generationProvenanceRegistry.floorInstances,
      stores: state.stores,
    );
    LevelApartmentCompositionIntegrity.validateOrThrow(
        registry: state.engineeringMetadata.generationProvenanceRegistry,
        projectId: current.id,
        stores: state.stores);
    final index = ProjectIndex.build(state.stores);
    if (!index.isConsistentWith(state.stores)) {
      throw StateError('Candidate ProjectIndex is inconsistent with stores.');
    }
  }
}

final class UndoRecord {
  UndoRecord.fromStates({
    required this.commandType,
    required this.beforeState,
    required this.afterState,
  }) {
    if (commandType.trim().isEmpty) {
      throw ArgumentError.value(
        commandType,
        'commandType',
        'Must be non-empty.',
      );
    }
    if (_ProjectMutableStateDiff.between(beforeState, afterState).isEmpty) {
      throw ArgumentError(
        'UndoRecord requires different before/after canonical state.',
      );
    }
  }

  final String commandType;
  final ProjectMutableState beforeState;
  final ProjectMutableState afterState;
}

final class _ProjectMutableStateDiff {
  const _ProjectMutableStateDiff({
    required this.entityDiff,
    required this.engineeringMetadataDiff,
  });

  factory _ProjectMutableStateDiff.between(
    ProjectMutableState before,
    ProjectMutableState after,
  ) =>
      _ProjectMutableStateDiff(
        entityDiff: ProjectEntityDiff.between(before.stores, after.stores),
        engineeringMetadataDiff: ProjectEngineeringMetadataDiff.between(
          before.engineeringMetadata,
          after.engineeringMetadata,
        ),
      );

  final ProjectEntityDiff entityDiff;
  final ProjectEngineeringMetadataDiff engineeringMetadataDiff;

  bool get isEmpty => entityDiff.isEmpty && engineeringMetadataDiff.isEmpty;
}

final class ProjectMutationSession {
  ProjectMutationSession(ProjectAggregateRoot initial)
      : _current = initial,
        _boundaryIdentityRegistry = initial
            .engineeringMetadata.boundaryEdgeIdentityRegistry
            .registerActiveBoundaries(initial.stores.boundaries);

  ProjectAggregateRoot _current;
  BoundaryEdgeIdentityRegistry _boundaryIdentityRegistry;
  final List<UndoRecord> _undoStack = <UndoRecord>[];
  final List<UndoRecord> _redoStack = <UndoRecord>[];

  ProjectAggregateRoot get current => _current;
  int get undoDepth => _undoStack.length;
  int get redoDepth => _redoStack.length;
  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  ProjectMutationPreview preview(ProjectMutationRequest request) {
    _requireVersion(request.expectedVersion);
    final commandType = _requireCommandType(request.command);
    final before = _current;
    final candidate = request.command.buildCandidate(before);
    var candidateState = candidate.resolveState(before);
    candidateState = _withTrackedGenerationProvenance(
      before: before,
      candidateState: candidateState,
    );
    final trackedCandidate = ProjectCommandCandidate.fromState(
      state: candidateState,
      affectedEntityIds: candidate.affectedEntityIds,
    );
    CandidateGraphValidator.validate(
      current: before,
      candidate: trackedCandidate,
    );
    candidateState = _withDurableBoundaryRegistry(candidateState);
    _validateProvenance(before.id, candidateState);
    final stateDiff = _ProjectMutableStateDiff.between(
      ProjectMutableState.fromProject(before),
      candidateState,
    );
    _requireVersion(request.expectedVersion);
    final previewRoot = ProjectAggregateRoot(
      id: before.id,
      siteId: before.siteId,
      version: before.version,
      engineeringMetadata: candidateState.engineeringMetadata,
      stores: candidateState.stores,
    );
    return ProjectMutationPreview(
      candidate: previewRoot,
      commandType: commandType,
      entityDiff: stateDiff.entityDiff,
      engineeringMetadataDiff: stateDiff.engineeringMetadataDiff,
      declaredAffectedEntityIds: candidate.affectedEntityIds,
    );
  }

  ProjectMutationResult? commit(ProjectMutationRequest request) {
    _requireVersion(request.expectedVersion);
    final commandType = _requireCommandType(request.command);
    final before = _current;
    final beforeState = ProjectMutableState.fromProject(before);
    final candidate = request.command.buildCandidate(before);
    var candidateState = candidate.resolveState(before);
    candidateState = _withTrackedGenerationProvenance(
      before: before,
      candidateState: candidateState,
    );
    final trackedCandidate = ProjectCommandCandidate.fromState(
      state: candidateState,
      affectedEntityIds: candidate.affectedEntityIds,
    );
    CandidateGraphValidator.validate(
      current: before,
      candidate: trackedCandidate,
    );
    candidateState = _withDurableBoundaryRegistry(candidateState);
    _validateProvenance(before.id, candidateState);
    final stateDiff = _ProjectMutableStateDiff.between(
      beforeState,
      candidateState,
    );
    _requireVersion(request.expectedVersion);
    if (stateDiff.isEmpty) return null;

    final committed = ProjectAggregateRoot(
      id: before.id,
      siteId: before.siteId,
      version: before.version.next(),
      engineeringMetadata: candidateState.engineeringMetadata,
      stores: candidateState.stores,
    );
    final changeSet = ProjectChangeSet(
      kind: ProjectChangeKind.command,
      commandType: commandType,
      beforeVersion: before.version,
      afterVersion: committed.version,
      entityDiff: stateDiff.entityDiff,
      engineeringMetadataDiff: stateDiff.engineeringMetadataDiff,
    );
    _current = committed;
    _boundaryIdentityRegistry =
        committed.engineeringMetadata.boundaryEdgeIdentityRegistry;
    _undoStack.add(
      UndoRecord.fromStates(
        commandType: commandType,
        beforeState: beforeState,
        afterState: ProjectMutableState.fromProject(committed),
      ),
    );
    _redoStack.clear();
    return ProjectMutationResult(project: committed, changeSet: changeSet);
  }

  ProjectMutationResult? undo(LocalProjectVersion expectedVersion) {
    _requireVersion(expectedVersion);
    if (_undoStack.isEmpty) return null;
    final before = _current;
    final beforeState = ProjectMutableState.fromProject(before);
    final record = _undoStack.last;
    final targetState = _withDurableBoundaryRegistry(record.beforeState);
    _validateProvenance(before.id, targetState);
    final stateDiff = _ProjectMutableStateDiff.between(
      beforeState,
      targetState,
    );
    if (stateDiff.isEmpty) {
      throw StateError(
        'Undo history is inconsistent with current project state.',
      );
    }
    final restored = _commitState(state: targetState, before: before);
    final changeSet = ProjectChangeSet(
      kind: ProjectChangeKind.undo,
      commandType: record.commandType,
      beforeVersion: before.version,
      afterVersion: restored.version,
      entityDiff: stateDiff.entityDiff,
      engineeringMetadataDiff: stateDiff.engineeringMetadataDiff,
    );
    _current = restored;
    _boundaryIdentityRegistry =
        restored.engineeringMetadata.boundaryEdgeIdentityRegistry;
    _undoStack.removeLast();
    _redoStack.add(record);
    return ProjectMutationResult(project: restored, changeSet: changeSet);
  }

  ProjectMutationResult? redo(LocalProjectVersion expectedVersion) {
    _requireVersion(expectedVersion);
    if (_redoStack.isEmpty) return null;
    final before = _current;
    final beforeState = ProjectMutableState.fromProject(before);
    final record = _redoStack.last;
    final targetState = _withDurableBoundaryRegistry(record.afterState);
    _validateProvenance(before.id, targetState);
    final stateDiff = _ProjectMutableStateDiff.between(
      beforeState,
      targetState,
    );
    if (stateDiff.isEmpty) {
      throw StateError(
        'Redo history is inconsistent with current project state.',
      );
    }
    final restored = _commitState(state: targetState, before: before);
    final changeSet = ProjectChangeSet(
      kind: ProjectChangeKind.redo,
      commandType: record.commandType,
      beforeVersion: before.version,
      afterVersion: restored.version,
      entityDiff: stateDiff.entityDiff,
      engineeringMetadataDiff: stateDiff.engineeringMetadataDiff,
    );
    _current = restored;
    _boundaryIdentityRegistry =
        restored.engineeringMetadata.boundaryEdgeIdentityRegistry;
    _redoStack.removeLast();
    _undoStack.add(record);
    return ProjectMutationResult(project: restored, changeSet: changeSet);
  }

  ProjectAggregateRoot _commitState({
    required ProjectMutableState state,
    required ProjectAggregateRoot before,
  }) {
    final durableState = _withDurableBoundaryRegistry(state);
    final issues = ProjectAggregateValidator.validate(
      rootSiteId: before.siteId,
      stores: durableState.stores,
    );
    if (issues.isNotEmpty) {
      throw ProjectCandidateValidationException(issues);
    }
    durableState.engineeringMetadata.boundaryHostedObjectRegistry
        .validateAgainst(durableState.stores.boundaries);
    durableState.engineeringMetadata.boundaryWallProfileRegistry
        .validateAgainst(durableState.stores.boundaries);
    durableState.engineeringMetadata.boundaryConstructionRegistry
        .validateAgainst(durableState.stores.boundaries);
    _validateProvenance(before.id, durableState);
    return ProjectAggregateRoot(
      id: before.id,
      siteId: before.siteId,
      version: before.version.next(),
      engineeringMetadata: durableState.engineeringMetadata,
      stores: durableState.stores,
    );
  }

  ProjectMutableState _withTrackedGenerationProvenance({
    required ProjectAggregateRoot before,
    required ProjectMutableState candidateState,
  }) {
    final beforeRegistry =
        before.engineeringMetadata.generationProvenanceRegistry;
    if (beforeRegistry.entities.isEmpty &&
        !beforeRegistry.hasTypicalFloorLineage) {
      return candidateState;
    }

    var registry =
        candidateState.engineeringMetadata.generationProvenanceRegistry;
    for (final entry in beforeRegistry.typicalFloorDefinitions.entries) {
      final next = registry.typicalFloorDefinitions[entry.key];
      if (next != null && !entry.value.sameAs(next)) {
        throw const TypicalFloorLineageException(
            'p10.typical-floor.definition-immutable');
      }
    }
    for (final entry in beforeRegistry.entities.entries) {
      final entityId = entry.key;
      final provenance = entry.value;
      if (!_entityExists(candidateState.stores, entityId)) {
        registry = registry.removeGeneratedEntity(entityId);
        continue;
      }
      final changed = _changedGeneratedProperties(
        entityId: entityId,
        before: before,
        afterStores: candidateState.stores,
      ).intersection(provenance.generatedProperties);
      if (changed.isNotEmpty) {
        registry = registry.markOverridden(entityId, changed);
      }
    }
    final nextInstances = {...registry.floorInstances};
    for (final beforeInstance in beforeRegistry.floorInstances.values) {
      final instance = nextInstances[beforeInstance.levelId];
      if (instance == null) continue;
      if (!candidateState.stores.levels.containsKey(instance.levelId)) {
        nextInstances.remove(instance.levelId);
        continue;
      }
      final entities = {...instance.entities};
      final overridden = {...instance.overriddenProperties};
      final removed = {...instance.removedGenerationKeys};
      for (final entry in beforeInstance.entities.entries) {
        if (!entities.containsKey(entry.key)) continue;
        if (!_entityExists(candidateState.stores, entry.value)) {
          entities.remove(entry.key);
          overridden.remove(entry.key);
          removed.add(entry.key);
          continue;
        }
        final changed = _changedGeneratedProperties(
          entityId: entry.value,
          before: before,
          afterStores: candidateState.stores,
        );
        if (changed.isNotEmpty) {
          overridden[entry.key] = {...?overridden[entry.key], ...changed};
        }
      }
      nextInstances[instance.levelId] = instance.copyWith(
        entities: entities,
        overriddenProperties: overridden,
        removedGenerationKeys: removed,
      );
    }
    registry = registry.copyWith(
      floorInstances: nextInstances,
      levelCompositions: {
        for (final entry in registry.levelCompositions.entries)
          entry.key: entry.value.reconcileRelations(candidateState.stores)
      },
      typicalFloorDefinitions: {
        for (final entry in registry.typicalFloorDefinitions.entries)
          if (candidateState.stores.buildings
              .containsKey(entry.value.buildingId))
            entry.key: entry.value,
      },
    );
    if (registry.sameAs(
      candidateState.engineeringMetadata.generationProvenanceRegistry,
    )) {
      return candidateState;
    }
    return ProjectMutableState(
      engineeringMetadata: candidateState.engineeringMetadata
          .withGenerationProvenanceRegistry(registry),
      stores: candidateState.stores,
    );
  }

  ProjectMutableState _withDurableBoundaryRegistry(ProjectMutableState state) {
    try {
      final registry = _boundaryIdentityRegistry.registerActiveBoundaries(
        state.stores.boundaries,
      );
      return ProjectMutableState(
        engineeringMetadata: state.engineeringMetadata
            .withBoundaryEdgeIdentityRegistry(registry),
        stores: state.stores,
      );
    } on BoundaryEdgeIdentityOwnershipException catch (error) {
      throw BoundaryEdgeOwnershipException(
        edgeId: error.edgeId,
        expectedSpaceId: error.expectedSpaceId,
        actualSpaceId: error.actualSpaceId,
      );
    }
  }

  void _validateProvenance(ProjectId projectId, ProjectMutableState state) {
    LevelApartmentCompositionIntegrity.validateOrThrow(
        registry: state.engineeringMetadata.generationProvenanceRegistry,
        projectId: projectId,
        stores: state.stores);
    state.engineeringMetadata.generationProvenanceRegistry.validateOrThrow(
      projectId: projectId,
      entityExists: (id) => _entityExists(state.stores, id),
    );
    TypicalFloorLineageIntegrity.validateOrThrow(
      definitions: state.engineeringMetadata.generationProvenanceRegistry
          .typicalFloorDefinitions,
      instances:
          state.engineeringMetadata.generationProvenanceRegistry.floorInstances,
      stores: state.stores,
    );
  }

  String _requireCommandType(ProjectCommand command) {
    final commandType = command.commandType;
    if (commandType.trim().isEmpty) {
      throw ArgumentError.value(
        commandType,
        'command.commandType',
        'Must be non-empty.',
      );
    }
    return commandType;
  }

  void _requireVersion(LocalProjectVersion expectedVersion) {
    if (expectedVersion != _current.version) {
      throw StaleProjectMutationException(
        expectedVersion: expectedVersion,
        currentVersion: _current.version,
      );
    }
  }
}

Set<GenerationPropertyKey> _changedGeneratedProperties({
  required EntityId entityId,
  required ProjectAggregateRoot before,
  required ProjectEntityStores afterStores,
}) {
  final changed = <GenerationPropertyKey>{};
  final beforeStores = before.stores;

  if (entityId is LevelId) {
    final left = beforeStores.levels[entityId];
    final right = afterStores.levels[entityId];
    if (left == null || right == null) return changed;
    if (left.name != right.name) changed.add(GenerationPropertyKey.name);
    if (left.levelNumber != right.levelNumber ||
        left.kind != right.kind ||
        left.elevationMm != right.elevationMm ||
        left.displayOrder != right.displayOrder ||
        left.floorToFloorHeightMm != right.floorToFloorHeightMm) {
      changed.add(GenerationPropertyKey.levelStructure);
    }
    if (!_sameSet(left.spaceIds, right.spaceIds) ||
        !_sameSet(left.zoneIds, right.zoneIds)) {
      changed.add(GenerationPropertyKey.zoneMembership);
    }
    return changed;
  }

  if (entityId is ZoneId) {
    final left = beforeStores.zones[entityId];
    final right = afterStores.zones[entityId];
    if (left == null || right == null) return changed;
    if (left.name != right.name) changed.add(GenerationPropertyKey.name);
    if (!_sameSet(left.spaceIds, right.spaceIds)) {
      changed.add(GenerationPropertyKey.zoneMembership);
    }
    return changed;
  }

  if (entityId is SpaceId) {
    final left = beforeStores.spaces[entityId];
    final right = afterStores.spaces[entityId];
    if (left == null || right == null) return changed;
    if (left.name != right.name) changed.add(GenerationPropertyKey.name);
    if (left.type != right.type) {
      changed.add(GenerationPropertyKey.spaceType);
    }
    if (left.usage != right.usage) {
      changed.add(GenerationPropertyKey.spaceUsage);
    }
    if (!_sameNullableBoundary(
      beforeStores.boundaries[entityId],
      afterStores.boundaries[entityId],
    )) {
      changed.add(GenerationPropertyKey.geometry);
    }
    if (_zoneForSpace(beforeStores, entityId) !=
        _zoneForSpace(afterStores, entityId)) {
      changed.add(GenerationPropertyKey.zoneMembership);
    }
    if (!_sameSpaceOpeningRelations(beforeStores, afterStores, entityId)) {
      changed.add(GenerationPropertyKey.openingRelations);
    }
    if (!_sameSpaceAdjacencyRelations(beforeStores, afterStores, entityId)) {
      changed.add(GenerationPropertyKey.adjacencyRelations);
    }
    return changed;
  }

  if (entityId is BoundaryEdgeId) {
    final left = _boundaryEdge(beforeStores, entityId);
    final right = _boundaryEdge(afterStores, entityId);
    if (left != null && right != null && !_sameBoundaryEdge(left, right)) {
      changed.add(GenerationPropertyKey.geometry);
    }
    return changed;
  }

  if (entityId is OpeningId) {
    final left = beforeStores.openings[entityId];
    final right = afterStores.openings[entityId];
    if (left != null && right != null && !_sameOpening(left, right)) {
      changed.add(GenerationPropertyKey.openingRelations);
    }
    return changed;
  }

  if (entityId is SpaceAdjacencyId) {
    final left = beforeStores.adjacencies[entityId];
    final right = afterStores.adjacencies[entityId];
    if (left != null && right != null && !_sameAdjacency(left, right)) {
      changed.add(GenerationPropertyKey.adjacencyRelations);
    }
  }
  return changed;
}

ZoneId? _zoneForSpace(ProjectEntityStores stores, SpaceId spaceId) {
  for (final zone in stores.zones.values) {
    if (zone.spaceIds.contains(spaceId)) return zone.id;
  }
  return null;
}

ProjectBoundaryEdge? _boundaryEdge(
  ProjectEntityStores stores,
  BoundaryEdgeId edgeId,
) {
  for (final topology in stores.boundaries.values) {
    final edge = topology.edges[edgeId];
    if (edge != null) return edge;
  }
  return null;
}

bool _sameNullableBoundary(
  SpaceBoundaryTopology? left,
  SpaceBoundaryTopology? right,
) {
  if (left == null || right == null) return left == right;
  return _sameBoundaryTopology(left, right);
}

bool _sameSpaceOpeningRelations(
  ProjectEntityStores before,
  ProjectEntityStores after,
  SpaceId spaceId,
) {
  final left = before.openings.values
      .where((opening) => opening.connectedSpaceIds.contains(spaceId))
      .toList()
    ..sort((a, b) => a.id.value.compareTo(b.id.value));
  final right = after.openings.values
      .where((opening) => opening.connectedSpaceIds.contains(spaceId))
      .toList()
    ..sort((a, b) => a.id.value.compareTo(b.id.value));
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (!_sameOpening(left[index], right[index])) return false;
  }
  return true;
}

bool _sameSpaceAdjacencyRelations(
  ProjectEntityStores before,
  ProjectEntityStores after,
  SpaceId spaceId,
) {
  final left = before.adjacencies.values
      .where(
        (adjacency) =>
            adjacency.spaceAId == spaceId || adjacency.spaceBId == spaceId,
      )
      .toList()
    ..sort((a, b) => a.id.value.compareTo(b.id.value));
  final right = after.adjacencies.values
      .where(
        (adjacency) =>
            adjacency.spaceAId == spaceId || adjacency.spaceBId == spaceId,
      )
      .toList()
    ..sort((a, b) => a.id.value.compareTo(b.id.value));
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (!_sameAdjacency(left[index], right[index])) return false;
  }
  return true;
}

bool _entityExists(ProjectEntityStores stores, EntityId id) {
  if (id is SiteId) return stores.sites.containsKey(id);
  if (id is BuildingId) return stores.buildings.containsKey(id);
  if (id is LevelId) return stores.levels.containsKey(id);
  if (id is SlabId) return stores.slabs.containsKey(id);
  if (id is VerticalCoreId) return stores.verticalCores.containsKey(id);
  if (id is ZoneId) return stores.zones.containsKey(id);
  if (id is SpaceId) return stores.spaces.containsKey(id);
  if (id is OpeningId) return stores.openings.containsKey(id);
  if (id is SpaceAdjacencyId) return stores.adjacencies.containsKey(id);
  if (id is OverlayClassificationId) return stores.overlays.containsKey(id);
  if (id is BoundaryEdgeId) return _boundaryEdge(stores, id) != null;
  return false;
}

void _diffMap<K extends EntityId, V>(
  Map<K, V> before,
  Map<K, V> after,
  bool Function(V before, V after) same,
  Set<EntityId> added,
  Set<EntityId> updated,
  Set<EntityId> removed,
) {
  for (final entry in before.entries) {
    final afterValue = after[entry.key];
    if (afterValue == null) {
      removed.add(entry.key);
    } else if (!same(entry.value, afterValue)) {
      updated.add(entry.key);
    }
  }
  for (final key in after.keys) {
    if (!before.containsKey(key)) added.add(key);
  }
}

void _diffBoundaries(
  Map<SpaceId, SpaceBoundaryTopology> before,
  Map<SpaceId, SpaceBoundaryTopology> after,
  Set<EntityId> added,
  Set<EntityId> updated,
  Set<EntityId> removed,
) {
  final spaceIds = <SpaceId>{...before.keys, ...after.keys};
  for (final spaceId in spaceIds) {
    final previous = before[spaceId];
    final next = after[spaceId];

    if (previous == null && next != null) {
      _markBoundaryOwnerUpdated(spaceId, added, updated, removed);
      added.addAll(next.edges.keys);
      continue;
    }
    if (previous != null && next == null) {
      _markBoundaryOwnerUpdated(spaceId, added, updated, removed);
      removed.addAll(previous.edges.keys);
      continue;
    }
    if (previous == null || next == null) continue;

    if (!_sameBoundaryTopology(previous, next)) {
      _markBoundaryOwnerUpdated(spaceId, added, updated, removed);
    }

    for (final entry in previous.edges.entries) {
      final nextEdge = next.edges[entry.key];
      if (nextEdge == null) {
        removed.add(entry.key);
      } else if (!_sameBoundaryEdge(entry.value, nextEdge)) {
        updated.add(entry.key);
      }
    }
    for (final edgeId in next.edges.keys) {
      if (!previous.edges.containsKey(edgeId)) added.add(edgeId);
    }
  }
}

void _markBoundaryOwnerUpdated(
  SpaceId spaceId,
  Set<EntityId> added,
  Set<EntityId> updated,
  Set<EntityId> removed,
) {
  if (!added.contains(spaceId) && !removed.contains(spaceId)) {
    updated.add(spaceId);
  }
}

bool _sameSite(ProjectSiteEntity a, ProjectSiteEntity b) =>
    a.id == b.id && a.name == b.name && _sameSet(a.buildingIds, b.buildingIds);

bool _sameBuilding(ProjectBuildingEntity a, ProjectBuildingEntity b) =>
    a.id == b.id &&
    a.siteId == b.siteId &&
    a.name == b.name &&
    a.displayOrder == b.displayOrder &&
    _sameSet(a.levelIds, b.levelIds);

bool _sameLevel(ProjectLevelEntity a, ProjectLevelEntity b) =>
    a.id == b.id &&
    a.buildingId == b.buildingId &&
    a.name == b.name &&
    a.levelNumber == b.levelNumber &&
    a.kind == b.kind &&
    a.floorToFloorHeightMm == b.floorToFloorHeightMm &&
    a.displayOrder == b.displayOrder &&
    a.elevationMm == b.elevationMm &&
    _sameSet(a.zoneIds, b.zoneIds) &&
    _sameSet(a.spaceIds, b.spaceIds);

bool _sameSlab(ProjectSlab a, ProjectSlab b) {
  if (a.id != b.id ||
      a.buildingId != b.buildingId ||
      a.kind != b.kind ||
      a.belowLevelId != b.belowLevelId ||
      a.aboveLevelId != b.aboveLevelId ||
      a.bottomElevationMm != b.bottomElevationMm ||
      a.thicknessMm != b.thicknessMm ||
      a.materialId != b.materialId ||
      a.footprint.length != b.footprint.length) {
    return false;
  }
  for (var index = 0; index < a.footprint.length; index++) {
    final left = a.footprint[index];
    final right = b.footprint[index];
    if (left.xMm != right.xMm || left.yMm != right.yMm) return false;
  }
  return true;
}

bool _sameVerticalCore(ProjectVerticalCore a, ProjectVerticalCore b) {
  if (a.id != b.id ||
      a.buildingId != b.buildingId ||
      a.kind != b.kind ||
      a.usage != b.usage ||
      a.name != b.name ||
      !_sameSet(a.levelIds, b.levelIds) ||
      !_sameMap(a.hostSpaceIdsByLevel, b.hostSpaceIdsByLevel) ||
      a.footprint.length != b.footprint.length) {
    return false;
  }
  for (var index = 0; index < a.footprint.length; index++) {
    final left = a.footprint[index];
    final right = b.footprint[index];
    if (left.xMm != right.xMm || left.yMm != right.yMm) return false;
  }
  return true;
}

bool _sameZone(ProjectStructuralZoneEntity a, ProjectStructuralZoneEntity b) =>
    a.id == b.id &&
    a.levelId == b.levelId &&
    a.name == b.name &&
    a.kind == b.kind &&
    _sameSet(a.spaceIds, b.spaceIds);

bool _sameSpace(ProjectSpaceEntity a, ProjectSpaceEntity b) =>
    a.id == b.id &&
    a.levelId == b.levelId &&
    a.name == b.name &&
    a.type == b.type &&
    a.usage == b.usage;

bool _sameOpening(ProjectOpeningEntity a, ProjectOpeningEntity b) =>
    a.id == b.id &&
    a.levelId == b.levelId &&
    a.kind == b.kind &&
    _sameSet(a.connectedSpaceIds, b.connectedSpaceIds) &&
    a.widthMm == b.widthMm &&
    a.heightMm == b.heightMm &&
    a.baseElevationMm == b.baseElevationMm;

bool _sameAdjacency(
  ProjectSpaceAdjacencyEntity a,
  ProjectSpaceAdjacencyEntity b,
) =>
    a.id == b.id &&
    a.spaceAId == b.spaceAId &&
    a.spaceBId == b.spaceBId &&
    a.kind == b.kind &&
    a.openingId == b.openingId;

bool _sameOverlay(
  ProjectOverlayClassificationEntity a,
  ProjectOverlayClassificationEntity b,
) =>
    a.id == b.id &&
    a.name == b.name &&
    a.discipline == b.discipline &&
    a.kind == b.kind &&
    _sameSet(a.spaceIds, b.spaceIds);

bool _sameBoundaryTopology(
  SpaceBoundaryTopology a,
  SpaceBoundaryTopology b,
) {
  if (a.spaceId != b.spaceId ||
      a.orderedEdgeIds.length != b.orderedEdgeIds.length ||
      a.edges.length != b.edges.length) {
    return false;
  }
  for (var index = 0; index < a.orderedEdgeIds.length; index++) {
    if (a.orderedEdgeIds[index] != b.orderedEdgeIds[index]) return false;
  }
  for (final entry in a.edges.entries) {
    final other = b.edges[entry.key];
    if (other == null || !_sameBoundaryEdge(entry.value, other)) return false;
  }
  return true;
}

bool _sameBoundaryEdge(ProjectBoundaryEdge a, ProjectBoundaryEdge b) =>
    a.id == b.id &&
    a.spaceId == b.spaceId &&
    a.start == b.start &&
    a.end == b.end;

bool _sameSet<T>(Set<T> a, Set<T> b) =>
    a.length == b.length && a.containsAll(b);

bool _sameMap<K, V>(Map<K, V> a, Map<K, V> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (b[entry.key] != entry.value) return false;
  }
  return true;
}

bool _hasOverlap(Set<EntityId> a, Set<EntityId> b) => a.any(b.contains);
