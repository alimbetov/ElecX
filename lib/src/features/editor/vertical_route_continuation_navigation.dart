import '../../domain/canonical_slab_route_handoff.dart';
import '../../domain/route_host.dart';
import '../../domain/surfaces.dart';
import 'canonical_room_surface_runtime_registry.dart';
import 'editor_controller.dart';
import 'vertical_route_continuation_marker.dart';

enum VerticalRouteContinuationNavigationIssueCode {
  markerUnavailable,
  canonicalRuntimeRequired,
  targetSpaceUnresolved,
  slabOwnershipMismatch,
  targetMaterializationFailed,
}

final class VerticalRouteContinuationNavigationException implements Exception {
  const VerticalRouteContinuationNavigationException({
    required this.code,
    required this.message,
  });

  final VerticalRouteContinuationNavigationIssueCode code;
  final String message;

  @override
  String toString() => '${code.name}: $message';
}

/// Navigation-only action for a committed slab penetration marker.
///
/// This never mutates route geometry. Authoring an unfinished cross-level draft
/// remains the responsibility of CanonicalSlabCableHandoffAuthoring. Here the
/// route and SlabId already exist, so activation only changes canonical
/// navigation and rematerializes the opposite floor/ceiling surface.
abstract final class VerticalRouteContinuationNavigation {
  static VerticalRouteContinuationMarker follow({
    required EditorController controller,
    required String routeId,
    required RouteHostTransition transition,
  }) {
    final currentSurface = controller.activeSurface;
    final marker = currentSurface == null
        ? null
        : VerticalRouteContinuationMarkerResolver.resolve(
            routeId: routeId,
            transition: transition,
            currentSurface: currentSurface,
          );
    if (marker == null) {
      throw const VerticalRouteContinuationNavigationException(
        code: VerticalRouteContinuationNavigationIssueCode.markerUnavailable,
        message: 'The selected transition is not an active inter-level marker.',
      );
    }

    final coordinator =
        CanonicalRoomSurfaceRuntimeRegistry.coordinatorFor(controller);
    final routing =
        CanonicalRoomSurfaceRuntimeRegistry.physicalRoutingContextFor(controller);
    if (coordinator == null || routing == null) {
      throw const VerticalRouteContinuationNavigationException(
        code:
            VerticalRouteContinuationNavigationIssueCode.canonicalRuntimeRequired,
        message: 'Canonical runtime is required for inter-level navigation.',
      );
    }

    final sourceSpaceId =
        routing.canonicalSpaceIdForSurfaceSpaceId(marker.currentSurface.spaceId);
    final targetSpaceId =
        routing.canonicalSpaceIdForSurfaceSpaceId(marker.targetSurface.spaceId);
    if (sourceSpaceId == null || targetSpaceId == null) {
      throw const VerticalRouteContinuationNavigationException(
        code: VerticalRouteContinuationNavigationIssueCode.targetSpaceUnresolved,
        message: 'Marker surfaces cannot be resolved to canonical SpaceId values.',
      );
    }

    final plan = CanonicalSlabRouteHandoffPlanner.resolve(
      project: coordinator.session.project,
      fromSpaceId: sourceSpaceId,
      toSpaceId: targetSpaceId,
    );
    if (plan == null || plan.slabId != marker.slabId) {
      throw const VerticalRouteContinuationNavigationException(
        code: VerticalRouteContinuationNavigationIssueCode.slabOwnershipMismatch,
        message: 'Marker SlabId does not own the canonical source/target levels.',
      );
    }

    coordinator.session.selectRoom(targetSpaceId);
    coordinator.pushCanonicalToEditor();
    switch (marker.targetSurface.type) {
      case SurfacePlaneType.floor:
        controller.showFloor();
      case SurfacePlaneType.ceiling:
        controller.showCeiling();
      case SurfacePlaneType.wall:
        throw const VerticalRouteContinuationNavigationException(
          code: VerticalRouteContinuationNavigationIssueCode
              .targetMaterializationFailed,
          message: 'A slab continuation target cannot be a wall surface.',
        );
    }

    final active = controller.activeSurface;
    final activeCanonical = active == null
        ? null
        : routing.canonicalSpaceIdForSurfaceSpaceId(active.spaceId);
    if (active == null ||
        activeCanonical != targetSpaceId ||
        active.type != marker.targetSurface.type) {
      throw const VerticalRouteContinuationNavigationException(
        code: VerticalRouteContinuationNavigationIssueCode
            .targetMaterializationFailed,
        message: 'Target floor/ceiling could not be materialized after navigation.',
      );
    }
    return marker;
  }
}
