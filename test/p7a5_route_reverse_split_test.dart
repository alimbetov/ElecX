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
  test('route may traverse split children in reverse boundary order', () {
    final spaceId = SpaceId('space');
    final a = BoundaryEdgeId('bottom-a');
    final b = BoundaryEdgeId('bottom-b');
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
      orderedEdgeIds: [a, b, east, north, west],
      edges: {
        a: ProjectBoundaryEdge(
          id: a,
          spaceId: spaceId,
          start: const BoundaryPointMm(xMm: 0, yMm: 0),
          end: const BoundaryPointMm(xMm: 2000, yMm: 0),
        ),
        b: ProjectBoundaryEdge(
          id: b,
          spaceId: spaceId,
          start: const BoundaryPointMm(xMm: 2000, yMm: 0),
          end: const BoundaryPointMm(xMm: 4000, yMm: 0),
        ),
        east: ProjectBoundaryEdge(
          id: east,
          spaceId: spaceId,
          start: const BoundaryPointMm(xMm: 4000, yMm: 0),
          end: const BoundaryPointMm(xMm: 4000, yMm: 3000),
        ),
        north: ProjectBoundaryEdge(
          id: north,
          spaceId: spaceId,
          start: const BoundaryPointMm(xMm: 4000, yMm: 3000),
          end: const BoundaryPointMm(xMm: 0, yMm: 3000),
        ),
        west: ProjectBoundaryEdge(
          id: west,
          spaceId: spaceId,
          start: const BoundaryPointMm(xMm: 0, yMm: 3000),
          end: const BoundaryPointMm(xMm: 0, yMm: 0),
        ),
      },
    );
    final route = ElectricalCableRoute(
      id: 'reverse',
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
            RouteAnchorId('source'),
            RouteAnchorId('middle'),
            RouteAnchorId('target'),
          ],
        ),
      ],
    );
    final registry = BoundaryHostedObjectRegistry({
      'cable:reverse:source': BoundaryHostedReference.point(
        objectKey: 'cable:reverse:source',
        objectKind: BoundaryHostedObjectKind.cableEndpoint,
        host: BoundaryEdgeHostRef(spaceId: spaceId, edgeId: b),
        offsetMm: 1500,
      ),
      'route:reverse:anchor:middle': BoundaryHostedReference.point(
        objectKey: 'route:reverse:anchor:middle',
        objectKind: BoundaryHostedObjectKind.routeAnchor,
        host: BoundaryEdgeHostRef(spaceId: spaceId, edgeId: b),
        offsetMm: 500,
      ),
      'cable:reverse:target': BoundaryHostedReference.point(
        objectKey: 'cable:reverse:target',
        objectKind: BoundaryHostedObjectKind.cableEndpoint,
        host: BoundaryEdgeHostRef(spaceId: spaceId, edgeId: a),
        offsetMm: 500,
      ),
    });

    final materialized = CanonicalBoundaryHostProjection.materializeTopology(
      canonicalSpaceId: spaceId,
      legacySpace: legacy,
      topology: topology,
      registry: registry,
      wallProfiles: const BoundaryWallProfileRegistry.empty(),
      openings: const [],
      p2State: EditorP2State(routes: [route]),
    );

    final segments = materialized.p2State.routes.single.segments;
    expect(segments, hasLength(2));
    expect(segments[0].surface.wallIndex, 1);
    expect(segments[0].points.last, const SurfacePointMm(0, 700));
    expect(segments[1].surface.wallIndex, 0);
    expect(segments[1].points.first, const SurfacePointMm(2000, 700));
    expect(segments[1].anchorIds.last, RouteAnchorId('target'));
  });
}
