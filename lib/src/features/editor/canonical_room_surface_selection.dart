import '../../domain/project_identity.dart';
import '../../domain/surfaces.dart';
import 'canonical_room_boundary_projection.dart';
import 'editor_controller.dart';

enum CanonicalRoomSurfaceKind { plan, floor, ceiling, wall }

final class CanonicalRoomSurfaceSelection {
  const CanonicalRoomSurfaceSelection({
    required this.kind,
    this.boundaryEdgeId,
    this.wallOrdinal,
  });

  final CanonicalRoomSurfaceKind kind;
  final BoundaryEdgeId? boundaryEdgeId;

  /// Transitional legacy canvas address. Never persist or compare this as
  /// engineering identity; [boundaryEdgeId] owns wall identity.
  final int? wallOrdinal;
}

/// P7A-4 stable-selection bridge around the legacy [EditorController].
///
/// The controller may still expose [RoomSurfaceRef.wall] by integer ordinal,
/// but callers of this adapter select and navigate walls by BoundaryEdgeId.
/// Ordinal conversion happens only at the final legacy API boundary.
final class CanonicalRoomSurfaceSelectionAdapter {
  const CanonicalRoomSurfaceSelectionAdapter({
    required this.controller,
    required this.projection,
  });

  final EditorController controller;
  final CanonicalRoomBoundaryProjection projection;

  CanonicalRoomSurfaceSelection current() {
    if (!_hasExactLegacyMaterialization()) {
      return const CanonicalRoomSurfaceSelection(
        kind: CanonicalRoomSurfaceKind.plan,
      );
    }

    final active = controller.activeSurface;
    if (controller.viewMode == EditorViewMode.plan || active == null) {
      return const CanonicalRoomSurfaceSelection(
        kind: CanonicalRoomSurfaceKind.plan,
      );
    }
    if (active.spaceId != projection.legacySpaceId) {
      return const CanonicalRoomSurfaceSelection(
        kind: CanonicalRoomSurfaceKind.plan,
      );
    }

    return switch (active.type) {
      SurfacePlaneType.floor => const CanonicalRoomSurfaceSelection(
          kind: CanonicalRoomSurfaceKind.floor,
        ),
      SurfacePlaneType.ceiling => const CanonicalRoomSurfaceSelection(
          kind: CanonicalRoomSurfaceKind.ceiling,
        ),
      SurfacePlaneType.wall => _wallSelection(active.wallIndex),
    };
  }

  CanonicalRoomSurfaceSelection _wallSelection(int? wallOrdinal) {
    if (wallOrdinal == null ||
        wallOrdinal < 0 ||
        wallOrdinal >= projection.wallCount) {
      return const CanonicalRoomSurfaceSelection(
        kind: CanonicalRoomSurfaceKind.plan,
      );
    }
    return CanonicalRoomSurfaceSelection(
      kind: CanonicalRoomSurfaceKind.wall,
      boundaryEdgeId: projection.edgeIdAtOrdinal(wallOrdinal),
      wallOrdinal: wallOrdinal,
    );
  }

  bool showBoundaryEdge(BoundaryEdgeId edgeId) {
    if (!_hasExactLegacyMaterialization()) return false;
    final wallOrdinal = projection.ordinalForEdgeId(edgeId);
    if (wallOrdinal == null) return false;
    controller.showWall(wallOrdinal);
    return true;
  }

  bool previousWall() {
    if (!_hasExactLegacyMaterialization() || projection.wallCount == 0) {
      return false;
    }
    final currentSelection = current();
    final currentEdgeId = currentSelection.boundaryEdgeId;
    final currentOrdinal = currentEdgeId == null
        ? 0
        : projection.ordinalForEdgeId(currentEdgeId) ?? 0;
    final targetOrdinal =
        (currentOrdinal - 1 + projection.wallCount) % projection.wallCount;
    return showBoundaryEdge(projection.edgeIdAtOrdinal(targetOrdinal));
  }

  bool nextWall() {
    if (!_hasExactLegacyMaterialization() || projection.wallCount == 0) {
      return false;
    }
    final currentSelection = current();
    final currentEdgeId = currentSelection.boundaryEdgeId;
    final currentOrdinal = currentEdgeId == null
        ? -1
        : projection.ordinalForEdgeId(currentEdgeId) ?? -1;
    final targetOrdinal = (currentOrdinal + 1) % projection.wallCount;
    return showBoundaryEdge(projection.edgeIdAtOrdinal(targetOrdinal));
  }

  bool _hasExactLegacyMaterialization() {
    final selectedSpace = controller.selectedSpace;
    return selectedSpace != null &&
        controller.selectedSpaceId == projection.legacySpaceId &&
        selectedSpace.id == projection.legacySpaceId &&
        projection.matchesLegacySpace(selectedSpace);
  }
}
