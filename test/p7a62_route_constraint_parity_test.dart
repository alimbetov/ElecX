import 'package:elecx/src/domain/boundary_host_migration.dart';
import 'package:elecx/src/domain/boundary_host_registry.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/boundary_wall_profile_registry.dart';
import 'package:elecx/src/domain/electrical_routing.dart';
import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_model.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/features/editor/cable_route_constraints.dart';
import 'package:elecx/src/features/editor/canonical_boundary_host_projection.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reverse split preserves stable anchor, lock and mandatory waypoint',
      () {
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
        a: _edge(a, spaceId, 0, 0, 2000, 0),
        b: _edge(b, spaceId, 2000, 0, 4000, 0),
        east: _edge(east, spaceId, 4000, 0, 4000, 3000),
        north: _edge(north, spaceId, 4000, 3000, 0, 3000),
        west: _edge(west, spaceId, 0, 3000, 0, 0),
      },
    );
    final route = ElectricalCableRoute(
      id: 'reverse-constrained',
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
            RouteAnchorId('middle-stable'),
            RouteAnchorId('target-placeholder'),
          ],
        ),
      ],
    );
    final registry = BoundaryHostedObjectRegistry({
      'cable:reverse-constrained:source': BoundaryHostedReference.point(
        objectKey: 'cable:reverse-constrained:source',
        objectKind: BoundaryHostedObjectKind.cableEndpoint,
        host: BoundaryEdgeHostRef(spaceId: spaceId, edgeId: b),
        offsetMm: 1500,
      ),
      'route:reverse-constrained:anchor:middle-stable':
          BoundaryHostedReference.point(
        objectKey: 'route:reverse-constrained:anchor:middle-stable',
        objectKind: BoundaryHostedObjectKind.routeAnchor,
        host: BoundaryEdgeHostRef(spaceId: spaceId, edgeId: b),
        offsetMm: 500,
      ),
      'cable:reverse-constrained:target': BoundaryHostedReference.point(
        objectKey: 'cable:reverse-constrained:target',
        objectKind: BoundaryHostedObjectKind.cableEndpoint,
        host: BoundaryEdgeHostRef(spaceId: spaceId, edgeId: a),
        offsetMm: 500,
      ),
    });
    final constraints = CableRouteConstraints(
      lockedSegments: {0},
      mandatoryWaypoints: const [
        CableMandatoryWaypoint(
          segmentIndex: 0,
          pointIndex: 1,
          point: SurfacePointMm(2500, 700),
        ),
      ],
    );

    final materialized = CanonicalBoundaryHostProjection.materializeTopology(
      canonicalSpaceId: spaceId,
      legacySpace: legacy,
      topology: topology,
      registry: registry,
      wallProfiles: const BoundaryWallProfileRegistry.empty(),
      openings: const [],
      p2State: EditorP2State(
        routes: [route],
        routeConstraints: {route.id: constraints},
      ),
    );

    final resultRoute = materialized.p2State.routes.single;
    final resultConstraints = materialized.p2State.routeConstraints[route.id]!;

    expect(resultRoute.segments, hasLength(2));
    expect(resultRoute.segments[0].surface.wallIndex, 1);
    expect(resultRoute.segments[1].surface.wallIndex, 0);
    expect(
      resultRoute.segments[0].anchorIds,
      contains(RouteAnchorId('middle-stable')),
    );
    expect(resultConstraints.lockedSegments, {0, 1});
    expect(resultConstraints.mandatoryWaypoints, hasLength(1));
    expect(resultConstraints.mandatoryWaypoints.single.segmentIndex, 0);
    expect(resultConstraints.mandatoryWaypoints.single.pointIndex, 1);
    expect(
      resultConstraints.mandatoryWaypoints.single.point,
      const SurfacePointMm(500, 700),
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
