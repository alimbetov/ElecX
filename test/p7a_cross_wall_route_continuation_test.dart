import 'package:elecx/src/domain/boundary_penetration.dart';
import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/electrical_routing.dart';
import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/project_model.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:elecx/src/features/editor/physical_cable_route_committer.dart';
import 'package:elecx/src/features/editor/physical_manual_cable_draft_persistence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('continuing across-wall route does not duplicate existing penetration',
      () {
    final roomABoundary = MmPolygon.rectangle(
      const MmPoint(0, 0),
      const MmPoint(4000, 3000),
    );
    final roomBBoundary = MmPolygon.rectangle(
      const MmPoint(4000, 0),
      const MmPoint(8000, 3000),
    );
    final roomA = EngineeringSpace(
      id: 'room-a',
      name: 'Room A',
      type: SpaceType.room,
      boundary: roomABoundary,
      referenceFrame: RoomReferenceFrame(origin: roomABoundary.bounds.center),
    );
    final roomB = EngineeringSpace(
      id: 'room-b',
      name: 'Room B',
      type: SpaceType.room,
      boundary: roomBBoundary,
      referenceFrame: RoomReferenceFrame(origin: roomBBoundary.bounds.center),
    );
    final wallA = RoomSurfaceRef.wall(roomA.id, 1);
    final wallB = RoomSurfaceRef.wall(roomB.id, 3);
    final controller = EditorController.restored(
      level: BuildingLevel(
        id: 'level-1',
        name: 'Level 1',
        elevationMm: 0,
        spaces: [roomA, roomB],
      ),
      openings: const [],
    )..selectSpace(roomA.id);
    addTearDown(controller.dispose);

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
    final targetA = ElectricalComponentPlacement(
      id: 'target-a',
      type: ElectricalComponentType.socketOutlet,
      surface: wallB,
      position: const SurfacePointMm(900, 1000),
      label: 'Target A',
      ports: const [
        ElectricalPortDefinition(
          id: 'in',
          kind: ElectricalPortKind.powerIn,
        ),
      ],
    );
    final targetB = ElectricalComponentPlacement(
      id: 'target-b',
      type: ElectricalComponentType.socketOutlet,
      surface: wallB,
      position: const SurfacePointMm(1500, 1000),
      label: 'Target B',
      ports: const [
        ElectricalPortDefinition(
          id: 'in',
          kind: ElectricalPortKind.powerIn,
        ),
      ],
    );
    controller.p2.history.replaceState(
      EditorP2State(components: [source, targetA, targetB]),
      clearHistory: true,
    );

    final penetration = BoundaryPenetration.normal(
      id: 'C-103:penetration:0',
      hostKind: BoundaryPenetrationHostKind.wall,
      entrySurface: wallA,
      entryPoint: const SurfacePointMm(700, 1000),
      exitSurface: wallB,
      exitPoint: const SurfacePointMm(200, 1000),
      hostThicknessMm: 180,
      routeId: 'C-103',
      materialId: 'brick',
    );
    final original = ElectricalCableRoute(
      id: 'C-103',
      source: const ElectricalEndpointRef(
        componentId: 'source',
        portId: 'out',
      ),
      target: const ElectricalEndpointRef(
        componentId: 'target-a',
        portId: 'in',
      ),
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
    expect(controller.p2.commitPhysicalCableRoute(original), isTrue);
    final revision = controller.p2.history.mutationRevision;

    expect(controller.beginPhysicalRouteContinuation('C-103'), isTrue);
    expect(controller.selectedSpaceId, roomB.id);
    expect(controller.activeSurface?.wallIndex, 3);
    controller.surfaceTap(const SurfacePointMm(1200, 1000));
    controller.surfaceTap(const SurfacePointMm(1500, 1000));

    expect(
      controller.finishPhysicalRouteContinuation(
        resolveTransition: (_, __, ___, ____) => null,
      ),
      isTrue,
    );
    expect(controller.p2.history.mutationRevision, revision + 1);
    expect(controller.p2.routes, hasLength(1));
    final continued = controller.p2.routes.single;
    expect(continued.id, 'C-103');
    expect(continued.target.componentId, 'target-b');
    expect(continued.penetrations, hasLength(1));
    expect(continued.penetrations.single.id, 'C-103:penetration:0');
    expect(continued.hiddenPenetrationLengthMm, 180);

    controller.p2.undo();
    expect(controller.p2.routes.single.id, 'C-103');
    expect(controller.p2.routes.single.target.componentId, 'target-a');
    expect(controller.p2.routes.single.penetrations, hasLength(1));
    expect(
      controller.p2.routes.single.penetrations.single.id,
      'C-103:penetration:0',
    );
  });
}
