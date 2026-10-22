import 'package:elecx/src/domain/boundary_host_migration.dart';
import 'package:elecx/src/domain/boundary_host_registry.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/boundary_wall_profile_registry.dart';
import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/electrical_routing.dart';
import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_model.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/domain/wall_profile.dart';
import 'package:elecx/src/features/editor/cable_route_constraints.dart';
import 'package:elecx/src/features/editor/canonical_boundary_host_projection.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P7A-5 production hosted-object projection', () {
    final canonicalSpaceId = SpaceId('space-a');
    final e0 = BoundaryEdgeId('edge-0');
    final e1 = BoundaryEdgeId('edge-1');
    final e2 = BoundaryEdgeId('edge-2');
    final e3 = BoundaryEdgeId('edge-3');
    final ordered = [e0, e1, e2, e3];

    EngineeringSpace room() => EngineeringSpace(
          id: 'legacy-room',
          name: 'Room',
          type: SpaceType.room,
          boundary: MmPolygon.rectangle(
            const MmPoint(0, 0),
            const MmPoint(4000, 3000),
          ),
          referenceFrame: const RoomReferenceFrame(
            origin: MmPoint(2000, 1500),
          ),
          wallProfiles: {
            0: WallProfile.rectangle(widthMm: 4000, heightMm: 3000),
          },
        );

    test('captures hosted objects and wall profiles in separate registries', () {
      final legacyRoom = room();
      final wall = RoomSurfaceRef.wall(legacyRoom.id, 0);
      final componentA = ElectricalComponentPlacement(
        id: 'c1',
        type: ElectricalComponentType.distributionBoard,
        surface: wall,
        position: const SurfacePointMm(500, 1200),
        label: 'Board',
        ports: const [
          ElectricalPortDefinition(
            id: 'power-out',
            kind: ElectricalPortKind.powerOut,
          ),
        ],
      );
      final componentB = ElectricalComponentPlacement(
        id: 'c2',
        type: ElectricalComponentType.socketOutlet,
        surface: wall,
        position: const SurfacePointMm(3000, 300),
        label: 'Socket',
        ports: const [
          ElectricalPortDefinition(
            id: 'power-in',
            kind: ElectricalPortKind.powerIn,
          ),
        ],
      );
      final route = ElectricalCableRoute(
        id: 'r1',
        source: const ElectricalEndpointRef(
          componentId: 'c1',
          portId: 'power-out',
        ),
        target: const ElectricalEndpointRef(
          componentId: 'c2',
          portId: 'power-in',
        ),
        segments: [
          ElectricalRouteSegment(
            surface: wall,
            points: const [
              SurfacePointMm(500, 1200),
              SurfacePointMm(1700, 1200),
              SurfacePointMm(3000, 300),
            ],
            anchorIds: [
              RouteAnchorId('route-source'),
              RouteAnchorId('anchor-1'),
              RouteAnchorId('route-target'),
            ],
          ),
        ],
      );
      final opening = ArchitecturalOpening(
        id: 'o1',
        hostWall: wall,
        type: ArchitecturalOpeningType.door,
        offsetFromStartMm: 2200,
        widthMm: 800,
        heightMm: 2100,
        sillHeightMm: 0,
      );

      final hosted = CanonicalBoundaryHostProjection.capture(
        canonicalSpaceId: canonicalSpaceId,
        legacySpace: legacyRoom,
        orderedEdgeIds: ordered,
        openings: [opening],
        p2State: EditorP2State(
          components: [componentA, componentB],
          routes: [route],
        ),
      );
      final profiles = CanonicalBoundaryHostProjection.captureWallProfiles(
        canonicalSpaceId: canonicalSpaceId,
        legacySpace: legacyRoom,
        orderedEdgeIds: ordered,
      );

      expect(hosted['opening:o1:space-a']!.host.edgeId, e0);
      expect(
        hosted['opening:o1:space-a']!.geometryKind,
        BoundaryHostGeometryKind.interval,
      );
      expect(hosted['component:c1']!.host.edgeId, e0);
      expect(hosted['component:c2']!.host.edgeId, e0);
      expect(hosted['cable:r1:source']!.host.edgeId, e0);
      expect(hosted['route:r1:anchor:anchor-1']!.host.edgeId, e0);
      expect(hosted['cable:r1:target']!.host.edgeId, e0);
      expect(
        hosted.references.values.any(
          (reference) =>
              reference.objectKind == BoundaryHostedObjectKind.wallProfile,
        ),
        isFalse,
      );
      expect(
        profiles[
          BoundaryEdgeHostRef(spaceId: canonicalSpaceId, edgeId: e0)
        ],
        isNotNull,
      );
    });

    test('legacy route interior point without RouteAnchorId fails closed', () {
      final legacyRoom = room();
      final wall = RoomSurfaceRef.wall(legacyRoom.id, 0);
      final route = ElectricalCableRoute(
        id: 'legacy-route',
        source: const ElectricalEndpointRef(componentId: 'c1', portId: 'out'),
        target: const ElectricalEndpointRef(componentId: 'c2', portId: 'in'),
        segments: [
          ElectricalRouteSegment(
            surface: wall,
            points: const [
              SurfacePointMm(500, 500),
              SurfacePointMm(1500, 500),
              SurfacePointMm(2500, 500),
            ],
          ),
        ],
      );

      expect(
        () => CanonicalBoundaryHostProjection.capture(
          canonicalSpaceId: canonicalSpaceId,
          legacySpace: legacyRoom,
          orderedEdgeIds: ordered,
          openings: const [],
          p2State: EditorP2State(routes: [route]),
        ),
        throwsStateError,
      );
    });

    test('stable BoundaryEdgeId surfaces are captured without wallIndex', () {
      final legacyRoom = room();
      final stableWall = RoomSurfaceRef.wallByBoundaryEdge(legacyRoom.id, e2);
      final component = ElectricalComponentPlacement(
        id: 'stable-c1',
        type: ElectricalComponentType.socketOutlet,
        surface: stableWall,
        position: const SurfacePointMm(700, 300),
        label: 'Stable socket',
      );
      final opening = ArchitecturalOpening(
        id: 'stable-o1',
        hostWall: stableWall,
        type: ArchitecturalOpeningType.window,
        offsetFromStartMm: 500,
        widthMm: 900,
        heightMm: 1200,
        sillHeightMm: 900,
      );

      final hosted = CanonicalBoundaryHostProjection.capture(
        canonicalSpaceId: canonicalSpaceId,
        legacySpace: legacyRoom,
        orderedEdgeIds: ordered,
        openings: [opening],
        p2State: EditorP2State(components: [component]),
      );

      expect(hosted['opening:stable-o1:space-a']!.host.edgeId, e2);
      expect(hosted['component:stable-c1']!.host.edgeId, e2);
    });

    test('materializes remapped ids back to transient ordinal without id drift',
        () {
      final legacyRoom = room();
      final wall = RoomSurfaceRef.wall(legacyRoom.id, 0);
      final component = ElectricalComponentPlacement(
        id: 'c1',
        type: ElectricalComponentType.socketOutlet,
        surface: wall,
        position: const SurfacePointMm(500, 300),
        label: 'Socket',
      );
      final opening = ArchitecturalOpening(
        id: 'o1',
        hostWall: wall,
        type: ArchitecturalOpeningType.window,
        offsetFromStartMm: 500,
        widthMm: 1000,
        heightMm: 1200,
        sillHeightMm: 900,
      );
      final registry = CanonicalBoundaryHostProjection.capture(
        canonicalSpaceId: canonicalSpaceId,
        legacySpace: legacyRoom,
        orderedEdgeIds: ordered,
        openings: [opening],
        p2State: EditorP2State(components: [component]),
      );
      final profiles = CanonicalBoundaryHostProjection.captureWallProfiles(
        canonicalSpaceId: canonicalSpaceId,
        legacySpace: legacyRoom,
        orderedEdgeIds: ordered,
      );

      final remapped = registry
          .put(
            BoundaryHostedReference.interval(
              objectKey: 'opening:o1:space-a',
              objectKind: BoundaryHostedObjectKind.opening,
              host: BoundaryEdgeHostRef(
                spaceId: canonicalSpaceId,
                edgeId: e2,
              ),
              startOffsetMm: 300,
              endOffsetMm: 1300,
            ),
          )
          .put(
            BoundaryHostedReference.point(
              objectKey: 'component:c1',
              objectKind: BoundaryHostedObjectKind.component,
              host: BoundaryEdgeHostRef(
                spaceId: canonicalSpaceId,
                edgeId: e2,
              ),
              offsetMm: 700,
            ),
          );

      final materialized = CanonicalBoundaryHostProjection.materialize(
        canonicalSpaceId: canonicalSpaceId,
        legacySpace: legacyRoom,
        orderedEdgeIds: ordered,
        registry: remapped,
        wallProfiles: profiles,
        openings: [opening],
        p2State: EditorP2State(components: [component]),
      );

      expect(materialized.openings.single.id, 'o1');
      expect(materialized.openings.single.hostWall.wallIndex, 2);
      expect(materialized.openings.single.offsetFromStartMm, 300);
      expect(materialized.openings.single.widthMm, 1000);
      expect(materialized.p2State.components.single.id, 'c1');
      expect(materialized.p2State.components.single.surface.wallIndex, 2);
      expect(
        materialized.p2State.components.single.position,
        const SurfacePointMm(700, 300),
      );
      expect(materialized.space.boundaryEdgeWallProfiles[e0], isNotNull);
    });

    test('topology-aware materialization reconstructs wall count after split', () {
      final legacyRoom = room();
      final bottomA = BoundaryEdgeId('bottom-a');
      final bottomB = BoundaryEdgeId('bottom-b');
      final topology = _splitBottomTopology(
        canonicalSpaceId: canonicalSpaceId,
        bottomA: bottomA,
        bottomB: bottomB,
        e1: e1,
        e2: e2,
        e3: e3,
      );
      final component = ElectricalComponentPlacement(
        id: 'c1',
        type: ElectricalComponentType.socketOutlet,
        surface: RoomSurfaceRef.wall(legacyRoom.id, 0),
        position: const SurfacePointMm(3000, 300),
        label: 'Socket',
      );
      final hosted = BoundaryHostedObjectRegistry({
        'component:c1': BoundaryHostedReference.point(
          objectKey: 'component:c1',
          objectKind: BoundaryHostedObjectKind.component,
          host: BoundaryEdgeHostRef(
            spaceId: canonicalSpaceId,
            edgeId: bottomB,
          ),
          offsetMm: 1000,
        ),
      });

      final materialized = CanonicalBoundaryHostProjection.materializeTopology(
        canonicalSpaceId: canonicalSpaceId,
        legacySpace: legacyRoom,
        topology: topology,
        registry: hosted,
        wallProfiles: const BoundaryWallProfileRegistry.empty(),
        openings: const [],
        p2State: EditorP2State(components: [component]),
      );

      expect(materialized.space.boundary.vertices, hasLength(5));
      expect(materialized.p2State.components.single.surface.wallIndex, 1);
      expect(
        materialized.p2State.components.single.position,
        const SurfacePointMm(1000, 300),
      );
      expect(materialized.space.wallProfiles, isEmpty);
    });

    test('collinear split materializes one route segment as two losslessly', () {
      final legacyRoom = room();
      final bottomA = BoundaryEdgeId('bottom-a');
      final bottomB = BoundaryEdgeId('bottom-b');
      final topology = _splitBottomTopology(
        canonicalSpaceId: canonicalSpaceId,
        bottomA: bottomA,
        bottomB: bottomB,
        e1: e1,
        e2: e2,
        e3: e3,
      );
      final route = ElectricalCableRoute(
        id: 'split-route',
        source: const ElectricalEndpointRef(componentId: 'c1', portId: 'out'),
        target: const ElectricalEndpointRef(componentId: 'c2', portId: 'in'),
        segments: [
          ElectricalRouteSegment(
            surface: RoomSurfaceRef.wall(legacyRoom.id, 0),
            points: const [
              SurfacePointMm(500, 500),
              SurfacePointMm(2500, 500),
              SurfacePointMm(3500, 500),
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
        'cable:split-route:source': BoundaryHostedReference.point(
          objectKey: 'cable:split-route:source',
          objectKind: BoundaryHostedObjectKind.cableEndpoint,
          host: BoundaryEdgeHostRef(spaceId: canonicalSpaceId, edgeId: bottomA),
          offsetMm: 500,
        ),
        'route:split-route:anchor:middle': BoundaryHostedReference.point(
          objectKey: 'route:split-route:anchor:middle',
          objectKind: BoundaryHostedObjectKind.routeAnchor,
          host: BoundaryEdgeHostRef(spaceId: canonicalSpaceId, edgeId: bottomB),
          offsetMm: 500,
        ),
        'cable:split-route:target': BoundaryHostedReference.point(
          objectKey: 'cable:split-route:target',
          objectKind: BoundaryHostedObjectKind.cableEndpoint,
          host: BoundaryEdgeHostRef(spaceId: canonicalSpaceId, edgeId: bottomB),
          offsetMm: 1500,
        ),
      });
      final constraints = CableRouteConstraints(
        lockedSegments: {0},
        mandatoryWaypoints: const [
          CableMandatoryWaypoint(
            segmentIndex: 0,
            pointIndex: 1,
            point: SurfacePointMm(2500, 500),
          ),
        ],
      );

      final materialized = CanonicalBoundaryHostProjection.materializeTopology(
        canonicalSpaceId: canonicalSpaceId,
        legacySpace: legacyRoom,
        topology: topology,
        registry: registry,
        wallProfiles: const BoundaryWallProfileRegistry.empty(),
        openings: const [],
        p2State: EditorP2State(
          routes: [route],
          routeConstraints: {'split-route': constraints},
        ),
      );

      final result = materialized.p2State.routes.single;
      expect(result.id, 'split-route');
      expect(result.segments, hasLength(2));
      expect(result.segments[0].surface.wallIndex, 0);
      expect(result.segments[1].surface.wallIndex, 1);
      expect(result.segments[0].points.last, const SurfacePointMm(2000, 500));
      expect(result.segments[1].points.first, const SurfacePointMm(0, 500));
      expect(result.segments[1].anchorIds[1], RouteAnchorId('middle'));

      final resultConstraints =
          materialized.p2State.routeConstraints['split-route']!;
      expect(resultConstraints.lockedSegments, {0, 1});
      expect(resultConstraints.mandatoryWaypoints.single.segmentIndex, 1);
      expect(resultConstraints.mandatoryWaypoints.single.pointIndex, 1);
      expect(
        resultConstraints.mandatoryWaypoints.single.point,
        const SurfacePointMm(500, 500),
      );
    });

    test('route crossing a real corner remains fail closed', () {
      final legacyRoom = room();
      final wall = RoomSurfaceRef.wall(legacyRoom.id, 0);
      final route = ElectricalCableRoute(
        id: 'r1',
        source: const ElectricalEndpointRef(componentId: 'c1', portId: 'out'),
        target: const ElectricalEndpointRef(componentId: 'c2', portId: 'in'),
        segments: [
          ElectricalRouteSegment(
            surface: wall,
            points: const [
              SurfacePointMm(500, 500),
              SurfacePointMm(2000, 500),
              SurfacePointMm(3500, 500),
            ],
            anchorIds: [
              RouteAnchorId('route-source'),
              RouteAnchorId('crossing-anchor'),
              RouteAnchorId('route-target'),
            ],
          ),
        ],
      );
      final p2 = EditorP2State(routes: [route]);
      final captured = CanonicalBoundaryHostProjection.capture(
        canonicalSpaceId: canonicalSpaceId,
        legacySpace: legacyRoom,
        orderedEdgeIds: ordered,
        openings: const [],
        p2State: p2,
      );
      final incompatible = captured.put(
        BoundaryHostedReference.point(
          objectKey: 'route:r1:anchor:crossing-anchor',
          objectKind: BoundaryHostedObjectKind.routeAnchor,
          host: BoundaryEdgeHostRef(
            spaceId: canonicalSpaceId,
            edgeId: e1,
          ),
          offsetMm: 400,
        ),
      );

      expect(
        () => CanonicalBoundaryHostProjection.materialize(
          canonicalSpaceId: canonicalSpaceId,
          legacySpace: legacyRoom,
          orderedEdgeIds: ordered,
          registry: incompatible,
          openings: const [],
          p2State: p2,
        ),
        throwsStateError,
      );
    });
  });
}

SpaceBoundaryTopology _splitBottomTopology({
  required SpaceId canonicalSpaceId,
  required BoundaryEdgeId bottomA,
  required BoundaryEdgeId bottomB,
  required BoundaryEdgeId e1,
  required BoundaryEdgeId e2,
  required BoundaryEdgeId e3,
}) =>
    SpaceBoundaryTopology(
      spaceId: canonicalSpaceId,
      orderedEdgeIds: [bottomA, bottomB, e1, e2, e3],
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
        e1: ProjectBoundaryEdge(
          id: e1,
          spaceId: canonicalSpaceId,
          start: const BoundaryPointMm(xMm: 4000, yMm: 0),
          end: const BoundaryPointMm(xMm: 4000, yMm: 3000),
        ),
        e2: ProjectBoundaryEdge(
          id: e2,
          spaceId: canonicalSpaceId,
          start: const BoundaryPointMm(xMm: 4000, yMm: 3000),
          end: const BoundaryPointMm(xMm: 0, yMm: 3000),
        ),
        e3: ProjectBoundaryEdge(
          id: e3,
          spaceId: canonicalSpaceId,
          start: const BoundaryPointMm(xMm: 0, yMm: 3000),
          end: const BoundaryPointMm(xMm: 0, yMm: 0),
        ),
      },
    );
