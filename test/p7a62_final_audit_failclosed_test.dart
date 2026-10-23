import 'package:elecx/src/domain/boundary_host_migration.dart';
import 'package:elecx/src/domain/boundary_host_registry.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/electrical_routing.dart';
import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_model.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/features/editor/canonical_boundary_host_projection.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P7A-6.2 final adversarial audit', () {
    test('whole-edge preserved lineage rejects a missing result edge', () {
      final spaceId = SpaceId('space');
      final source = BoundaryEdgeId('source');
      final east = BoundaryEdgeId('east');
      final north = BoundaryEdgeId('north');
      final west = BoundaryEdgeId('west');
      final replacement = BoundaryEdgeId('replacement');
      final before = _topology(
        spaceId,
        [source, east, north, west],
        {
          source: _edge(source, spaceId, 0, 0, 4000, 0),
          east: _edge(east, spaceId, 4000, 0, 4000, 3000),
          north: _edge(north, spaceId, 4000, 3000, 0, 3000),
          west: _edge(west, spaceId, 0, 3000, 0, 0),
        },
      );
      final after = _topology(
        spaceId,
        [replacement, east, north, west],
        {
          replacement: _edge(replacement, spaceId, 0, 0, 4000, 0),
          east: _edge(east, spaceId, 4000, 0, 4000, 3000),
          north: _edge(north, spaceId, 4000, 3000, 0, 3000),
          west: _edge(west, spaceId, 0, 3000, 0, 0),
        },
      );
      final malformedLineage = BoundaryTopologyChangeSet([
        BoundaryEdgeLineage.preserved(source),
        BoundaryEdgeLineage.preserved(east),
        BoundaryEdgeLineage.preserved(north),
        BoundaryEdgeLineage.preserved(west),
      ]);
      final reference = BoundaryHostedReference.wholeEdge(
        objectKey: 'domain:whole-source',
        objectKind: BoundaryHostedObjectKind.component,
        host: BoundaryEdgeHostRef(spaceId: spaceId, edgeId: source),
      );

      expect(
        () => BoundaryHostedObjectRemapper.remapAll(
          before: before,
          after: after,
          lineage: malformedLineage,
          references: [reference],
        ),
        throwsA(
          isA<BoundaryHostMigrationException>().having(
            (error) => error.code,
            'code',
            BoundaryHostMigrationIssueCode.resultEdgeMissing,
          ),
        ),
      );
    });

    test(
      'historically colliding route-anchor identities remain distinct',
      () {
        final legacySpace = EngineeringSpace(
          id: 'legacy-room',
          name: 'Room',
          type: SpaceType.room,
          boundary: MmPolygon.rectangle(
            const MmPoint(0, 0),
            const MmPoint(4000, 3000),
          ),
          referenceFrame: const RoomReferenceFrame(origin: MmPoint(2000, 1500)),
        );
        final wall = RoomSurfaceRef.wall(legacySpace.id, 0);
        final routeA = _route(
          id: 'x',
          wall: wall,
          middleOffset: 1000,
          middleAnchor: RouteAnchorId('y:anchor:z'),
        );
        final routeB = _route(
          id: 'x:anchor:y',
          wall: wall,
          middleOffset: 2000,
          middleAnchor: RouteAnchorId('z'),
        );

        final captured = CanonicalBoundaryHostProjection.capture(
          canonicalSpaceId: SpaceId('space'),
          legacySpace: legacySpace,
          orderedEdgeIds: [
            BoundaryEdgeId('bottom'),
            BoundaryEdgeId('east'),
            BoundaryEdgeId('north'),
            BoundaryEdgeId('west'),
          ],
          openings: const [],
          p2State: EditorP2State(routes: [routeA, routeB]),
        );
        final keyA = BoundaryHostedObjectRegistry.routeAnchorObjectKey(
          routeA.id,
          RouteAnchorId('y:anchor:z'),
        );
        final keyB = BoundaryHostedObjectRegistry.routeAnchorObjectKey(
          routeB.id,
          RouteAnchorId('z'),
        );

        expect(keyA, isNot(keyB));
        expect(captured[keyA]?.startOffsetMm, 1000);
        expect(captured[keyB]?.startOffsetMm, 2000);
      },
    );
  });
}

ElectricalCableRoute _route({
  required String id,
  required RoomSurfaceRef wall,
  required int middleOffset,
  required RouteAnchorId middleAnchor,
}) =>
    ElectricalCableRoute(
      id: id,
      source: ElectricalEndpointRef(componentId: '$id-source', portId: 'out'),
      target: ElectricalEndpointRef(componentId: '$id-target', portId: 'in'),
      segments: [
        ElectricalRouteSegment(
          surface: wall,
          points: [
            const SurfacePointMm(500, 700),
            SurfacePointMm(middleOffset, 700),
            const SurfacePointMm(3500, 700),
          ],
          anchorIds: [
            RouteAnchorId('$id-source-anchor'),
            middleAnchor,
            RouteAnchorId('$id-target-anchor'),
          ],
        ),
      ],
    );

SpaceBoundaryTopology _topology(
  SpaceId spaceId,
  List<BoundaryEdgeId> ordered,
  Map<BoundaryEdgeId, ProjectBoundaryEdge> edges,
) =>
    SpaceBoundaryTopology(
      spaceId: spaceId,
      orderedEdgeIds: ordered,
      edges: edges,
    );

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
