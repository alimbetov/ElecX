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

/// One committed canonical change boundary.
final class ProjectChangeSet {
  ProjectChangeSet({
    required this.kind,
    required this.commandType,
    required this.beforeVersion,
    required this.afterVersion,
    Iterable<EntityId> affectedEntityIds = const <EntityId>[],
  }) : affectedEntityIds = Set<EntityId>.unmodifiable(affectedEntityIds) {
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
  }

  final ProjectChangeKind kind;
  final String commandType;
  final LocalProjectVersion beforeVersion;
  final LocalProjectVersion afterVersion;
  final Set<EntityId> affectedEntityIds;
}

/// Validated but uncommitted command result.
final class ProjectMutationPreview {
  const ProjectMutationPreview({
    required this.candidate,
    required this.commandType,
    required this.affectedEntityIds,
  });

  final ProjectAggregateRoot candidate;
  final String commandType;
  final Set<EntityId> affectedEntityIds;
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
    Iterable<EntityId> affectedEntityIds = const <EntityId>[],
  }) : affectedEntityIds = Set<EntityId>.unmodifiable(affectedEntityIds) {
    if (commandType.trim().isEmpty) {
      throw ArgumentError.value(
        commandType,
        'commandType',
        'Must be non-empty.',
      );
    }
  }

  final String commandType;
  final ProjectEntityStores beforeStores;
  final ProjectEntityStores afterStores;
  final Set<EntityId> affectedEntityIds;
}

/// Atomic in-memory mutation boundary for one canonical project.
///
/// Protocol:
/// read N -> build candidate -> validate -> verify N -> commit N+1 ->
/// publish one ProjectChangeSet -> append one UndoRecord.
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
    final candidate = request.command.buildCandidate(_current);
    CandidateGraphValidator.validate(current: _current, candidate: candidate);

    final previewRoot = ProjectAggregateRoot(
      id: _current.id,
      siteId: _current.siteId,
      version: _current.version,
      stores: candidate.stores,
    );
    return ProjectMutationPreview(
      candidate: previewRoot,
      commandType: commandType,
      affectedEntityIds: candidate.affectedEntityIds,
    );
  }

  ProjectMutationResult commit(ProjectMutationRequest request) {
    _requireVersion(request.expectedVersion);
    final commandType = _requireCommandType(request.command);
    final before = _current;
    final candidate = request.command.buildCandidate(before);
    CandidateGraphValidator.validate(current: before, candidate: candidate);

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
      affectedEntityIds: candidate.affectedEntityIds,
    );

    _current = committed;
    _undoStack.add(
      UndoRecord(
        commandType: commandType,
        beforeStores: before.stores,
        afterStores: committed.stores,
        affectedEntityIds: candidate.affectedEntityIds,
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
    final restored = _commitStoredState(
      stores: record.beforeStores,
      before: before,
    );
    final changeSet = ProjectChangeSet(
      kind: ProjectChangeKind.undo,
      commandType: record.commandType,
      beforeVersion: before.version,
      afterVersion: restored.version,
      affectedEntityIds: record.affectedEntityIds,
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
    final restored = _commitStoredState(
      stores: record.afterStores,
      before: before,
    );
    final changeSet = ProjectChangeSet(
      kind: ProjectChangeKind.redo,
      commandType: record.commandType,
      beforeVersion: before.version,
      afterVersion: restored.version,
      affectedEntityIds: record.affectedEntityIds,
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
