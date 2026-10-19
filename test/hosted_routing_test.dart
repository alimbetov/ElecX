import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/hosted_routing.dart';
import 'package:elecx/src/domain/project_model.dart';
import 'package:elecx/src/domain/route_host.dart';
import 'package:elecx/src/domain/site_outdoor_model.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/engine/route_interaction_engine.dart';
import 'package:elecx/src/domain/route_medium.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('site connection bridges indoor route to outdoor lighting feed', () {
    final room = EngineeringSpace(
      id: 'room-1',
      name: 'Electrical room',
      type: SpaceType.technicalRoom,
      boundary: MmPolygon.rectangle(const MmPoint(0, 0), const MmPoint(4000, 3000)),
      referenceFrame: const RoomReferenceFrame(origin: MmPoint(2000, 1500)),
    );
    final level = BuildingLevel(
      id: 'level-1',
      name: 'Ground',
      elevationMm: 0,
      spaces: [room],
    );
    final project = ComposedProjectSite(
      site: ProjectSite(
        id: 'site-1',
        name: 'Site',
        buildings: [
          Building(id: 'building-1', name: 'House', levels: [level]),
        ],
      ),
      outdoorZones: [
        OutdoorZone(
          id: 'yard',
          name: 'Yard',
          kind: OutdoorZoneKind.yard,
          boundary: MmPolygon.rectangle(
            const MmPoint(0, 0),
            const MmPoint(20000, 15000),
          ),
        ),
      ],
      connections: [
        SiteBuildingConnection(
          id: 'lighting-entry',
          kind: SiteConnectionKind.lightingFeed,
          outdoorZoneId: 'yard',
          buildingId: 'building-1',
          levelNumber: 0,
          sitePoint: const MmPoint(4000, 1500),
          levelPoint: const MmPoint(4000, 1500),
          targetSpaceId: 'room-1',
        ),
      ],
    );

    final transitions = SiteRouteTransitionResolver.fromConnections(
      project: project,
      resolveIndoorHost: (_) => RouteHostRef.indoor(
        RoomSurfaceRef.wall('room-1', 1),
      ),
    );

    expect(transitions, hasLength(1));
    expect(transitions.single.kind, RouteHostTransitionKind.lightingFeed);
    expect(transitions.single.fromHost.kind, RouteHostKind.outdoorZone);
    expect(transitions.single.toHost.kind, RouteHostKind.indoorSurface);

    final route = HostedRoutePath(
      routeId: 'yard-light-1',
      transitions: transitions,
      segments: [
        HostedRouteSegment(
          host: transitions.single.toHost,
          points: const [MmPoint(1000, 1500), MmPoint(4000, 1500)],
        ),
        HostedRouteSegment(
          host: transitions.single.fromHost,
          points: const [MmPoint(4000, 1500), MmPoint(12000, 6000)],
        ),
      ],
    );

    expect(route.crossesBuildingEnvelope, isTrue);
    expect(route.hosts.length, 2);
    expect(route.lengthMm, greaterThan(10000));

    final samples = RouteInteractionEngine.flowSamples(
      route: route,
      medium: RouteMediumProfile.acPower,
      phase: 0.25,
    );
    expect(samples, isEmpty); // AC uses oscillating glow rather than fake particles.

    final dcSamples = RouteInteractionEngine.flowSamples(
      route: route,
      medium: RouteMediumProfile.dcPower,
      phase: 0.7,
    );
    expect(dcSamples, isNotEmpty);
    expect(
      dcSamples.map((sample) => sample.hostId).toSet().length,
      greaterThanOrEqualTo(1),
    );
  });
}
