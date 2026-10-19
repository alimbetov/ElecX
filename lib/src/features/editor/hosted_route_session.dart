import 'package:flutter/foundation.dart';

import '../../domain/hosted_routing.dart';
import 'editor_controller.dart';

final class HostedRouteSession extends ChangeNotifier {
  final List<HostedRoutePath> _paths = [];

  List<HostedRoutePath> get paths => List.unmodifiable(_paths);

  HostedRoutePath? byId(String id) {
    for (final path in _paths) {
      if (path.routeId == id) return path;
    }
    return null;
  }

  void upsert(HostedRoutePath path) {
    final index = _paths.indexWhere((item) => item.routeId == path.routeId);
    if (index < 0) {
      _paths.add(path);
    } else {
      _paths[index] = path;
    }
    notifyListeners();
  }

  bool remove(String routeId) {
    final before = _paths.length;
    _paths.removeWhere((path) => path.routeId == routeId);
    if (_paths.length == before) return false;
    notifyListeners();
    return true;
  }

  void clear() {
    if (_paths.isEmpty) return;
    _paths.clear();
    notifyListeners();
  }
}

final Expando<HostedRouteSession> _hostedRouteSessions =
    Expando<HostedRouteSession>('ElecX hosted route session');

extension HostedRouteSessionAccess on EditorController {
  HostedRouteSession get hostedRoutes =>
      _hostedRouteSessions[this] ??= HostedRouteSession();
}
