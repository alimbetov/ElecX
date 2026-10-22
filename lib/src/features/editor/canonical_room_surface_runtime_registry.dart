import '../../domain/project_identity.dart';
import '../../domain/surfaces.dart';
import 'canonical_editor_runtime_cutover.dart';
import 'canonical_room_surface_cutover.dart';
import 'canonical_room_surface_resume.dart';
import 'canonical_room_surface_selection.dart';
import 'editor_controller.dart';

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

  static void attach(CanonicalEditorRuntimeCutoverCoordinator coordinator) {
    final controller = coordinator.adapter.workspace.editor;
    _coordinators[controller] = coordinator;

    // A legacy document may have restored RoomSurfaceRef.wall(..., wallIndex).
    // Once this controller enters canonical runtime that ordinal is not trusted
    // as durable identity. Only an explicitly staged BoundaryEdgeId resume may
    // restore a wall after canonical materialization.
    if (_stagedResumes[controller] == null &&
        controller.activeSurface?.type == SurfacePlaneType.wall) {
      controller.showPlan();
    }
  }

  static void detach(CanonicalEditorRuntimeCutoverCoordinator coordinator) {
    final controller = coordinator.adapter.workspace.editor;
    if (identical(_coordinators[controller], coordinator)) {
      _coordinators[controller] = null;
    }
  }

  static bool hasCanonicalRuntime(EditorController controller) =>
      _coordinators[controller] != null;

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

  /// Applies a staged stable resume only after canonical navigation has been
  /// materialized into the exact legacy workspace. Missing/deleted/reowned
  /// edges fail closed to Plan and can never fall through to a wall ordinal.
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
