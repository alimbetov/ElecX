import '../../domain/project_identity.dart';
import '../../domain/surfaces.dart';
import 'canonical_room_surface_runtime_registry.dart';
import 'editor_controller.dart';

/// Navigates a visible route transition without treating a legacy wall ordinal
/// as canonical identity.
///
/// When canonical runtime is attached, the target space and wall are resolved
/// through the current binding and BoundaryEdgeId projection. A retired,
/// foreign or otherwise stale edge fails closed to Plan. Legacy wallIndex is
/// accepted only when no canonical BoundaryEdgeId is present.
abstract final class SurfaceTransitionNavigator {
  static bool navigate(
    EditorController controller,
    RoomSurfaceRef target,
  ) {
    final physical =
        CanonicalRoomSurfaceRuntimeRegistry.physicalRoutingContextFor(
      controller,
    );

    SpaceId? canonicalSpaceId;
    String targetLegacySpaceId;
    if (physical == null) {
      targetLegacySpaceId = target.spaceId;
    } else {
      canonicalSpaceId =
          physical.canonicalSpaceIdForSurfaceSpaceId(target.spaceId);
      if (canonicalSpaceId == null) return _failClosed(controller);
      final legacySpaceId =
          physical.legacySpaceIdForCanonical(canonicalSpaceId);
      if (legacySpaceId == null) return _failClosed(controller);
      targetLegacySpaceId = legacySpaceId;
    }

    if (controller.selectedSpaceId != targetLegacySpaceId) {
      controller.selectSpace(targetLegacySpaceId);
    }
    if (controller.selectedSpaceId != targetLegacySpaceId) {
      return _failClosed(controller);
    }

    switch (target.type) {
      case SurfacePlaneType.wall:
        final edgeId = target.boundaryEdgeId;
        if (edgeId != null) {
          if (canonicalSpaceId == null) return _failClosed(controller);
          final adapter = CanonicalRoomSurfaceRuntimeRegistry.resolve(
            controller,
            canonicalSpaceId,
          );
          if (adapter == null || !adapter.showBoundaryEdge(edgeId)) {
            return _failClosed(controller);
          }
          return true;
        }
        final wallIndex = target.wallIndex;
        if (wallIndex == null) return _failClosed(controller);
        controller.showWall(wallIndex);
        return controller.activeSurface?.wallIndex == wallIndex;
      case SurfacePlaneType.floor:
        controller.showFloor();
        return controller.activeSurface?.type == SurfacePlaneType.floor;
      case SurfacePlaneType.ceiling:
        controller.showCeiling();
        return controller.activeSurface?.type == SurfacePlaneType.ceiling;
    }
  }

  static bool _failClosed(EditorController controller) {
    controller.showPlan();
    return false;
  }
}
