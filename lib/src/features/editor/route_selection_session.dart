import 'package:flutter/foundation.dart';

import '../../domain/electrical_routing.dart';
import 'editor_controller.dart';
import 'editor_p2_session.dart';

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

  bool contains(String routeId) => _selectedRouteId == routeId;

  void select(String? routeId) {
    if (routeId != null &&
        !controller.p2.routes.any((route) => route.id == routeId)) {
      return;
    }
    if (_selectedRouteId == routeId) return;
    _selectedRouteId = routeId;
    if (routeId != null) controller.p2.clearSelection();
    notifyListeners();
  }

  void clear() => select(null);

  void normalize() {
    final id = _selectedRouteId;
    if (id == null) return;
    if (controller.p2.routes.any((route) => route.id == id)) return;
    _selectedRouteId = null;
    notifyListeners();
  }
}

final Expando<RouteSelectionSession> _sessions =
    Expando<RouteSelectionSession>('ElecX route selection session');

extension RouteSelectionSessionAccess on EditorController {
  RouteSelectionSession get routeSelection =>
      _sessions[this] ??= RouteSelectionSession(this);
}
