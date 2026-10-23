import 'package:elecx/src/domain/boundary_penetration.dart';
import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/electrical_routing.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:elecx/src/features/editor/physical_cable_route_committer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('route and penetration undo/redo as one aggregate', () {
    final wallA = RoomSurfaceRef.wallByBoundaryEdge(
      'space-a',
      BoundaryEdgeId('edge-a'),
    );
    final wallB = RoomSurfaceRef.wallByBoundaryEdge(
      'space-b',
      BoundaryEdgeId('edge-b'),
    );
    final source = ElectricalComponentPlacement(
      id: 'source',
      type: ElectricalComponentType.powerSource,
      surface: wallA,
      position: const SurfacePointMm(100, 1000),
      label: 'Source',
      ports: const [
        ElectricalPortDefinition(
          id: 'out',
          kind: ElectricalPortKind.powerOut,
        ),
      ],
    );
    final target = ElectricalComponentPlacement(
      id: 'target',
      type: ElectricalComponentType.socketOutlet,
      surface: wallB,
      position: const SurfacePointMm(900, 1000),
      label: 'Target',
      ports: const [
        ElectricalPortDefinition(
          id: 'in',
          kind: ElectricalPortKind.powerIn,
        ),
      ],
    );
    final segments = [
      ElectricalRouteSegment(
        surface: wallA,
        points: const [
          SurfacePointMm(100, 1000),
          SurfacePointMm(700, 1000),
        ],
      ),
      ElectricalRouteSegment(
        surface: wallB,
        points: const [
          SurfacePointMm(200, 1000),
          SurfacePointMm(900, 1000),
        ],
      ),
    ];
    final penetration = BoundaryPenetration.normal(
      id: 'p-1',
      hostKind: BoundaryPenetrationHostKind.wall,
      entrySurface: wallA,
      entryPoint: segments.first.points.last,
      exitSurface: wallB,
      exitPoint: segments.last.points.first,
      hostThicknessMm: 180,
      routeId: 'route-physical',
      materialId: 'brick',
    );
    final route = ElectricalCableRoute(
      id: 'route-physical',
      source: const ElectricalEndpointRef(componentId: 'source', portId: 'out'),
      target: const ElectricalEndpointRef(componentId: 'target', portId: 'in'),
      segments: segments,
      penetrations: [penetration],
    );
    final session = EditorP2Session(
      initialState: EditorP2State(components: [source, target]),
    );
    addTearDown(session.dispose);

    expect(session.commitPhysicalCableRoute(route), isTrue);
    expect(session.routes.single.penetrations.single.id, 'p-1');
    expect(session.history.undoLabel, 'Create physical cable route with penetrations');

    session.undo();
    expect(session.routes, isEmpty);

    session.redo();
    expect(session.routes.single.id, 'route-physical');
    expect(session.routes.single.penetrations.single.id, 'p-1');
  });

  test('duplicate physical route id is rejected before history mutation', () {
    final wall = RoomSurfaceRef.wall('space-a', 0);
    final source = ElectricalComponentPlacement(
      id: 'source',
      type: ElectricalComponentType.powerSource,
      surface: wall,
      position: const SurfacePointMm(100, 1000),
      label: 'Source',
      ports: const [
        ElectricalPortDefinition(
          id: 'out',
          kind: ElectricalPortKind.powerOut,
        ),
      ],
    );
    final target = ElectricalComponentPlacement(
      id: 'target',
      type: ElectricalComponentType.socketOutlet,
      surface: wall,
      position: const SurfacePointMm(900, 1000),
      label: 'Target',
      ports: const [
        ElectricalPortDefinition(
          id: 'in',
          kind: ElectricalPortKind.powerIn,
        ),
      ],
    );
    final route = ElectricalCableRoute(
      id: 'route-1',
      source: const ElectricalEndpointRef(componentId: 'source', portId: 'out'),
      target: const ElectricalEndpointRef(componentId: 'target', portId: 'in'),
      segments: [
        ElectricalRouteSegment(
          surface: wall,
          points: const [
            SurfacePointMm(100, 1000),
            SurfacePointMm(900, 1000),
          ],
        ),
      ],
    );
    final session = EditorP2Session(
      initialState: EditorP2State(components: [source, target]),
    );
    addTearDown(session.dispose);

    expect(session.commitPhysicalCableRoute(route), isTrue);
    final revision = session.history.mutationRevision;
    expect(session.commitPhysicalCableRoute(route), isFalse);
    expect(session.history.mutationRevision, revision);
    expect(session.routes, hasLength(1));
  });
}
