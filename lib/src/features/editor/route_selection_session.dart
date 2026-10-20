import 'package:flutter/foundation.dart';

import '../../domain/electrical_routing.dart';
import '../../domain/hosted_routing.dart';
import 'cable_editor_ui_session.dart';
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
    return controller.hostedRoutes.byId(id);
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
