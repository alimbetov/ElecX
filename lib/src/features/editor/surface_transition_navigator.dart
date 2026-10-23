import '../../domain/hosted_routing.dart';
import '../../domain/project_identity.dart';
import '../../domain/route_host.dart';
import '../../domain/surfaces.dart';
import 'canonical_room_surface_runtime_registry.dart';
import 'editor_controller.dart';
import 'route_selection_session.dart';
import 'vertical_route_continuation_navigation.dart';

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
    if (_navigateCommittedLevelPenetration(controller, target)) return true;

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
      final legacySpaceId = physical.legacySpaceIdForCanonical(canonicalSpaceId);
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

  static bool _navigateCommittedLevelPenetration(
    EditorController controller,
    RoomSurfaceRef target,
  ) {
    final routeId = controller.routeSelection.selectedRouteId;
    final active = controller.activeSurface;
    final physical =
        CanonicalRoomSurfaceRuntimeRegistry.physicalRoutingContextFor(
      controller,
    );
    if (routeId == null || active == null || physical == null) return false;

    final currentCanonical = _canonicalHorizontalSurface(physical, active);
    final targetCanonical = _canonicalHorizontalSurface(physical, target);
    if (currentCanonical == null || targetCanonical == null) return false;

    final explicit = controller.hostedRoutes.byId(routeId);
    final indoor = controller.routeSelection.selectedRoute;
    final route = explicit ??
        (indoor == null ? null : HostedRouteAdapter.fromIndoor(indoor));
    if (route == null) return false;

    for (final transition in route.transitions) {
      if (transition.kind != RouteHostTransitionKind.levelPenetration) continue;
      final from = transition.fromHost.surface;
      final to = transition.toHost.surface;
      final matches =
          (from == currentCanonical && to == targetCanonical) ||
              (to == currentCanonical && from == targetCanonical);
      if (!matches) continue;
      VerticalRouteContinuationNavigation.follow(
        controller: controller,
        routeId: routeId,
        transition: transition,
      );
      return true;
    }
    return false;
  }

  static RoomSurfaceRef? _canonicalHorizontalSurface(
    CanonicalPhysicalRoutingContext physical,
    RoomSurfaceRef surface,
  ) {
    if (surface.type == SurfacePlaneType.wall) return null;
    final spaceId = physical.canonicalSpaceIdForSurfaceSpaceId(surface.spaceId);
    if (spaceId == null) return null;
    return switch (surface.type) {
      SurfacePlaneType.floor => RoomSurfaceRef.floor(spaceId.value),
      SurfacePlaneType.ceiling => RoomSurfaceRef.ceiling(spaceId.value),
      SurfacePlaneType.wall => null,
    };
  }

  static bool _failClosed(EditorController controller) {
    controller.showPlan();
    return false;
  }
}
