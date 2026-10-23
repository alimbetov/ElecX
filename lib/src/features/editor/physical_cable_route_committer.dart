import '../../domain/electrical_routing.dart';
import '../../engine/command_history.dart';
import '../../engine/editor_layers.dart';
import 'editor_p2_session.dart';

extension PhysicalCableRouteCommitter on EditorP2Session {
  /// Commits a fully materialized physical route as one undo/redo transaction.
  ///
  /// The route already owns its BoundaryPenetration records, therefore history
  /// cannot leave a cable without its holes or leave orphan holes after undo.
  bool commitPhysicalCableRoute(ElectricalCableRoute route) {
    if (!layers.isVisible(EditorLayerId.cableRoutes) ||
        layers.isLocked(EditorLayerId.cableRoutes) ||
        routes.any((existing) => existing.id == route.id)) {
      return false;
    }
    if (!ElectricalConnectivityValidator.routeIsConnected(
          route: route,
          components: components,
        ) ||
        !ElectricalConnectivityValidator.routeIsPhysicallyAnchored(
          route: route,
          components: components,
        )) {
      return false;
    }

    history.execute(_AddPhysicalCableRouteCommand(route));
    // This extension is part of the EditorP2Session mutation surface. The
    // command has already committed synchronously; notify the same listeners as
    // native session mutation methods so canvas/panels cannot observe stale UI.
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    notifyListeners();
    return true;
  }
}

final class _AddPhysicalCableRouteCommand
    implements EditorCommand<EditorP2State> {
  const _AddPhysicalCableRouteCommand(this.route);

  final ElectricalCableRoute route;

  @override
  String get label => 'Create physical cable route with penetrations';

  @override
  EditorP2State execute(EditorP2State state) {
    if (state.routes.any((existing) => existing.id == route.id)) {
      throw StateError('Route ${route.id} already exists.');
    }
    return state.copyWith(
      routes: List.unmodifiable([...state.routes, route]),
    );
  }

  @override
  EditorP2State undo(EditorP2State state) => state.copyWith(
        routes: List.unmodifiable([
          for (final existing in state.routes)
            if (existing.id != route.id) existing,
        ]),
      );
}
