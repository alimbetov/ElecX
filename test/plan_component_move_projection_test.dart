import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/plan_component_move_projection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final controller = EditorController.demo();
  addTearDown(controller.dispose);

  test('wall plan movement changes only longitudinal offset, not mounting height',
      () {
    final space = controller.level.spaces.first;
    final component = ElectricalComponentPlacement(
      id: 'socket',
      type: ElectricalComponentType.socketOutlet,
      surface: RoomSurfaceRef.wall(space.id, 0),
      position: const SurfacePointMm(500, 1100),
      label: 'Socket',
    );
    expect(
      PlanComponentMoveProjection.fromPlan(
        space: space,
        component: component,
        planPoint: const MmPoint(2300, 1200),
      ),
      const SurfacePointMm(1300, 1100),
    );
    expect(
      PlanComponentMoveProjection.fromPlan(
        space: space,
        component: component,
        planPoint: const MmPoint(2300, 2000),
      ),
      isNull,
    );
    expect(
      PlanComponentMoveProjection.fromPlan(
        space: space,
        component: component,
        planPoint: const MmPoint(9500, 1200),
      ),
      isNull,
    );
  });

  test('ceiling movement changes local XY only within the same room', () {
    final space = controller.level.spaces.first;
    final component = ElectricalComponentPlacement(
      id: 'light',
      type: ElectricalComponentType.lightingPoint,
      surface: RoomSurfaceRef.ceiling(space.id),
      position: const SurfacePointMm(1000, 900),
      label: 'Light',
    );
    expect(
      PlanComponentMoveProjection.fromPlan(
        space: space,
        component: component,
        planPoint: const MmPoint(3300, 2600),
      ),
      const SurfacePointMm(2300, 1400),
    );
    expect(
      PlanComponentMoveProjection.fromPlan(
        space: space,
        component: component,
        planPoint: const MmPoint(9000, 2600),
      ),
      isNull,
    );
  });

  test('missing or stale canonical boundary identity blocks plan movement',
      () {
    final space = controller.level.spaces.first;
    final ids = [
      for (var i = 0; i < space.boundary.vertices.length; i++)
        BoundaryEdgeId('stable-$i'),
    ];
    final component = ElectricalComponentPlacement(
      id: 'canonical-socket',
      type: ElectricalComponentType.socketOutlet,
      surface: RoomSurfaceRef.wallByBoundaryEdge(space.id, ids[0]),
      position: const SurfacePointMm(500, 1100),
      label: 'Canonical Socket',
    );
    expect(
      PlanComponentMoveProjection.fromPlan(
        space: space,
        component: component,
        planPoint: const MmPoint(2400, 1200),
      ),
      isNull,
    );
    expect(
      PlanComponentMoveProjection.fromPlan(
        space: space,
        component: component,
        planPoint: const MmPoint(2400, 1200),
        orderedEdgeIds: ids,
      ),
      const SurfacePointMm(1400, 1100),
    );
    expect(
      PlanComponentMoveProjection.fromPlan(
        space: space,
        component: component,
        planPoint: const MmPoint(2400, 1200),
        orderedEdgeIds: [ids[0], ids[0], ...ids.skip(2)],
      ),
      isNull,
    );
  });

  test('pixel delta maps screen-down to negative plan Y', () {
    expect(
      PlanComponentMoveProjection.draggedPlanPoint(
        initialPoint: const MmPoint(1500, 2000),
        dxPx: 20,
        dyPx: 10,
        mmPerPixel: 12,
      ),
      const MmPoint(1740, 1880),
    );
  });
}
