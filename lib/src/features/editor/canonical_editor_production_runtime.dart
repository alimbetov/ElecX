import '../../application/project/project_structure_authoring.dart';
import '../../domain/project_identity.dart';
import 'canonical_editor_runtime_cutover.dart';
import 'canonical_editor_workspace_adapter.dart';
import 'canonical_project_navigator.dart';
import 'editor_building_workspace.dart';
import 'project_persistence_metadata.dart';

/// Resolves the canonical runtime that corresponds to one concrete legacy
/// editor workspace instance.
///
/// Returning null keeps that workspace on the legacy navigator. This is the
/// fail-closed path for documents/recovery snapshots that do not yet have a
/// canonical project representation and explicit identity bindings.
typedef CanonicalEditorRuntimeResolver = CanonicalEditorResolvedRuntime? Function(
  EditorBuildingWorkspace workspace,
  EditorProjectMetadata metadata,
);

typedef CanonicalProductionAuthoringCommittedCallback = void Function(
  ProjectStructureAuthoringSession session,
  EntityId createdId,
);

final class CanonicalEditorResolvedRuntime {
  const CanonicalEditorResolvedRuntime({
    required this.session,
    required this.binding,
    this.materializer = const ExistingBindingCanonicalEditorMaterializer(),
  });

  final ProjectStructureAuthoringSession session;
  final CanonicalEditorWorkspaceBinding binding;
  final CanonicalEditorMaterializer materializer;
}

/// Opt-in production cutover configuration for [UnifiedWorkspaceEditorScreen].
///
/// The screen asks [resolveRuntime] again whenever its legacy workspace is
/// replaced by open/recovery. This prevents a binding that points at a disposed
/// workspace from surviving a project lifecycle transition.
///
/// Canonical authoring is enabled only when [onAuthoringCommitted] is supplied.
/// The existing screen Save path serializes the transitional editor document,
/// not ProjectAggregateRoot, so enabling +Building/+Level/+Room without an
/// external canonical persistence owner would otherwise create unsaved state.
final class CanonicalEditorProductionRuntimeConfig {
  const CanonicalEditorProductionRuntimeConfig({
    required this.resolveRuntime,
    this.requestBuilding,
    this.requestLevel,
    this.requestRoom,
    this.onAuthoringCommitted,
  });

  final CanonicalEditorRuntimeResolver resolveRuntime;
  final BuildingRequestResolver? requestBuilding;
  final LevelRequestResolver? requestLevel;
  final RoomRequestResolver? requestRoom;
  final CanonicalProductionAuthoringCommittedCallback? onAuthoringCommitted;

  bool get authoringEnabled => onAuthoringCommitted != null;
}
