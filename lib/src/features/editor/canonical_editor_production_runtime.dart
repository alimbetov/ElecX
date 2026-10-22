import '../../application/project/project_mutation.dart';
import '../../application/project/project_north_editing.dart';
import '../../application/project/project_structure_authoring.dart';
import '../../domain/project_identity.dart';
import 'canonical_editor_runtime_cutover.dart';
import 'canonical_editor_workspace_adapter.dart';
import 'canonical_project_navigator.dart';
import 'editor_building_workspace.dart';
import 'project_persistence_metadata.dart';

export '../../application/project/project_mutation.dart'
    show ProjectMutationResult;

/// Resolves the canonical runtime that corresponds to one concrete legacy
/// editor workspace instance.
///
/// Returning null keeps that workspace on the legacy navigator. This is the
/// fail-closed path for documents/recovery snapshots that do not yet have a
/// canonical project representation and explicit identity bindings.
typedef CanonicalEditorRuntimeResolver = CanonicalEditorResolvedRuntime?
    Function(
  EditorBuildingWorkspace workspace,
  EditorProjectMetadata metadata,
);

/// Explicit acknowledgement that the production host has synchronously taken
/// ownership of a committed canonical mutation.
///
/// This is deliberately not a durable-save acknowledgement. The host may
/// persist through the canonical repository workflow later, but once this
/// receipt is returned it owns the committed canonical state and must not treat
/// it as a best-effort event.
final class CanonicalAuthoringOwnershipReceipt {
  const CanonicalAuthoringOwnershipReceipt.accepted();
}

typedef CanonicalProductionAuthoringCommittedCallback
    = CanonicalAuthoringOwnershipReceipt Function(
  ProjectStructureAuthoringSession session,
  EntityId createdId,
);

typedef CanonicalProductionProjectNorthCommittedCallback
    = CanonicalAuthoringOwnershipReceipt Function(
  ProjectNorthEditingPort editing,
  ProjectMutationResult result,
);

final class CanonicalEditorResolvedRuntime {
  const CanonicalEditorResolvedRuntime({
    required this.session,
    required this.binding,
    this.materializer = const ExistingBindingCanonicalEditorMaterializer(),
    this.persistenceOwnerProjectId,
  });

  final ProjectStructureAuthoringSession session;
  final CanonicalEditorWorkspaceBinding binding;
  final CanonicalEditorMaterializer materializer;

  /// Exact canonical project for which the production host accepts persistence
  /// ownership. Null keeps Project North read-only even when a canonical
  /// runtime is available.
  final ProjectId? persistenceOwnerProjectId;
}

/// Opt-in production cutover configuration for [UnifiedWorkspaceEditorScreen].
///
/// The screen asks [resolveRuntime] again whenever its legacy workspace is
/// replaced by open/recovery. This prevents a binding that points at a disposed
/// workspace from surviving a project lifecycle transition.
///
/// Canonical structure authoring is enabled only when [onAuthoringCommitted] is
/// supplied. Project North editing is independently enabled only when the
/// resolved runtime persistence-owner identity matches the screen/canonical
/// project and [onProjectNorthCommitted] is supplied. The editing capability is
/// obtained from [ProjectStructureAuthoringSession.projectNorthEditing], which
/// guarantees that structure and root-metadata edits share one P3 timeline.
///
/// Both callbacks are synchronous ownership-transfer boundaries. They do not
/// claim durable disk/backend save completion.
final class CanonicalEditorProductionRuntimeConfig {
  const CanonicalEditorProductionRuntimeConfig({
    required this.resolveRuntime,
    this.requestBuilding,
    this.requestLevel,
    this.requestRoom,
    this.onAuthoringCommitted,
    this.onProjectNorthCommitted,
  });

  final CanonicalEditorRuntimeResolver resolveRuntime;
  final BuildingRequestResolver? requestBuilding;
  final LevelRequestResolver? requestLevel;
  final RoomRequestResolver? requestRoom;
  final CanonicalProductionAuthoringCommittedCallback? onAuthoringCommitted;
  final CanonicalProductionProjectNorthCommittedCallback?
      onProjectNorthCommitted;

  bool get authoringEnabled => onAuthoringCommitted != null;
}
