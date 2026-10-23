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

  /// Atomically replaces one already committed physical route while preserving
  /// its engineering identity.
  ///
  /// Resume/extend authoring must never create a second cable merely because
  /// the visible path gained another segment. The replacement therefore
  /// requires the same route id and delegates to the production route-edit
  /// transaction, which revalidates connectivity, physical endpoint anchoring,
  /// route constraints and circuit identity, and invalidates stale sizing
  /// evidence in the same undoable mutation.
  bool replacePhysicalCableRoute({
    required ElectricalCableRoute before,
    required ElectricalCableRoute after,
  }) {
    if (before.id != after.id ||
        !layers.isVisible(EditorLayerId.cableRoutes) ||
        layers.isLocked(EditorLayerId.cableRoutes)) {
      return false;
    }
    return replaceCableRoute(before, after);
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
