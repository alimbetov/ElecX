import 'package:elecx/src/domain/boundary_host_migration.dart';
import 'package:elecx/src/domain/boundary_host_registry.dart';
import 'package:elecx/src/domain/boundary_penetration.dart';
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
  test('P7A wall split remaps penetration entry without identity drift', () {
    final canonicalSpaceId = SpaceId('space-a');
    final bottomA = BoundaryEdgeId('bottom-a');
    final bottomB = BoundaryEdgeId('bottom-b');
    final east = BoundaryEdgeId('east');
    final north = BoundaryEdgeId('north');
    final west = BoundaryEdgeId('west');
    final legacyRoom = EngineeringSpace(
      id: 'legacy-room-a',
      name: 'Room A',
      type: SpaceType.room,
      boundary: MmPolygon.rectangle(
        const MmPoint(0, 0),
        const MmPoint(4000, 3000),
      ),
      referenceFrame: const RoomReferenceFrame(
        origin: MmPoint(2000, 1500),
      ),
    );
    final entrySurface = RoomSurfaceRef.wall(legacyRoom.id, 0);
    final exitSurface = RoomSurfaceRef.wall('legacy-room-b', 0);
    final segments = <ElectricalRouteSegment>[
      ElectricalRouteSegment(
        surface: entrySurface,
        points: const [
          SurfacePointMm(500, 900),
          SurfacePointMm(2500, 900),
        ],
        anchorIds: [
          RouteAnchorId('source-anchor'),
          RouteAnchorId('penetration-entry'),
        ],
      ),
      ElectricalRouteSegment(
        surface: exitSurface,
        points: const [
          SurfacePointMm(300, 900),
          SurfacePointMm(1200, 900),
        ],
        anchorIds: [
          RouteAnchorId('penetration-exit'),
          RouteAnchorId('target-anchor'),
        ],
      ),
    ];
    final penetration = BoundaryPenetration.normal(
      id: 'penetration-1',
      hostKind: BoundaryPenetrationHostKind.wall,
      entrySurface: entrySurface,
      entryPoint: segments.first.points.last,
      exitSurface: exitSurface,
      exitPoint: segments.last.points.first,
      hostThicknessMm: 180,
      routeId: 'route-1',
      materialId: 'brick',
    );
    final route = ElectricalCableRoute(
      id: 'route-1',
      source: const ElectricalEndpointRef(
        componentId: 'source',
        portId: 'out',
      ),
      target: const ElectricalEndpointRef(
        componentId: 'target',
        portId: 'in',
      ),
      segments: segments,
      penetrations: [penetration],
    );
    final registry = BoundaryHostedObjectRegistry({
      BoundaryHostedObjectRegistry.cableSourceObjectKey(route.id):
          BoundaryHostedReference.point(
        objectKey: BoundaryHostedObjectRegistry.cableSourceObjectKey(route.id),
        objectKind: BoundaryHostedObjectKind.cableEndpoint,
        host: BoundaryEdgeHostRef(
          spaceId: canonicalSpaceId,
          edgeId: bottomA,
        ),
        offsetMm: 500,
      ),
      BoundaryHostedObjectRegistry.routeAnchorObjectKey(
        route.id,
        RouteAnchorId('penetration-entry'),
      ): BoundaryHostedReference.point(
        objectKey: BoundaryHostedObjectRegistry.routeAnchorObjectKey(
          route.id,
          RouteAnchorId('penetration-entry'),
        ),
        objectKind: BoundaryHostedObjectKind.routeAnchor,
        host: BoundaryEdgeHostRef(
          spaceId: canonicalSpaceId,
          edgeId: bottomB,
        ),
        offsetMm: 500,
      ),
    });
    final topology = SpaceBoundaryTopology(
      spaceId: canonicalSpaceId,
      orderedEdgeIds: [bottomA, bottomB, east, north, west],
      edges: {
        bottomA: ProjectBoundaryEdge(
          id: bottomA,
          spaceId: canonicalSpaceId,
          start: const BoundaryPointMm(xMm: 0, yMm: 0),
          end: const BoundaryPointMm(xMm: 2000, yMm: 0),
        ),
        bottomB: ProjectBoundaryEdge(
          id: bottomB,
          spaceId: canonicalSpaceId,
          start: const BoundaryPointMm(xMm: 2000, yMm: 0),
          end: const BoundaryPointMm(xMm: 4000, yMm: 0),
        ),
        east: ProjectBoundaryEdge(
          id: east,
          spaceId: canonicalSpaceId,
          start: const BoundaryPointMm(xMm: 4000, yMm: 0),
          end: const BoundaryPointMm(xMm: 4000, yMm: 3000),
        ),
        north: ProjectBoundaryEdge(
          id: north,
          spaceId: canonicalSpaceId,
          start: const BoundaryPointMm(xMm: 4000, yMm: 3000),
          end: const BoundaryPointMm(xMm: 0, yMm: 3000),
        ),
        west: ProjectBoundaryEdge(
          id: west,
          spaceId: canonicalSpaceId,
          start: const BoundaryPointMm(xMm: 0, yMm: 3000),
          end: const BoundaryPointMm(xMm: 0, yMm: 0),
        ),
      },
    );

    final materialized = CanonicalBoundaryHostProjection.materializeTopology(
      canonicalSpaceId: canonicalSpaceId,
      legacySpace: legacyRoom,
      topology: topology,
      registry: registry,
      wallProfiles: const BoundaryWallProfileRegistry.empty(),
      openings: const [],
      p2State: EditorP2State(routes: [route]),
    );

    final result = materialized.p2State.routes.single;
    expect(result.id, route.id);
    expect(result.segments, hasLength(3));
    expect(result.penetrations, hasLength(1));
    final remapped = result.penetrations.single;
    expect(remapped.id, penetration.id);
    expect(remapped.routeId, route.id);
    expect(remapped.entryAnchor.id, penetration.entryAnchor.id);
    expect(remapped.exitAnchor.id, penetration.exitAnchor.id);
    expect(remapped.hostThicknessMm, 180);
    expect(remapped.pathLengthMm, 180);
    expect(remapped.materialId, 'brick');
    expect(remapped.entryAnchor.surface.wallIndex, 1);
    expect(remapped.entryAnchor.point, const SurfacePointMm(500, 900));
    expect(remapped.exitAnchor.surface, exitSurface);
    expect(remapped.exitAnchor.point, const SurfacePointMm(300, 900));
    expect(result.segments[1].points.last, remapped.entryAnchor.point);
    expect(result.segments[2].points.first, remapped.exitAnchor.point);
  });
}
