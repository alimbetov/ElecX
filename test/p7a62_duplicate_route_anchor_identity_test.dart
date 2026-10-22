import 'dart:math';

import 'package:elecx/src/domain/electrical_routing.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/route_anchor_identity_migration.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('duplicate durable route anchor identity fails closed before capture',
      () {
    final route = ElectricalCableRoute(
      id: 'route-duplicate-anchor',
      source: const ElectricalEndpointRef(componentId: 's', portId: 'out'),
      target: const ElectricalEndpointRef(componentId: 't', portId: 'in'),
      segments: [
        ElectricalRouteSegment(
          surface: RoomSurfaceRef.wall('room', 0),
          points: const [
            SurfacePointMm(500, 400),
            SurfacePointMm(1500, 400),
            SurfacePointMm(2500, 400),
            SurfacePointMm(3500, 400),
          ],
          anchorIds: [
            RouteAnchorId('source-placeholder'),
            RouteAnchorId('duplicate'),
            RouteAnchorId('duplicate'),
            RouteAnchorId('target-placeholder'),
          ],
        ),
      ],
    );

    expect(
      () => RouteAnchorIdentityMigration.migrate(
        route,
        SecureRandomEntityIdFactory(random: Random(6202)),
      ),
      throwsStateError,
    );
  });

  test('legacy durable anchor cannot occupy projection transition namespace',
      () {
    final route = ElectricalCableRoute(
      id: 'route-reserved-anchor',
      source: const ElectricalEndpointRef(componentId: 's', portId: 'out'),
      target: const ElectricalEndpointRef(componentId: 't', portId: 'in'),
      segments: [
        ElectricalRouteSegment(
          surface: RoomSurfaceRef.wall('room', 0),
          points: const [
            SurfacePointMm(500, 400),
            SurfacePointMm(1500, 400),
            SurfacePointMm(2500, 400),
          ],
          anchorIds: [
            RouteAnchorId('source-placeholder'),
            RouteAnchorId('p7a-transition:user-supplied'),
            RouteAnchorId('target-placeholder'),
          ],
        ),
      ],
    );

    expect(
      () => RouteAnchorIdentityMigration.migrate(
        route,
        SecureRandomEntityIdFactory(random: Random(6203)),
      ),
      throwsStateError,
    );
  });
}
