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

enum _WizardPreviewLifecycle { active, consumed, discarded }

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
        _idFactory = idFactory;

  final ProjectMutationSession _mutations;
  final EntityIdFactory _idFactory;

  /// Only live previews are retained strongly. Each preview gets a short-lived
  /// coordinator so its consumed-reservation tombstone becomes unreachable as
  /// soon as the preview reaches a terminal lifecycle state.
  final Map<ReservedProjectMutationPreview, ReservedProjectMutationCoordinator>
      _activePreviews = Map<ReservedProjectMutationPreview,
          ReservedProjectMutationCoordinator>.identity();

  /// Terminal lifecycle is attached weakly to the preview object. Expando does
  /// not keep discarded/consumed preview aggregates alive merely to reject a
  /// later stale reference.
  final Expando<_WizardPreviewLifecycle> _previewLifecycle =
      Expando<_WizardPreviewLifecycle>('wizardPreviewLifecycle');

  @override
  ProjectAggregateRoot get project => _mutations.current;

  @override
  LocalProjectVersion get version => _mutations.current.version;

  /// Qualification diagnostic: terminal previews must never accumulate here.
  int get activePreviewCount => _activePreviews.length;

  @override
  ReservedProjectMutationPreview preview(ReservedProjectCommand command) {
    final coordinator = ReservedProjectMutationCoordinator(
      _mutations,
      entityIdFactory: _idFactory,
    );
    final planned = coordinator.preview(command);
    _activePreviews[planned] = coordinator;
    _previewLifecycle[planned] = _WizardPreviewLifecycle.active;
    return planned;
  }

  @override
  void discardPreview(ReservedProjectMutationPreview preview) {
    final lifecycle = _previewLifecycle[preview];
    if (lifecycle == _WizardPreviewLifecycle.discarded ||
        lifecycle == _WizardPreviewLifecycle.consumed) {
      return;
    }
    _activePreviews.remove(preview);
    _previewLifecycle[preview] = _WizardPreviewLifecycle.discarded;
  }

  @override
  ReservedProjectMutationCommitResult? commitPreview(
    ReservedProjectMutationPreview preview,
  ) {
    final lifecycle = _previewLifecycle[preview];
    if (lifecycle == _WizardPreviewLifecycle.discarded) {
      throw const DiscardedWizardPreviewException();
    }
    if (lifecycle == _WizardPreviewLifecycle.consumed) {
      throw const ConsumedMutationReservationException();
    }

    final coordinator = _activePreviews[preview];
    if (coordinator == null) {
      throw const ForeignMutationPreviewException();
    }

    final result = coordinator.commitPreview(preview);
    if (result != null) {
      _activePreviews.remove(preview);
      _previewLifecycle[preview] = _WizardPreviewLifecycle.consumed;
    }
    return result;
  }
}
