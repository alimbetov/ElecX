import '../../domain/project_aggregate.dart';
import '../../domain/project_identity.dart';
import 'canonical_editor_workspace_adapter.dart';
import 'canonical_room_boundary_projection.dart';
import 'canonical_room_surface_selection.dart';
import 'editor_controller.dart';

enum CanonicalRoomSurfaceCutoverIssueCode {
  canonicalSpaceMissing,
  boundaryTopologyMissing,
  legacySpaceBindingMissing,
  legacySpaceNotSelected,
}

final class CanonicalRoomSurfaceCutoverException implements Exception {
  const CanonicalRoomSurfaceCutoverException({
    required this.code,
    required this.message,
    required this.spaceId,
  });

  final CanonicalRoomSurfaceCutoverIssueCode code;
  final String message;
  final SpaceId spaceId;

  @override
  String toString() => '${code.name}: $message';
}

/// Production-facing P7A-4 resolver for one selected canonical room.
///
/// It refuses to manufacture topology for rooms that have not yet crossed the
/// P7A persistence/materialization boundary. The selected legacy editor room
/// must be the exact space bound to [spaceId], and its polygon must match the
/// canonical topology through [CanonicalRoomBoundaryProjection].
abstract final class CanonicalRoomSurfaceCutover {
  static CanonicalRoomSurfaceSelectionAdapter resolve({
    required ProjectAggregateRoot project,
    required CanonicalEditorWorkspaceBinding binding,
    required EditorController controller,
    required SpaceId spaceId,
  }) {
    final canonicalSpace = project.index.space(spaceId);
    if (canonicalSpace == null) {
      throw CanonicalRoomSurfaceCutoverException(
        code: CanonicalRoomSurfaceCutoverIssueCode.canonicalSpaceMissing,
        spaceId: spaceId,
        message: 'Canonical space $spaceId does not exist in the project.',
      );
    }

    final topology = project.index.boundary(spaceId);
    if (topology == null) {
      throw CanonicalRoomSurfaceCutoverException(
        code: CanonicalRoomSurfaceCutoverIssueCode.boundaryTopologyMissing,
        spaceId: spaceId,
        message: 'Canonical space $spaceId has no P7A boundary topology.',
      );
    }

    final legacySpaceId = binding.legacySpaceIds[spaceId];
    if (legacySpaceId == null) {
      throw CanonicalRoomSurfaceCutoverException(
        code: CanonicalRoomSurfaceCutoverIssueCode.legacySpaceBindingMissing,
        spaceId: spaceId,
        message: 'Canonical space $spaceId has no legacy editor binding.',
      );
    }

    final legacySpace = controller.selectedSpace;
    if (legacySpace == null ||
        controller.selectedSpaceId != legacySpaceId ||
        legacySpace.id != legacySpaceId) {
      throw CanonicalRoomSurfaceCutoverException(
        code: CanonicalRoomSurfaceCutoverIssueCode.legacySpaceNotSelected,
        spaceId: spaceId,
        message: 'Legacy editor selection does not match canonical space '
            '$spaceId binding $legacySpaceId.',
      );
    }

    final projection = CanonicalRoomBoundaryProjection.build(
      canonicalSpaceId: spaceId,
      legacySpaceId: legacySpaceId,
      canonicalTopology: topology,
      legacySpace: legacySpace,
    );
    return CanonicalRoomSurfaceSelectionAdapter(
      controller: controller,
      projection: projection,
    );
  }
}
