import 'cable_endpoint_transform_session.dart';
import 'cable_route_edit_session.dart';
import 'editor_controller.dart';
import 'editor_p2_session.dart';

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
