import 'package:elecx/src/domain/boundary_penetration.dart';
import 'package:elecx/src/domain/cable_penetration_authoring.dart';
import 'package:elecx/src/domain/electrical_routing.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/surface_transition_graph.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CablePenetrationAuthoring', () {
    final wallA = RoomSurfaceRef.wallByBoundaryEdge(
      'space-a',
      BoundaryEdgeId('edge-a'),
    );
    final wallB = RoomSurfaceRef.wallByBoundaryEdge(
      'space-b',
      BoundaryEdgeId('edge-b'),
    );
    final segments = <ElectricalRouteSegment>[
      ElectricalRouteSegment(
        surface: wallA,
        points: const [
          SurfacePointMm(100, 1200),
          SurfacePointMm(900, 1200),
        ],
      ),
      ElectricalRouteSegment(
        surface: wallB,
        points: const [
          SurfacePointMm(200, 1200),
          SurfacePointMm(1100, 1200),
        ],
      ),
    ];

    SurfaceTransitionCandidate wallTransition({int? thicknessMm = 180}) =>
        SurfaceTransitionCandidate(
          id: 'transition-wall-a-b',
          kind: SurfaceTransitionKind.roomPenetration,
          fromSurface: wallA,
          fromPoint: segments.first.points.last,
          toSurface: wallB,
          toPoint: segments.last.points.first,
          penetrationRequirement: BoundaryPenetrationRequirement(
            hostKind: BoundaryPenetrationHostKind.wall,
            hostThicknessMm: thicknessMm,
            materialId: 'brick',
          ),
        );

    test('materializes typed wall penetration into one route aggregate', () {
      final route = CablePenetrationAuthoring.build(
        routeId: 'route-1',
        source: const ElectricalEndpointRef(componentId: 'a', portId: 'out'),
        target: const ElectricalEndpointRef(componentId: 'b', portId: 'in'),
        segments: segments,
        resolveTransition: (_, __, ___, ____) => wallTransition(),
        penetrationIdFactory: (index, transition) =>
            BoundaryPenetrationId('route-1:p$index'),
      );

      expect(route.penetrations, hasLength(1));
      final penetration = route.penetrations.single;
      final penetrationId = BoundaryPenetrationId('route-1:p0');
      expect(penetration.id, penetrationId);
      expect(penetration.entryAnchor.penetrationId, penetrationId);
      expect(penetration.exitAnchor.penetrationId, penetrationId);
      expect(penetration.routeId, 'route-1');
      expect(penetration.hostThicknessMm, 180);
      expect(penetration.materialId, 'brick');
      expect(penetration.entryAnchor.surface, wallA);
      expect(penetration.exitAnchor.surface, wallB);
      expect(penetration.exitAnchor.isContinuationStart, isTrue);
      expect(route.hiddenPenetrationLengthMm, 180);
    });

    test('same geometry can allocate two distinct penetration identities', () {
      ElectricalCableRoute build(String rawId) =>
          CablePenetrationAuthoring.build(
            routeId: 'route-1',
            source: const ElectricalEndpointRef(
              componentId: 'a',
              portId: 'out',
            ),
            target: const ElectricalEndpointRef(
              componentId: 'b',
              portId: 'in',
            ),
            segments: segments,
            resolveTransition: (_, __, ___, ____) => wallTransition(),
            penetrationIdFactory: (_, __) => BoundaryPenetrationId(rawId),
          );

      final first = build('penetration-a').penetrations.single;
      final second = build('penetration-b').penetrations.single;

      expect(first.entryAnchor.point, second.entryAnchor.point);
      expect(first.exitAnchor.point, second.exitAnchor.point);
      expect(first.id, isNot(second.id));
    });

    test('missing construction thickness rejects the whole route', () {
      expect(
        () => CablePenetrationAuthoring.build(
          routeId: 'route-1',
          source: const ElectricalEndpointRef(componentId: 'a', portId: 'out'),
          target: const ElectricalEndpointRef(componentId: 'b', portId: 'in'),
          segments: segments,
          resolveTransition: (_, __, ___, ____) =>
              wallTransition(thicknessMm: null),
          penetrationIdFactory: (index, transition) =>
              BoundaryPenetrationId('route-1:p$index'),
        ),
        throwsStateError,
      );
    });

    test('missing transition evidence rejects cross-surface teleport', () {
      expect(
        () => CablePenetrationAuthoring.build(
          routeId: 'route-1',
          source: const ElectricalEndpointRef(componentId: 'a', portId: 'out'),
          target: const ElectricalEndpointRef(componentId: 'b', portId: 'in'),
          segments: segments,
          resolveTransition: (_, __, ___, ____) => null,
          penetrationIdFactory: (index, transition) =>
              BoundaryPenetrationId('route-1:p$index'),
        ),
        throwsStateError,
      );
    });

    test('mismatched transition coordinates are rejected fail closed', () {
      final invalid = SurfaceTransitionCandidate(
        id: 'invalid',
        kind: SurfaceTransitionKind.roomPenetration,
        fromSurface: wallA,
        fromPoint: const SurfacePointMm(901, 1200),
        toSurface: wallB,
        toPoint: segments.last.points.first,
        penetrationRequirement: const BoundaryPenetrationRequirement(
          hostKind: BoundaryPenetrationHostKind.wall,
          hostThicknessMm: 180,
        ),
      );

      expect(
        () => CablePenetrationAuthoring.build(
          routeId: 'route-1',
          source: const ElectricalEndpointRef(componentId: 'a', portId: 'out'),
          target: const ElectricalEndpointRef(componentId: 'b', portId: 'in'),
          segments: segments,
          resolveTransition: (_, __, ___, ____) => invalid,
          penetrationIdFactory: (index, transition) =>
              BoundaryPenetrationId('route-1:p$index'),
        ),
        throwsStateError,
      );
    });
  });
}
