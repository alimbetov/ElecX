import 'package:elecx/src/domain/boundary_penetration.dart';
import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/electrical_routing.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:elecx/src/features/editor/physical_cable_route_committer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('physical route replacement preserves route and penetration identity',
      () {
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
    final initialTarget = ElectricalComponentPlacement(
      id: 'target-a',
      type: ElectricalComponentType.socketOutlet,
      surface: wallB,
      position: const SurfacePointMm(900, 1000),
      label: 'Initial target',
      ports: const [
        ElectricalPortDefinition(
          id: 'in',
          kind: ElectricalPortKind.powerIn,
        ),
      ],
    );
    final extendedTarget = ElectricalComponentPlacement(
      id: 'target-b',
      type: ElectricalComponentType.socketOutlet,
      surface: wallB,
      position: const SurfacePointMm(1500, 1000),
      label: 'Extended target',
      ports: const [
        ElectricalPortDefinition(
          id: 'in',
          kind: ElectricalPortKind.powerIn,
        ),
      ],
    );
    const routeId = 'C-103';
    final penetration = BoundaryPenetration.normal(
      id: '$routeId:penetration:0',
      hostKind: BoundaryPenetrationHostKind.wall,
      entrySurface: wallA,
      entryPoint: const SurfacePointMm(700, 1000),
      exitSurface: wallB,
      exitPoint: const SurfacePointMm(200, 1000),
      hostThicknessMm: 180,
      routeId: routeId,
      materialId: 'brick',
    );
    final before = ElectricalCableRoute(
      id: routeId,
      source: const ElectricalEndpointRef(componentId: 'source', portId: 'out'),
      target:
          const ElectricalEndpointRef(componentId: 'target-a', portId: 'in'),
      segments: [
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
      ],
      penetrations: [penetration],
    );
    final after = ElectricalCableRoute(
      id: routeId,
      source: before.source,
      target:
          const ElectricalEndpointRef(componentId: 'target-b', portId: 'in'),
      segments: [
        before.segments.first,
        ElectricalRouteSegment(
          surface: wallB,
          points: const [
            SurfacePointMm(200, 1000),
            SurfacePointMm(1500, 1000),
          ],
        ),
      ],
      penetrations: [penetration],
    );
    final session = EditorP2Session(
      initialState: EditorP2State(
        components: [source, initialTarget, extendedTarget],
      ),
    );
    addTearDown(session.dispose);

    expect(session.commitPhysicalCableRoute(before), isTrue);
    final revisionBeforeReplace = session.history.mutationRevision;

    expect(
      session.replacePhysicalCableRoute(before: before, after: after),
      isTrue,
    );
    expect(session.history.mutationRevision, revisionBeforeReplace + 1);
    expect(session.routes, hasLength(1));
    expect(session.routes.single.id, routeId);
    expect(session.routes.single.target.componentId, 'target-b');
    expect(
      session.routes.single.penetrations.single.id,
      '$routeId:penetration:0',
    );

    session.undo();
    expect(session.routes.single.id, routeId);
    expect(session.routes.single.target.componentId, 'target-a');
    expect(
      session.routes.single.penetrations.single.id,
      '$routeId:penetration:0',
    );

    session.redo();
    expect(session.routes.single.id, routeId);
    expect(session.routes.single.target.componentId, 'target-b');
    expect(
      session.routes.single.penetrations.single.id,
      '$routeId:penetration:0',
    );
  });

  test('physical route replacement rejects identity drift before mutation', () {
    final surface = RoomSurfaceRef.wall('space-a', 0);
    final source = ElectricalComponentPlacement(
      id: 'source',
      type: ElectricalComponentType.powerSource,
      surface: surface,
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
      surface: surface,
      position: const SurfacePointMm(900, 1000),
      label: 'Target',
      ports: const [
        ElectricalPortDefinition(
          id: 'in',
          kind: ElectricalPortKind.powerIn,
        ),
      ],
    );
    final before = ElectricalCableRoute(
      id: 'C-103',
      source: const ElectricalEndpointRef(componentId: 'source', portId: 'out'),
      target: const ElectricalEndpointRef(componentId: 'target', portId: 'in'),
      segments: [
        ElectricalRouteSegment(
          surface: surface,
          points: const [
            SurfacePointMm(100, 1000),
            SurfacePointMm(900, 1000),
          ],
        ),
      ],
    );
    final wrongId = ElectricalCableRoute(
      id: 'C-104',
      source: before.source,
      target: before.target,
      segments: before.segments,
    );
    final session = EditorP2Session(
      initialState: EditorP2State(components: [source, target]),
    );
    addTearDown(session.dispose);
    expect(session.commitPhysicalCableRoute(before), isTrue);
    final revision = session.history.mutationRevision;

    expect(
      session.replacePhysicalCableRoute(before: before, after: wrongId),
      isFalse,
    );
    expect(session.history.mutationRevision, revision);
    expect(session.routes.single.id, 'C-103');
  });
}
