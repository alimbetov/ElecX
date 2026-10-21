import '../../domain/project_aggregate.dart';
import '../../domain/project_identity.dart';

/// Describes one semantic application command against the canonical project.
///
/// Commands build immutable candidate stores only. They never mutate the live
/// [ProjectAggregateRoot] and never advance [LocalProjectVersion] themselves.
abstract interface class ProjectCommand {
  String get commandType;

  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current);
}

/// Immutable candidate produced by one [ProjectCommand].
///
/// [affectedEntityIds] is a command-provided hint only. The mutation engine
/// computes the authoritative [ProjectEntityDiff] from before/after stores and
/// never trusts this hint for invalidation, persistence or Undo semantics.
final class ProjectCommandCandidate {
  ProjectCommandCandidate({
    required this.stores,
    Iterable<EntityId> affectedEntityIds = const <EntityId>[],
  }) : affectedEntityIds = Set<EntityId>.unmodifiable(affectedEntityIds);

  final ProjectEntityStores stores;
  final Set<EntityId> affectedEntityIds;
}

/// Optimistic local mutation request.
final class ProjectMutationRequest {
  const ProjectMutationRequest({
    required this.expectedVersion,
    required this.command,
  });

  final LocalProjectVersion expectedVersion;
  final ProjectCommand command;
}

enum ProjectChangeKind {
  command,
  undo,
  redo,
}

/// Authoritative semantic entity delta between two canonical store snapshots.
///
/// The three sets are disjoint. [affectedEntityIds] is derived from their union
/// and is therefore safe for incremental projections and invalidation.
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

    _diffMap<SiteId, ProjectSiteEntity>(
      before.sites,
      after.sites,
      _sameSite,
      added,
      updated,
      removed,
    );
    _diffMap<BuildingId, ProjectBuildingEntity>(
      before.buildings,
      after.buildings,
      _sameBuilding,
      added,
      updated,
      removed,
    );
    _diffMap<LevelId, ProjectLevelEntity>(
      before.levels,
      after.levels,
      _sameLevel,
      added,
      updated,
      removed,
    );
    _diffMap<ZoneId, ProjectStructuralZoneEntity>(
      before.zones,
      after.zones,
      _sameZone,
      added,
      updated,
      removed,
    );
    _diffMap<SpaceId, ProjectSpaceEntity>(
      before.spaces,
      after.spaces,
      _sameSpace,
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

  Set<EntityId> get affectedEntityIds => Set<EntityId>.unmodifiable(
        <EntityId>{
          ...addedEntityIds,
          ...updatedEntityIds,
          ...removedEntityIds,
        },
      );

  bool get isEmpty =>
      addedEntityIds.isEmpty &&
      updatedEntityIds.isEmpty &&
      removedEntityIds.isEmpty;

  bool get isNotEmpty => !isEmpty;
}

/// One committed canonical change boundary.
final class ProjectChangeSet {
  ProjectChangeSet({
    required this.kind,
    required this.commandType,
    required this.beforeVersion,
    required this.afterVersion,
    required this.diff,
  }) {
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
    if (diff.isEmpty) {
      throw ArgumentError(
        'A committed ProjectChangeSet must contain a non-empty entity diff.',
      );
    }
  }

  final ProjectChangeKind kind;
  final String commandType;
  final LocalProjectVersion beforeVersion;
  final LocalProjectVersion afterVersion;
  final ProjectEntityDiff diff;

  Set<EntityId> get addedEntityIds => diff.addedEntityIds;
  Set<EntityId> get updatedEntityIds => diff.updatedEntityIds;
  Set<EntityId> get removedEntityIds => diff.removedEntityIds;
  Set<EntityId> get affectedEntityIds => diff.affectedEntityIds;
}

/// Validated but uncommitted command result.
final class ProjectMutationPreview {
  ProjectMutationPreview({
    required this.candidate,
    required this.commandType,
    required this.diff,
    Iterable<EntityId> declaredAffectedEntityIds = const <EntityId>[],
  }) : declaredAffectedEntityIds =
            Set<EntityId>.unmodifiable(declaredAffectedEntityIds);

  final ProjectAggregateRoot candidate;
  final String commandType;
  final ProjectEntityDiff diff;
  final Set<EntityId> declaredAffectedEntityIds;

  Set<EntityId> get affectedEntityIds => diff.affectedEntityIds;
  bool get hasChanges => diff.isNotEmpty;
}

/// Successful committed command/undo/redo result.
final class ProjectMutationResult {
  const ProjectMutationResult({
    required this.project,
    required this.changeSet,
  });

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

/// Application-level candidate graph gate used before canonical commit.
abstract final class CandidateGraphValidator {
  static void validate({
    required ProjectAggregateRoot current,
    required ProjectCommandCandidate candidate,
  }) {
    final issues = ProjectAggregateValidator.validate(
      rootSiteId: current.siteId,
      stores: candidate.stores,
    );
    if (issues.isNotEmpty) {
      throw ProjectCandidateValidationException(issues);
    }

    final index = ProjectIndex.build(candidate.stores);
    if (!index.isConsistentWith(candidate.stores)) {
      throw StateError('Candidate ProjectIndex is inconsistent with stores.');
    }
  }
}

/// One original command boundary retained for deterministic undo/redo.
///
/// P3 intentionally stores immutable before/after entity stores. Later stages
/// may compact records, but undo semantics must remain one semantic command per
/// record and must never restore an older LocalProjectVersion value.
final class UndoRecord {
  UndoRecord({
    required this.commandType,
    required this.beforeStores,
    required this.afterStores,
  }) {
    if (commandType.trim().isEmpty) {
      throw ArgumentError.value(
        commandType,
        'commandType',
        'Must be non-empty.',
      );
    }
    if (ProjectEntityDiff.between(beforeStores, afterStores).isEmpty) {
      throw ArgumentError(
        'UndoRecord requires different before/after canonical stores.',
      );
    }
  }

  final String commandType;
  final ProjectEntityStores beforeStores;
  final ProjectEntityStores afterStores;
}

/// Atomic in-memory mutation boundary for one canonical project.
///
/// Protocol:
/// read N -> build candidate -> validate -> compute authoritative diff ->
/// verify N -> commit N+1 -> publish one ProjectChangeSet -> append one
/// UndoRecord. A semantically empty candidate is suppressed as a no-op.
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
    final diff = ProjectEntityDiff.between(before.stores, candidate.stores);

    final previewRoot = ProjectAggregateRoot(
      id: before.id,
      siteId: before.siteId,
      version: before.version,
      stores: candidate.stores,
    );
    return ProjectMutationPreview(
      candidate: previewRoot,
      commandType: commandType,
      diff: diff,
      declaredAffectedEntityIds: candidate.affectedEntityIds,
    );
  }

  /// Commits one semantic command, or returns `null` for a semantic no-op.
  ///
  /// A no-op does not advance the local version and does not create Undo/Redo
  /// history. This prevents redundant autosave/sync/projection invalidation.
  ProjectMutationResult? commit(ProjectMutationRequest request) {
    _requireVersion(request.expectedVersion);
    final commandType = _requireCommandType(request.command);
    final before = _current;
    final candidate = request.command.buildCandidate(before);
    CandidateGraphValidator.validate(current: before, candidate: candidate);
    final diff = ProjectEntityDiff.between(before.stores, candidate.stores);
    if (diff.isEmpty) return null;

    // Keep the optimistic guard explicit at the commit boundary. The current
    // implementation is synchronous, but this invariant remains mandatory if
    // candidate construction later moves across async/isolate boundaries.
    _requireVersion(request.expectedVersion);

    final committed = ProjectAggregateRoot(
      id: before.id,
      siteId: before.siteId,
      version: before.version.next(),
      stores: candidate.stores,
    );
    final changeSet = ProjectChangeSet(
      kind: ProjectChangeKind.command,
      commandType: commandType,
      beforeVersion: before.version,
      afterVersion: committed.version,
      diff: diff,
    );

    _current = committed;
    _undoStack.add(
      UndoRecord(
        commandType: commandType,
        beforeStores: before.stores,
        afterStores: committed.stores,
      ),
    );
    _redoStack.clear();

    return ProjectMutationResult(project: committed, changeSet: changeSet);
  }

  ProjectMutationResult? undo(LocalProjectVersion expectedVersion) {
    _requireVersion(expectedVersion);
    if (_undoStack.isEmpty) return null;

    final before = _current;
    final record = _undoStack.last;
    final diff = ProjectEntityDiff.between(before.stores, record.beforeStores);
    if (diff.isEmpty) return null;

    final restored = _commitStoredState(
      stores: record.beforeStores,
      before: before,
    );
    final changeSet = ProjectChangeSet(
      kind: ProjectChangeKind.undo,
      commandType: record.commandType,
      beforeVersion: before.version,
      afterVersion: restored.version,
      diff: diff,
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
    final record = _redoStack.last;
    final diff = ProjectEntityDiff.between(before.stores, record.afterStores);
    if (diff.isEmpty) return null;

    final restored = _commitStoredState(
      stores: record.afterStores,
      before: before,
    );
    final changeSet = ProjectChangeSet(
      kind: ProjectChangeKind.redo,
      commandType: record.commandType,
      beforeVersion: before.version,
      afterVersion: restored.version,
      diff: diff,
    );

    _current = restored;
    _redoStack.removeLast();
    _undoStack.add(record);
    return ProjectMutationResult(project: restored, changeSet: changeSet);
  }

  ProjectAggregateRoot _commitStoredState({
    required ProjectEntityStores stores,
    required ProjectAggregateRoot before,
  }) {
    final issues = ProjectAggregateValidator.validate(
      rootSiteId: before.siteId,
      stores: stores,
    );
    if (issues.isNotEmpty) {
      throw ProjectCandidateValidationException(issues);
    }
    return ProjectAggregateRoot(
      id: before.id,
      siteId: before.siteId,
      version: before.version.next(),
      stores: stores,
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
    a.id == b.id && a.levelId == b.levelId && a.name == b.name;

bool _sameSet<T>(Set<T> a, Set<T> b) =>
    a.length == b.length && a.containsAll(b);

bool _hasOverlap(Set<EntityId> a, Set<EntityId> b) => a.any(b.contains);
