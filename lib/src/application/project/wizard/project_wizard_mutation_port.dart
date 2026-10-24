import '../../../domain/project_aggregate.dart';
import '../../../domain/project_identity.dart';
import '../project_mutation.dart';
import '../project_mutation_reservation.dart';

/// Application boundary used by Wizard flows to preview and commit one frozen
/// reserved mutation on the same canonical timeline as ordinary authoring.
///
/// The port deliberately does not expose the underlying [ProjectMutationSession]
/// so Wizard code cannot create a second version/history owner or bypass the
/// reserved preview lifecycle.
abstract interface class ProjectWizardMutationPort {
  ProjectAggregateRoot get project;
  LocalProjectVersion get version;

  ReservedProjectMutationPreview preview(ReservedProjectCommand command);

  /// Permanently invalidates a prepared preview that the Wizard no longer
  /// presents as confirmable. Cancel, Back, parameter edits and explicit
  /// rebase all use this boundary so a retained preview reference cannot be
  /// committed later through the same port.
  void discardPreview(ReservedProjectMutationPreview preview);

  ReservedProjectMutationCommitResult? commitPreview(
    ReservedProjectMutationPreview preview,
  );
}

final class DiscardedWizardPreviewException implements Exception {
  const DiscardedWizardPreviewException();

  @override
  String toString() => 'Wizard preview was discarded and cannot be committed.';
}

/// Production/default implementation bound to an existing canonical mutation
/// session. Callers must pass the exact [ProjectMutationSession] and
/// [EntityIdFactory] already owned by the project authoring composition root.
///
/// Creating a new ProjectMutationSession from `project` is intentionally not
/// supported here because that would fork versioning and Undo/Redo history.
final class SharedProjectWizardMutationPort
    implements ProjectWizardMutationPort {
  SharedProjectWizardMutationPort({
    required ProjectMutationSession mutations,
    required EntityIdFactory idFactory,
  })  : _mutations = mutations,
        _coordinator = ReservedProjectMutationCoordinator(
          mutations,
          entityIdFactory: idFactory,
        );

  final ProjectMutationSession _mutations;
  final ReservedProjectMutationCoordinator _coordinator;
  final Set<ReservedProjectMutationPreview> _discardedPreviews =
      Set<ReservedProjectMutationPreview>.identity();

  @override
  ProjectAggregateRoot get project => _mutations.current;

  @override
  LocalProjectVersion get version => _mutations.current.version;

  @override
  ReservedProjectMutationPreview preview(ReservedProjectCommand command) =>
      _coordinator.preview(command);

  @override
  void discardPreview(ReservedProjectMutationPreview preview) {
    _discardedPreviews.add(preview);
  }

  @override
  ReservedProjectMutationCommitResult? commitPreview(
    ReservedProjectMutationPreview preview,
  ) {
    if (_discardedPreviews.contains(preview)) {
      throw const DiscardedWizardPreviewException();
    }
    return _coordinator.commitPreview(preview);
  }
}
