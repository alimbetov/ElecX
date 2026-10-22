import 'dart:math';

import 'package:elecx/src/domain/boundary_host_migration.dart';
import 'package:elecx/src/domain/boundary_host_registry.dart';
import 'package:elecx/src/domain/electrical_routing.dart';
import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_model.dart';
import 'package:elecx/src/domain/route_anchor_identity_migration.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/features/editor/canonical_route_anchor_rehydration.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P7A-5 stable route anchor lifecycle', () {
    final spaceId = SpaceId('space-a');
    final edgeId = BoundaryEdgeId('edge-a');
    final legacySpace = EngineeringSpace(
      id: 'legacy-space',
      name: 'Room',
      type: SpaceType.room,
      boundary: MmPolygon.rectangle(
        const MmPoint(0, 0),
        const MmPoint(4000, 3000),
      ),
      referenceFrame: const RoomReferenceFrame(origin: MmPoint(2000, 1500)),
    );

    ElectricalCableRoute legacyRoute() => ElectricalCableRoute(
          id: 'route-1',
          source: const ElectricalEndpointRef(componentId: 'a', portId: 'out'),
          target: const ElectricalEndpointRef(componentId: 'b', portId: 'in'),
          segments: [
            ElectricalRouteSegment(
              surface: RoomSurfaceRef.wall(legacySpace.id, 0),
              points: const [
                SurfacePointMm(500, 400),
                SurfacePointMm(1500, 400),
                SurfacePointMm(2500, 400),
              ],
            ),
          ],
        );

    test('legacy route receives UUID-backed stable point identities explicitly',
        () {
      final ids = SecureRandomEntityIdFactory(random: Random(11));
      final migrated = RouteAnchorIdentityMigration.migrate(legacyRoute(), ids);

      expect(migrated.segments.single.anchorIds, hasLength(3));
      expect(migrated.segments.single.hasStableAnchorIdentity, isTrue);
      expect(
        migrated.segments.single.anchorIds.map((id) => id.value).toSet(),
        hasLength(3),
      );
    });

    test('existing stable identities are preserved exactly', () {
      final route = legacyRoute();
      final stable = ElectricalCableRoute(
        id: route.id,
        source: route.source,
        target: route.target,
        segments: [
          ElectricalRouteSegment(
            surface: route.segments.single.surface,
            points: route.segments.single.points,
            anchorIds: [
              RouteAnchorId('a1'),
              RouteAnchorId('a2'),
              RouteAnchorId('a3'),
            ],
          ),
        ],
      );
      final migrated = RouteAnchorIdentityMigration.migrate(
        stable,
        SecureRandomEntityIdFactory(random: Random(12)),
      );

      expect(migrated, same(stable));
    });

    test('canonical registry rehydrates interior id without using point index',
        () {
      final route = legacyRoute();
      final registry = BoundaryHostedObjectRegistry({
        'cable:route-1:source': BoundaryHostedReference.point(
          objectKey: 'cable:route-1:source',
          objectKind: BoundaryHostedObjectKind.cableEndpoint,
          host: BoundaryEdgeHostRef(spaceId: spaceId, edgeId: edgeId),
          offsetMm: 500,
        ),
        'route:route-1:anchor:stable-middle': BoundaryHostedReference.point(
          objectKey: 'route:route-1:anchor:stable-middle',
          objectKind: BoundaryHostedObjectKind.routeAnchor,
          host: BoundaryEdgeHostRef(spaceId: spaceId, edgeId: edgeId),
          offsetMm: 1500,
        ),
        'cable:route-1:target': BoundaryHostedReference.point(
          objectKey: 'cable:route-1:target',
          objectKind: BoundaryHostedObjectKind.cableEndpoint,
          host: BoundaryEdgeHostRef(spaceId: spaceId, edgeId: edgeId),
          offsetMm: 2500,
        ),
      });

      final restored = CanonicalRouteAnchorRehydration.rehydrate(
        p2State: EditorP2State(routes: [route]),
        legacySpace: legacySpace,
        canonicalSpaceId: spaceId,
        orderedEdgeIds: [
          edgeId,
          BoundaryEdgeId('east'),
          BoundaryEdgeId('north'),
          BoundaryEdgeId('west'),
        ],
        registry: registry,
      );

      expect(
        restored.routes.single.segments.single.anchorIds[1],
        RouteAnchorId('stable-middle'),
      );
    });

    test('ambiguous persisted route anchor candidates fail closed', () {
      final route = legacyRoute();
      final registry = BoundaryHostedObjectRegistry({
        for (final suffix in ['x', 'y'])
          'route:route-1:anchor:$suffix': BoundaryHostedReference.point(
            objectKey: 'route:route-1:anchor:$suffix',
            objectKind: BoundaryHostedObjectKind.routeAnchor,
            host: BoundaryEdgeHostRef(spaceId: spaceId, edgeId: edgeId),
            offsetMm: 1500,
          ),
      });

      expect(
        () => CanonicalRouteAnchorRehydration.rehydrate(
          p2State: EditorP2State(routes: [route]),
          legacySpace: legacySpace,
          canonicalSpaceId: spaceId,
          orderedEdgeIds: [
            edgeId,
            BoundaryEdgeId('east'),
            BoundaryEdgeId('north'),
            BoundaryEdgeId('west'),
          ],
          registry: registry,
        ),
        throwsStateError,
      );
    });
  });
}
