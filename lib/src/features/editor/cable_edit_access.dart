import '../../domain/electrical_routing.dart';
import '../../engine/command_history.dart';
import 'cable_endpoint_transform_session.dart';
import 'cable_route_edit_session.dart';
import 'editor_controller.dart';
import 'editor_p2_session.dart';

extension UndoableCableRouteEditing on EditorP2Session {
  bool replaceCableRoute(
    ElectricalCableRoute before,
    ElectricalCableRoute after,
  ) {
    if (before.id != after.id) return false;
    if (!routes.any((route) => route.id == before.id)) return false;
    if (!ElectricalConnectivityValidator.routeIsConnected(
      route: after,
      components: components,
    )) {
      return false;
    }
    history.execute(_ReplaceCableRouteCommand(before: before, after: after));
    notifyListeners();
    return true;
  }
}

final class _ReplaceCableRouteCommand implements EditorCommand<EditorP2State> {
  const _ReplaceCableRouteCommand({required this.before, required this.after});

  final ElectricalCableRoute before;
  final ElectricalCableRoute after;

  @override
  String get label => 'Edit cable route';

  @override
  EditorP2State execute(EditorP2State state) =>
      _replace(state, before.id, after);

  @override
  EditorP2State undo(EditorP2State state) => _replace(state, after.id, before);

  static EditorP2State _replace(
    EditorP2State state,
    String routeId,
    ElectricalCableRoute replacement,
  ) =>
      state.copyWith(
        routes: [
          for (final route in state.routes)
            if (route.id == routeId) replacement else route,
        ],
      );
}

final Expando<CableRouteEditSession> _routeEditSessions =
    Expando<CableRouteEditSession>('ElecX cable route edit session');
final Expando<CableEndpointTransformSession> _endpointTransformSessions =
    Expando<CableEndpointTransformSession>(
      'ElecX cable endpoint transform session',
    );

extension CableEditSessionAccess on EditorController {
  CableRouteEditSession get cableRouteEdit =>
      _routeEditSessions[this] ??= CableRouteEditSession(
        onCommit: p2.replaceCableRoute,
      );

  CableEndpointTransformSession get cableEndpointTransform =>
      _endpointTransformSessions[this] ??= CableEndpointTransformSession(
        onCommit: p2.replaceCableRoute,
      );
}
