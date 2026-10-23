import 'package:flutter/foundation.dart';

import '../../domain/electrical_routing.dart';
import '../../domain/hosted_routing.dart';
import '../../domain/route_host.dart';
import 'cable_editor_ui_session.dart';
import 'canonical_room_surface_runtime_registry.dart';
import 'editor_controller.dart';
import 'editor_p2_session.dart';
import 'hosted_route_session.dart';

final class RouteSelectionSession extends ChangeNotifier {
  RouteSelectionSession(this.controller);

  final EditorController controller;
  String? _selectedRouteId;

  String? get selectedRouteId => _selectedRouteId;

  ElectricalCableRoute? get selectedRoute {
    final id = _selectedRouteId;
    if (id == null) return null;
    for (final route in controller.p2.routes) {
      if (route.id == id) return route;
    }
    return null;
  }

  HostedRoutePath? get selectedHostedRoute {
    final id = _selectedRouteId;
    if (id == null) return null;
    final explicit = controller.hostedRoutes.byId(id);
    final indoor = selectedRoute;
    final route = explicit ??
        (indoor == null ? null : HostedRouteAdapter.fromIndoor(indoor));
    return route == null ? null : _projectActiveSlabHost(route);
  }

  HostedRoutePath _projectActiveSlabHost(HostedRoutePath route) {
    final activeSurface = controller.activeSurface;
    final context =
        CanonicalRoomSurfaceRuntimeRegistry.physicalRoutingContextFor(
      controller,
    );
    if (activeSurface == null || context == null) return route;

    final activeCanonicalSpaceId =
        context.canonicalSpaceIdForSurfaceSpaceId(activeSurface.spaceId);
    if (activeCanonicalSpaceId == null) return route;

    var changed = false;
    RouteHostRef projectHost(RouteHostRef host) {
      final surface = host.surface;
      if (surface == null || surface.type != activeSurface.type) return host;
      final canonicalSpaceId =
          context.canonicalSpaceIdForSurfaceSpaceId(surface.spaceId);
      if (canonicalSpaceId != activeCanonicalSpaceId) return host;
      changed = true;
      return RouteHostRef.indoor(activeSurface);
    }

    final transitions = <RouteHostTransition>[
      for (final transition in route.transitions)
        if (transition.kind == RouteHostTransitionKind.levelPenetration)
          RouteHostTransition(
            id: transition.id,
            kind: transition.kind,
            fromHost: projectHost(transition.fromHost),
            fromPoint: transition.fromPoint,
            toHost: projectHost(transition.toHost),
            toPoint: transition.toPoint,
            requiresPenetration: transition.requiresPenetration,
            siteConnectionId: transition.siteConnectionId,
            slabId: transition.slabId,
          )
        else
          transition,
    ];
    if (!changed) return route;
    return HostedRoutePath(
      routeId: route.routeId,
      segments: route.segments,
      transitions: transitions,
      medium: route.medium,
    );
  }

  bool contains(String routeId) => _selectedRouteId == routeId;

  bool _routeExists(String routeId) =>
      controller.p2.routes.any((route) => route.id == routeId) ||
      controller.hostedRoutes.byId(routeId) != null;

  void select(String? routeId) {
    if (routeId != null && !_routeExists(routeId)) return;
    if (_selectedRouteId == routeId) return;
    _selectedRouteId = routeId;
    controller.cableUi.clearFocus();
    if (routeId != null) controller.p2.clearSelection();
    notifyListeners();
  }

  void clear() => select(null);

  void normalize() {
    final id = _selectedRouteId;
    if (id == null || _routeExists(id)) return;
    _selectedRouteId = null;
    notifyListeners();
  }
}

final Expando<RouteSelectionSession> _sessions = Expando<RouteSelectionSession>(
  'ElecX route selection session',
);

extension RouteSelectionSessionAccess on EditorController {
  RouteSelectionSession get routeSelection =>
      _sessions[this] ??= RouteSelectionSession(this);
}
