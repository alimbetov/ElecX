import '../../domain/project_aggregate.dart';
import '../../domain/project_identity.dart';
import 'canonical_editor_workspace_adapter.dart';
import 'canonical_room_boundary_projection.dart';
import 'canonical_room_surface_selection.dart';
import 'editor_building_workspace.dart';

enum CanonicalRoomSurfaceCutoverIssueCode {
  canonicalSpaceMissing,
  canonicalLevelMissing,
  canonicalSpaceOutsideBoundBuilding,
  boundaryTopologyMissing,
  legacyBuildingMismatch,
  legacyLevelBindingMissing,
  legacyLevelNotActive,
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
/// P7A persistence/materialization boundary. The complete canonical
/// Space -> Level -> Building ownership chain and the matching legacy Building,
/// Level and Space bindings must be coherent before a wall ordinal can be
/// projected.
abstract final class CanonicalRoomSurfaceCutover {
  static CanonicalRoomSurfaceSelectionAdapter resolve({
    required ProjectAggregateRoot project,
    required CanonicalEditorWorkspaceBinding binding,
    required EditorBuildingWorkspace workspace,
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

    final canonicalLevel = project.index.level(canonicalSpace.levelId);
    if (canonicalLevel == null) {
      throw CanonicalRoomSurfaceCutoverException(
        code: CanonicalRoomSurfaceCutoverIssueCode.canonicalLevelMissing,
        spaceId: spaceId,
        message: 'Canonical space $spaceId references missing level '
            '${canonicalSpace.levelId}.',
      );
    }
    if (canonicalLevel.buildingId != binding.buildingId) {
      throw CanonicalRoomSurfaceCutoverException(
        code: CanonicalRoomSurfaceCutoverIssueCode
            .canonicalSpaceOutsideBoundBuilding,
        spaceId: spaceId,
        message: 'Canonical space $spaceId belongs to building '
            '${canonicalLevel.buildingId}, not editor binding '
            '${binding.buildingId}.',
      );
    }

    if (workspace.building.building.id != binding.legacyBuildingId) {
      throw CanonicalRoomSurfaceCutoverException(
        code: CanonicalRoomSurfaceCutoverIssueCode.legacyBuildingMismatch,
        spaceId: spaceId,
        message: 'Legacy workspace building '
            '${workspace.building.building.id} does not match binding '
            '${binding.legacyBuildingId}.',
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

    final legacyLevelId = binding.legacyLevelIds[canonicalSpace.levelId];
    if (legacyLevelId == null) {
      throw CanonicalRoomSurfaceCutoverException(
        code: CanonicalRoomSurfaceCutoverIssueCode.legacyLevelBindingMissing,
        spaceId: spaceId,
        message: 'Canonical level ${canonicalSpace.levelId} has no legacy '
            'editor binding for space $spaceId.',
      );
    }

    final activeLegacyLevel = workspace.activeLevel;
    final controller = workspace.editor;
    if (workspace.context != EditorWorkspaceContext.buildingLevel ||
        activeLegacyLevel?.level.id != legacyLevelId ||
        controller.level.id != legacyLevelId) {
      throw CanonicalRoomSurfaceCutoverException(
        code: CanonicalRoomSurfaceCutoverIssueCode.legacyLevelNotActive,
        spaceId: spaceId,
        message: 'Legacy workspace/editor active Level does not match '
            'canonical space $spaceId binding $legacyLevelId.',
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
