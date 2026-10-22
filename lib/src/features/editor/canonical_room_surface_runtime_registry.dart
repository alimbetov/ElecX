import '../../application/project/project_boundary_topology_editing.dart';
import '../../application/project/project_mutation.dart';
import '../../domain/project_identity.dart';
import '../../domain/surfaces.dart';
import 'canonical_editor_runtime_cutover.dart';
import 'canonical_room_surface_cutover.dart';
import 'canonical_room_surface_resume.dart';
import 'canonical_room_surface_selection.dart';
import 'editor_controller.dart';

typedef CanonicalBoundaryTopologyOwnershipCallback = void Function(
  ProjectBoundaryTopologyEditingPort editing,
  ProjectMutationResult result,
);

typedef CanonicalMutationOwnershipCallback = void Function(
  ProjectMutationResult result,
);

/// Runtime-only bridge from the legacy EditorController instance to the exact
/// canonical cutover coordinator that owns it.
///
/// The registry stores no projection. Every resolve reads session.project at
/// call time, so a LocalProjectVersion change reconstructs the BoundaryEdgeId
/// projection instead of reusing stale ordinal affinity.
abstract final class CanonicalRoomSurfaceRuntimeRegistry {
  static final Expando<CanonicalEditorRuntimeCutoverCoordinator> _coordinators =
      Expando<CanonicalEditorRuntimeCutoverCoordinator>(
    'ElecX canonical room surface coordinator',
  );
  static final Expando<CanonicalRoomSurfaceResume> _stagedResumes =
      Expando<CanonicalRoomSurfaceResume>('ElecX canonical surface resume');
  static final Expando<CanonicalBoundaryTopologyOwnershipCallback>
      _topologyOwnership = Expando<CanonicalBoundaryTopologyOwnershipCallback>(
    'ElecX canonical boundary topology ownership',
  );
  static final Expando<CanonicalMutationOwnershipCallback> _canonicalOwnership =
      Expando<CanonicalMutationOwnershipCallback>(
    'ElecX canonical mutation ownership',
  );

  static void attach(
    CanonicalEditorRuntimeCutoverCoordinator coordinator, {
    CanonicalBoundaryTopologyOwnershipCallback? onBoundaryTopologyCommitted,
    CanonicalMutationOwnershipCallback? onCanonicalMutationCommitted,
  }) {
    final controller = coordinator.adapter.workspace.editor;
    _coordinators[controller] = coordinator;
    _topologyOwnership[controller] = onBoundaryTopologyCommitted;
    _canonicalOwnership[controller] = onCanonicalMutationCommitted;

    if (_stagedResumes[controller] == null &&
        controller.activeSurface?.type == SurfacePlaneType.wall) {
      controller.showPlan();
    }
  }

  static void detach(CanonicalEditorRuntimeCutoverCoordinator coordinator) {
    final controller = coordinator.adapter.workspace.editor;
    if (identical(_coordinators[controller], coordinator)) {
      _coordinators[controller] = null;
      _topologyOwnership[controller] = null;
      _canonicalOwnership[controller] = null;
    }
  }

  static bool hasCanonicalRuntime(EditorController controller) =>
      _coordinators[controller] != null;

  /// Internal production-cutover capability lookup. Callers must still resolve
  /// their own version-aware projection and may not cache it across mutations.
  static CanonicalEditorRuntimeCutoverCoordinator? coordinatorFor(
    EditorController controller,
  ) =>
      _coordinators[controller];

  static CanonicalBoundaryTopologyOwnershipCallback? topologyOwnershipFor(
    EditorController controller,
  ) =>
      _topologyOwnership[controller];

  static CanonicalMutationOwnershipCallback? canonicalOwnershipFor(
    EditorController controller,
  ) =>
      _canonicalOwnership[controller];

  static CanonicalRoomSurfaceSelectionAdapter? resolve(
    EditorController controller,
    SpaceId spaceId,
  ) {
    final coordinator = _coordinators[controller];
    if (coordinator == null) return null;
    try {
      return CanonicalRoomSurfaceCutover.resolve(
        project: coordinator.session.project,
        binding: coordinator.adapter.binding,
        workspace: coordinator.adapter.workspace,
        spaceId: spaceId,
      );
    } on CanonicalRoomSurfaceCutoverException {
      return null;
    }
  }

  static CanonicalRoomSurfaceResume? capture(EditorController controller) {
    final coordinator = _coordinators[controller];
    final spaceId = coordinator?.session.navigation.selectedSpaceId;
    if (coordinator == null || spaceId == null) return null;
    final adapter = resolve(controller, spaceId);
    if (adapter == null) return null;
    final selection = adapter.current();
    return switch (selection.kind) {
      CanonicalRoomSurfaceKind.plan => CanonicalRoomSurfaceResume(
          spaceId: spaceId,
          kind: CanonicalRoomSurfaceResumeKind.plan,
        ),
      CanonicalRoomSurfaceKind.floor => CanonicalRoomSurfaceResume(
          spaceId: spaceId,
          kind: CanonicalRoomSurfaceResumeKind.floor,
        ),
      CanonicalRoomSurfaceKind.ceiling => CanonicalRoomSurfaceResume(
          spaceId: spaceId,
          kind: CanonicalRoomSurfaceResumeKind.ceiling,
        ),
      CanonicalRoomSurfaceKind.wall => CanonicalRoomSurfaceResume(
          spaceId: spaceId,
          kind: CanonicalRoomSurfaceResumeKind.wall,
          boundaryEdgeId: selection.boundaryEdgeId,
        ),
    };
  }

  static void stageResume(
    EditorController controller,
    CanonicalRoomSurfaceResume resume,
  ) {
    _stagedResumes[controller] = resume;
  }

  static bool applyStagedResume(EditorController controller) {
    final resume = _stagedResumes[controller];
    if (resume == null) return false;
    _stagedResumes[controller] = null;

    final coordinator = _coordinators[controller];
    if (coordinator == null ||
        coordinator.session.navigation.selectedSpaceId != resume.spaceId) {
      controller.showPlan();
      return false;
    }

    final adapter = resolve(controller, resume.spaceId);
    if (adapter == null) {
      controller.showPlan();
      return false;
    }

    switch (resume.kind) {
      case CanonicalRoomSurfaceResumeKind.plan:
        controller.showPlan();
        return true;
      case CanonicalRoomSurfaceResumeKind.floor:
        controller.showFloor();
        return true;
      case CanonicalRoomSurfaceResumeKind.ceiling:
        controller.showCeiling();
        return true;
      case CanonicalRoomSurfaceResumeKind.wall:
        final edgeId = resume.boundaryEdgeId;
        if (edgeId != null && adapter.showBoundaryEdge(edgeId)) return true;
        controller.showPlan();
        return false;
    }
  }
}
