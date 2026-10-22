import 'package:elecx/src/domain/boundary_host_migration.dart';
import 'package:elecx/src/domain/boundary_host_registry.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/boundary_wall_profile_registry.dart';
import 'package:elecx/src/domain/electrical_routing.dart';
import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_model.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/features/editor/canonical_boundary_host_projection.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('synthetic transition remains projection-only with opaque anchor ids', () {
    final spaceId = SpaceId('space');
    final first = BoundaryEdgeId('bottom-a');
    final second = BoundaryEdgeId('bottom-b');
    final east = BoundaryEdgeId('east');
    final north = BoundaryEdgeId('north');
    final west = BoundaryEdgeId('west');
    final legacy = EngineeringSpace(
      id: 'legacy-space',
      name: 'Room',
      type: SpaceType.room,
      boundary: MmPolygon.rectangle(
        const MmPoint(0, 0),
        const MmPoint(4000, 3000),
      ),
      referenceFrame: const RoomReferenceFrame(origin: MmPoint(2000, 1500)),
    );
    final topology = SpaceBoundaryTopology(
      spaceId: spaceId,
      orderedEdgeIds: [first, second, east, north, west],
      edges: {
        first: _edge(first, spaceId, 0, 0, 2000, 0),
        second: _edge(second, spaceId, 2000, 0, 4000, 0),
        east: _edge(east, spaceId, 4000, 0, 4000, 3000),
        north: _edge(north, spaceId, 4000, 3000, 0, 3000),
        west: _edge(west, spaceId, 0, 3000, 0, 0),
      },
    );
    final route = ElectricalCableRoute(
      id: 'opaque-route',
      source: const ElectricalEndpointRef(componentId: 's', portId: 'out'),
      target: const ElectricalEndpointRef(componentId: 't', portId: 'in'),
      segments: [
        ElectricalRouteSegment(
          surface: RoomSurfaceRef.wall(legacy.id, 0),
          points: const [
            SurfacePointMm(3500, 700),
            SurfacePointMm(2500, 700),
            SurfacePointMm(500, 700),
          ],
          anchorIds: [
            RouteAnchorId('source-placeholder'),
            RouteAnchorId('middle:anchor:opaque'),
            RouteAnchorId('target-placeholder'),
          ],
        ),
      ],
    );
    final canonical = BoundaryHostedObjectRegistry({
      'cable:opaque-route:source': BoundaryHostedReference.point(
        objectKey: 'cable:opaque-route:source',
        objectKind: BoundaryHostedObjectKind.cableEndpoint,
        host: BoundaryEdgeHostRef(spaceId: spaceId, edgeId: second),
        offsetMm: 1500,
      ),
      'route:opaque-route:anchor:middle:anchor:opaque':
          BoundaryHostedReference.point(
        objectKey: 'route:opaque-route:anchor:middle:anchor:opaque',
        objectKind: BoundaryHostedObjectKind.routeAnchor,
        host: BoundaryEdgeHostRef(spaceId: spaceId, edgeId: second),
        offsetMm: 500,
      ),
      'cable:opaque-route:target': BoundaryHostedReference.point(
        objectKey: 'cable:opaque-route:target',
        objectKind: BoundaryHostedObjectKind.cableEndpoint,
        host: BoundaryEdgeHostRef(spaceId: spaceId, edgeId: first),
        offsetMm: 500,
      ),
    });

    final materialized = CanonicalBoundaryHostProjection.materializeTopology(
      canonicalSpaceId: spaceId,
      legacySpace: legacy,
      topology: topology,
      registry: canonical,
      wallProfiles: const BoundaryWallProfileRegistry.empty(),
      openings: const [],
      p2State: EditorP2State(routes: [route]),
    );

    final transitionIds = [
      for (final segment in materialized.p2State.routes.single.segments)
        for (final id in segment.anchorIds)
          if (id.value.startsWith('p7a-transition:')) id,
    ];
    expect(transitionIds, hasLength(2));
    expect(transitionIds[0], transitionIds[1]);
    expect(transitionIds.first.value, contains(':anchor:'));

    final recaptured = CanonicalBoundaryHostProjection.capture(
      canonicalSpaceId: spaceId,
      legacySpace: materialized.space,
      orderedEdgeIds: topology.orderedEdgeIds,
      openings: materialized.openings,
      p2State: materialized.p2State,
    );

    expect(recaptured.sameAs(canonical), isTrue);
    expect(
      recaptured.references.values.where(
        (reference) => reference.objectKey.contains('p7a-transition:'),
      ),
      isEmpty,
    );
  });
}

ProjectBoundaryEdge _edge(
  BoundaryEdgeId id,
  SpaceId spaceId,
  int x1,
  int y1,
  int x2,
  int y2,
) =>
    ProjectBoundaryEdge(
      id: id,
      spaceId: spaceId,
      start: BoundaryPointMm(xMm: x1, yMm: y1),
      end: BoundaryPointMm(xMm: x2, yMm: y2),
    );
