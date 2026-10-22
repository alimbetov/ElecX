import '../../domain/project_aggregate.dart';
import 'project_mutation.dart';

/// Post-commit notification emitted exactly once for every successful canonical
/// command, undo or redo commit.
///
/// No-op previews/commands and failed mutations do not produce an event.
final class ProjectCommittedEvent {
  const ProjectCommittedEvent({required this.project, required this.changeSet});

  final ProjectAggregateRoot project;
  final ProjectChangeSet changeSet;
}

/// Application boundary for committed project notifications.
///
/// Publishers are expected to deliver synchronously without throwing. Storage,
/// navigator projections and autosave may subscribe behind an implementation of
/// this contract without coupling the mutation engine to UI or infrastructure.
abstract interface class ProjectCommitPublisher {
  void publish(ProjectCommittedEvent event);
}

final class NoopProjectCommitPublisher implements ProjectCommitPublisher {
  const NoopProjectCommitPublisher();

  @override
  void publish(ProjectCommittedEvent event) {}
}

/// Application-facing mutation facade that guarantees committed-change
/// publication while preserving [ProjectMutationSession] as the atomic state
/// transition engine.
final class PublishingProjectMutationSession {
  PublishingProjectMutationSession({
    required ProjectAggregateRoot initial,
    ProjectCommitPublisher publisher = const NoopProjectCommitPublisher(),
  })  : _session = ProjectMutationSession(initial),
        _publisher = publisher;

  final ProjectMutationSession _session;
  final ProjectCommitPublisher _publisher;

  ProjectAggregateRoot get current => _session.current;
  int get undoDepth => _session.undoDepth;
  int get redoDepth => _session.redoDepth;
  bool get canUndo => _session.canUndo;
  bool get canRedo => _session.canRedo;

  ProjectMutationPreview preview(ProjectMutationRequest request) =>
      _session.preview(request);

  ProjectMutationResult? commit(ProjectMutationRequest request) {
    final result = _session.commit(request);
    return _publishIfCommitted(result);
  }

  ProjectMutationResult? undo(LocalProjectVersion expectedVersion) {
    final result = _session.undo(expectedVersion);
    return _publishIfCommitted(result);
  }

  ProjectMutationResult? redo(LocalProjectVersion expectedVersion) {
    final result = _session.redo(expectedVersion);
    return _publishIfCommitted(result);
  }

  ProjectMutationResult? _publishIfCommitted(ProjectMutationResult? result) {
    if (result == null) return null;
    _publisher.publish(
      ProjectCommittedEvent(
        project: result.project,
        changeSet: result.changeSet,
      ),
    );
    return result;
  }
}
