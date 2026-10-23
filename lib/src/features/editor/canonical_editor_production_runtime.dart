import '../../application/project/project_boundary_topology_editing.dart';
import '../../application/project/project_mutation.dart';
import '../../application/project/project_north_editing.dart';
import '../../application/project/project_space_semantics_editing.dart';
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
typedef CanonicalEditorRuntimeResolver = CanonicalEditorResolvedRuntime?
    Function(
  EditorBuildingWorkspace workspace,
  EditorProjectMetadata metadata,
);

/// Explicit acknowledgement that the production host has synchronously taken
/// ownership of a committed canonical mutation.
final class CanonicalAuthoringOwnershipReceipt {
  const CanonicalAuthoringOwnershipReceipt.accepted();
}

/// Project-wide P3 ownership boundary. Every canonical command, undo and redo
/// is a new committed version and must pass through this callback before the
/// production history considers the transition fully owned.
typedef CanonicalProductionMutationCommittedCallback
    = CanonicalAuthoringOwnershipReceipt Function(
  ProjectStructureAuthoringSession session,
  ProjectMutationResult result,
);

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

typedef CanonicalProductionSpaceSemanticsCommittedCallback
    = CanonicalAuthoringOwnershipReceipt Function(
  ProjectSpaceSemanticsEditingPort editing,
  ProjectMutationResult result,
);

typedef CanonicalProductionBoundaryTopologyCommittedCallback
    = CanonicalAuthoringOwnershipReceipt Function(
  ProjectBoundaryTopologyEditingPort editing,
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

  final ProjectId? persistenceOwnerProjectId;
}

/// Opt-in production cutover configuration for [UnifiedWorkspaceEditorScreen].
///
/// Feature callbacks remain feature-level hooks. [onCanonicalMutationCommitted]
/// is the authoritative persistence/history ownership boundary for the shared
/// P3 timeline and is required for production canonical write capabilities.
final class CanonicalEditorProductionRuntimeConfig {
  const CanonicalEditorProductionRuntimeConfig({
    required this.resolveRuntime,
    this.requestBuilding,
    this.requestLevel,
    this.requestRoom,
    this.onCanonicalMutationCommitted,
    this.onAuthoringCommitted,
    this.onProjectNorthCommitted,
    this.onSpaceSemanticsCommitted,
    this.onBoundaryTopologyCommitted,
  });

  final CanonicalEditorRuntimeResolver resolveRuntime;
  final BuildingRequestResolver? requestBuilding;
  final LevelRequestResolver? requestLevel;
  final RoomRequestResolver? requestRoom;
  final CanonicalProductionMutationCommittedCallback?
      onCanonicalMutationCommitted;
  final CanonicalProductionAuthoringCommittedCallback? onAuthoringCommitted;
  final CanonicalProductionProjectNorthCommittedCallback?
      onProjectNorthCommitted;
  final CanonicalProductionSpaceSemanticsCommittedCallback?
      onSpaceSemanticsCommitted;
  final CanonicalProductionBoundaryTopologyCommittedCallback?
      onBoundaryTopologyCommitted;

  bool get authoringEnabled =>
      onCanonicalMutationCommitted != null && onAuthoringCommitted != null;
}
