import '../../domain/project_aggregate.dart';
import '../../domain/project_identity.dart';
import 'project_mutation.dart';
import 'project_repository.dart';
import 'project_snapshot.dart';

/// Synchronous ownership boundary for one production canonical project.
///
/// A canonical mutation is already committed when it reaches this owner. The
/// owner therefore accepts or rejects the exact next aggregate synchronously so
/// UI/history code can distinguish "owned by the production host" from
/// "scheduled for asynchronous storage". Repository persistence remains an
/// explicit asynchronous operation and must never be confused with ownership
/// acknowledgement.
final class CanonicalProjectPersistenceOwner {
  CanonicalProjectPersistenceOwner({
    required ProjectSnapshot snapshot,
    required ProjectRepository repository,
  })  : _snapshot = snapshot,
        _repository = repository;

  final ProjectRepository _repository;
  ProjectSnapshot _snapshot;

  ProjectSnapshot get snapshot => _snapshot;
  ProjectAggregateRoot get project => _snapshot.aggregate;
  ProjectId get projectId => _snapshot.id;
  LocalProjectVersion get version => _snapshot.localVersion;

  /// Takes synchronous ownership of the exact next canonical mutation.
  ///
  /// [sessionProject] must be the same committed aggregate instance exposed by
  /// the authoring session after the mutation. This prevents a caller from
  /// acknowledging a semantically similar but foreign/reconstructed project.
  /// The owner never repairs version gaps and never accepts another ProjectId.
  void acceptMutation({
    required ProjectAggregateRoot sessionProject,
    required ProjectMutationResult result,
    DateTime? now,
  }) {
    final current = _snapshot.aggregate;
    final changeSet = result.changeSet;
    final committed = result.project;

    if (committed.id != current.id || sessionProject.id != current.id) {
      throw StateError(
        'Canonical persistence owner ${current.id} cannot accept project '
        '${committed.id}.',
      );
    }
    if (!identical(sessionProject, committed)) {
      throw StateError(
        'Canonical persistence owner requires the exact committed session '
        'aggregate instance.',
      );
    }
    if (changeSet.beforeVersion != current.version ||
        changeSet.afterVersion != committed.version ||
        committed.version.value != current.version.value + 1) {
      throw StateError(
        'Canonical persistence owner expected version ${current.version.value} '
        '-> ${current.version.value + 1}, received '
        '${changeSet.beforeVersion.value} -> ${changeSet.afterVersion.value}.',
      );
    }

    final acceptedAt = (now ?? DateTime.now()).toUtc();
    final updatedAt = acceptedAt.isBefore(_snapshot.updatedAt)
        ? _snapshot.updatedAt
        : acceptedAt;
    _snapshot = _snapshot.copyWith(
      aggregate: committed,
      updatedAt: updatedAt,
    );
  }

  /// Persists the currently owned snapshot.
  ///
  /// Callers must await this method before presenting an explicit user Save as
  /// durable. A successful synchronous [acceptMutation] alone is deliberately
  /// not a disk-durability receipt.
  Future<void> save() => _repository.save(_snapshot);

  /// Loads an already persisted canonical owner. Missing persistence is
  /// reported explicitly as null; bootstrap/migration policy belongs to the
  /// production composition root rather than this ownership primitive.
  static Future<CanonicalProjectPersistenceOwner?> load({
    required ProjectRepository repository,
    required ProjectId projectId,
  }) async {
    final snapshot = await repository.load(projectId);
    if (snapshot == null) return null;
    if (snapshot.id != projectId) {
      throw StateError(
        'Canonical repository returned ${snapshot.id} for requested $projectId.',
      );
    }
    return CanonicalProjectPersistenceOwner(
      snapshot: snapshot,
      repository: repository,
    );
  }
}
