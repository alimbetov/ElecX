import '../../domain/project_aggregate.dart';
import '../../domain/project_identity.dart';
import '../../domain/project_orientation.dart';
import '../../domain/project_space_semantics.dart';

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
/// preserves root engineering metadata plus all P6 semantic stores. This keeps
/// older structural commands from accidentally erasing P6 state.
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
      stores: ProjectEntityStores(
        sites: legacy.sites,
        buildings: legacy.buildings,
        levels: legacy.levels,
        zones: legacy.zones,
        spaces: legacy.spaces,
        openings: current.stores.openings,
        adjacencies: current.stores.adjacencies,
        overlays: current.stores.overlays,
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
  });

  const ProjectEngineeringMetadataDiff.empty()
      : beforeProjectNorth = null,
        afterProjectNorth = null;

  factory ProjectEngineeringMetadataDiff.between(
    ProjectEngineeringMetadata before,
    ProjectEngineeringMetadata after,
  ) =>
      ProjectEngineeringMetadataDiff(
        beforeProjectNorth: before.projectNorth,
        afterProjectNorth: after.projectNorth,
      );

  final ProjectEngineeringNorth? beforeProjectNorth;
  final ProjectEngineeringNorth? afterProjectNorth;

  bool get projectNorthChanged => beforeProjectNorth != afterProjectNorth;
  bool get isEmpty => !projectNorthChanged;
  bool get isNotEmpty => projectNorthChanged;
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
      throw ArgumentError.value(commandType, 'commandType', 'Must be non-empty.');
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
        declaredAffectedEntityIds =
            Set<EntityId>.unmodifiable(declaredAffectedEntityIds) {
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
  bool get hasChanges => entityDiff.isNotEmpty || engineeringMetadataDiff.isNotEmpty;
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
      throw ArgumentError.value(commandType, 'commandType', 'Must be non-empty.');
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
  ProjectMutationSession(ProjectAggregateRoot initial) : _current = initial;

  ProjectAggregateRoot _current;
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
    CandidateGraphValidator.validate(current: before, candidate: candidate);
    final candidateState = candidate.resolveState(before);
    final stateDiff = _ProjectMutableStateDiff.between(
      ProjectMutableState.fromProject(before),
      candidateState,
    );
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
    CandidateGraphValidator.validate(current: before, candidate: candidate);
    final candidateState = candidate.resolveState(before);
    final stateDiff = _ProjectMutableStateDiff.between(beforeState, candidateState);
    if (stateDiff.isEmpty) return null;
    _requireVersion(request.expectedVersion);

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
    final stateDiff = _ProjectMutableStateDiff.between(
      beforeState,
      record.beforeState,
    );
    if (stateDiff.isEmpty) {
      throw StateError('Undo history is inconsistent with current project state.');
    }
    final restored = _commitState(state: record.beforeState, before: before);
    final changeSet = ProjectChangeSet(
      kind: ProjectChangeKind.undo,
      commandType: record.commandType,
      beforeVersion: before.version,
      afterVersion: restored.version,
      entityDiff: stateDiff.entityDiff,
      engineeringMetadataDiff: stateDiff.engineeringMetadataDiff,
    );
    _current = restored;
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
    final stateDiff = _ProjectMutableStateDiff.between(
      beforeState,
      record.afterState,
    );
    if (stateDiff.isEmpty) {
      throw StateError('Redo history is inconsistent with current project state.');
    }
    final restored = _commitState(state: record.afterState, before: before);
    final changeSet = ProjectChangeSet(
      kind: ProjectChangeKind.redo,
      commandType: record.commandType,
      beforeVersion: before.version,
      afterVersion: restored.version,
      entityDiff: stateDiff.entityDiff,
      engineeringMetadataDiff: stateDiff.engineeringMetadataDiff,
    );
    _current = restored;
    _redoStack.removeLast();
    _undoStack.add(record);
    return ProjectMutationResult(project: restored, changeSet: changeSet);
  }

  ProjectAggregateRoot _commitState({
    required ProjectMutableState state,
    required ProjectAggregateRoot before,
  }) {
    final issues = ProjectAggregateValidator.validate(
      rootSiteId: before.siteId,
      stores: state.stores,
    );
    if (issues.isNotEmpty) {
      throw ProjectCandidateValidationException(issues);
    }
    return ProjectAggregateRoot(
      id: before.id,
      siteId: before.siteId,
      version: before.version.next(),
      engineeringMetadata: state.engineeringMetadata,
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
    a.displayOrder == b.displayOrder &&
    a.elevationMm == b.elevationMm &&
    _sameSet(a.zoneIds, b.zoneIds) &&
    _sameSet(a.spaceIds, b.spaceIds);

bool _sameZone(
  ProjectStructuralZoneEntity a,
  ProjectStructuralZoneEntity b,
) =>
    a.id == b.id &&
    a.levelId == b.levelId &&
    a.name == b.name &&
    _sameSet(a.spaceIds, b.spaceIds);

bool _sameSpace(ProjectSpaceEntity a, ProjectSpaceEntity b) =>
    a.id == b.id &&
    a.levelId == b.levelId &&
    a.name == b.name &&
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

bool _sameSet<T>(Set<T> a, Set<T> b) =>
    a.length == b.length && a.containsAll(b);

bool _hasOverlap(Set<EntityId> a, Set<EntityId> b) => a.any(b.contains);
