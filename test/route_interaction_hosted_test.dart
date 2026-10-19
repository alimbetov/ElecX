import 'package:elecx/src/domain/electrical_routing.dart';
import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/hosted_routing.dart';
import 'package:elecx/src/domain/route_host.dart';
import 'package:elecx/src/domain/route_medium.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/engine/route_interaction_engine.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/hosted_route_session.dart';
import 'package:elecx/src/features/editor/route_selection_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hosted route hit test selects only segments on requested host', () {
    final outdoor = RouteHostRef.outdoor('yard');
    final indoor = RouteHostRef.indoor(RoomSurfaceRef.wall('room-101', 0));
    final route = HostedRoutePath(
      routeId: 'route-yard-light',
      medium: RouteMediumProfile.acPower,
      segments: [
        HostedRouteSegment(
          host: indoor,
          points: const [MmPoint(0, 300), MmPoint(1000, 300)],
        ),
        HostedRouteSegment(
          host: outdoor,
          points: const [MmPoint(1000, 300), MmPoint(5000, 2500)],
        ),
      ],
    );

    final hit = RouteInteractionEngine.hitTestHosted(
      routes: [route],
      host: outdoor,
      xMm: 3000,
      yMm: 1400,
      radiusMm: 40,
    );

    expect(hit?.routeId, 'route-yard-light');
    expect(
      RouteInteractionEngine.hitTestHosted(
        routes: [route],
        host: RouteHostRef.outdoor('other-yard'),
        xMm: 3000,
        yMm: 1400,
        radiusMm: 100,
      ),
      isNull,
    );
  });

  test('route selection accepts hosted-only route identity', () {
    final controller = EditorController.demo();
    controller.hostedRoutes.upsert(
      HostedRoutePath(
        routeId: 'route-external-gate',
        medium: RouteMediumProfile.ethernet,
        segments: [
          HostedRouteSegment(
            host: RouteHostRef.outdoor('yard'),
            points: const [MmPoint(0, 0), MmPoint(5000, 0)],
          ),
        ],
      ),
    );

    controller.routeSelection.select('route-external-gate');

    expect(controller.routeSelection.selectedRouteId, 'route-external-gate');
    expect(controller.routeSelection.selectedHostedRoute, isNotNull);
    expect(
      controller.routeSelection.selectedHostedRoute?.medium,
      RouteMediumProfile.ethernet,
    );
  });

  test('indoor adapter preserves route medium semantics', () {
    final route = ElectricalCableRoute(
      id: 'route-poe-camera',
      source: const ElectricalEndpointRef(
        componentId: 'switch',
        portId: 'poe-out',
      ),
      target: const ElectricalEndpointRef(
        componentId: 'camera',
        portId: 'poe-in',
      ),
      medium: RouteMediumProfile.poe,
      segments: [
        ElectricalRouteSegment(
          surface: RoomSurfaceRef.ceiling('room-101'),
          points: const [
            SurfacePointMm(100, 100),
            SurfacePointMm(2000, 100),
          ],
        ),
      ],
    );

    final hosted = HostedRouteAdapter.fromIndoor(route);

    expect(hosted.medium, RouteMediumProfile.poe);
    expect(hosted.routeId, route.id);
    expect(hosted.segments.single.host.surface, route.segments.single.surface);
  });

  test('selected hosted route keeps transition visible from both hosts', () {
    final indoor = RouteHostRef.indoor(RoomSurfaceRef.wall('room-101', 0));
    final outdoor = RouteHostRef.outdoor('yard');
    final transition = RouteHostTransition(
      id: 'entry-1',
      kind: RouteHostTransitionKind.cableEntry,
      fromHost: indoor,
      fromPoint: const MmPoint(1200, 400),
      toHost: outdoor,
      toPoint: const MmPoint(9000, 6000),
    );
    final route = HostedRoutePath(
      routeId: 'route-gate',
      segments: [
        HostedRouteSegment(
          host: indoor,
          points: const [MmPoint(0, 400), MmPoint(1200, 400)],
        ),
        HostedRouteSegment(
          host: outdoor,
          points: const [MmPoint(9000, 6000), MmPoint(15000, 6000)],
        ),
      ],
      transitions: [transition],
    );

    expect(
      RouteInteractionEngine.transitionsOnHost(route: route, host: indoor),
      [transition],
    );
    expect(
      RouteInteractionEngine.transitionsOnHost(route: route, host: outdoor),
      [transition],
    );
  });
}
