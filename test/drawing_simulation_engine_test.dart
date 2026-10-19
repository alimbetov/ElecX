import 'package:elecx/src/domain/component_catalog_v2.dart';
import 'package:elecx/src/domain/electrical_routing.dart';
import 'package:elecx/src/domain/engineering_graph.dart';
import 'package:elecx/src/domain/engineering_topology.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/engine/drawing_simulation_engine.dart';
import 'package:elecx/src/features/editor/catalog_component_placement.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('simulation finds route waste and missing path to board', () {
    final controller = EditorController.demo();
    addTearDown(controller.dispose);
    final space = controller.selectedSpace!;

    controller.showWall(0);
    final wall = controller.activeSurface!;
    final board = controller.p2.placeCatalogComponent(
      entry: ComponentCatalogV2.require('power.distribution-board.general'),
      surface: wall,
      position: const SurfacePointMm(300, 1500),
    );
    final switchPlacement = controller.p2.placeCatalogComponent(
      entry: ComponentCatalogV2.require('lighting.switch.general'),
      surface: wall,
      position: const SurfacePointMm(900, 900),
    );

    controller.showCeiling();
    final ceiling = controller.activeSurface!;
    final light = controller.p2.placeCatalogComponent(
      entry: ComponentCatalogV2.require('lighting.luminaire.general'),
      surface: ceiling,
      position: const SurfacePointMm(2100, 1800),
    );

    final topology = EngineeringTopology(nodes: [
      EngineeringNodeFactory.fromPlacement(
        placement: board,
        entry: ComponentCatalogV2.require('power.distribution-board.general'),
      ),
      EngineeringNodeFactory.fromPlacement(
        placement: switchPlacement,
        entry: ComponentCatalogV2.require('lighting.switch.general'),
      ),
      EngineeringNodeFactory.fromPlacement(
        placement: light,
        entry: ComponentCatalogV2.require('lighting.luminaire.general'),
      ),
    ]);
    topology.connect(
      id: 'board-switch',
      fromNodeId: board.id,
      fromPortId: 'outgoing',
      toNodeId: switchPlacement.id,
      toPortId: 'power-in',
      connectionType: EngineeringConnectionType.acSinglePhase,
      systemClass: EngineeringSystemClass.lighting,
      circuitId: 'lighting-01',
    );

    final badRoute = ElectricalCableRoute(
      id: 'route-switch-light',
      source: ElectricalEndpointRef(
        componentId: switchPlacement.id,
        portId: 'control-out',
      ),
      target: ElectricalEndpointRef(
        componentId: light.id,
        portId: 'power-in',
      ),
      segments: [
        ElectricalRouteSegment(
          surface: wall,
          points: const [
            SurfacePointMm(900, 900),
            SurfacePointMm(3900, 900),
            SurfacePointMm(3900, 2900),
            SurfacePointMm(900, 2900),
            SurfacePointMm(900, 3000),
          ],
        ),
        ElectricalRouteSegment(
          surface: ceiling,
          points: const [
            SurfacePointMm(900, 1800),
            SurfacePointMm(3900, 1800),
            SurfacePointMm(2100, 1800),
          ],
        ),
      ],
    );

    final result = DrawingSimulationEngine.run(
      DrawingSimulationRequest(
        space: space,
        components: controller.p2.components,
        routes: [badRoute],
        topology: topology,
        boardNodeId: board.id,
        routeImprovementThreshold: 0.05,
        maxBends: 2,
      ),
    );

    expect(
      result.defects.any(
        (item) => item.kind == DrawingDefectKind.routeInefficient,
      ),
      isTrue,
    );
    expect(
      result.defects.any(
        (item) => item.kind == DrawingDefectKind.routeExcessiveBends,
      ),
      isTrue,
    );
    expect(
      result.defects.any(
        (item) =>
            item.kind == DrawingDefectKind.topologyNoPathToBoard &&
            item.objectId == light.id,
      ),
      isTrue,
    );
    expect(result.routeCandidates, hasLength(1));
    expect(result.routeCandidates.single.savingMm, greaterThan(0));
    expect(result.score, lessThan(100));
  });

  test('simulation detects overlapping components on the same surface', () {
    final controller = EditorController.demo();
    addTearDown(controller.dispose);
    final space = controller.selectedSpace!;

    controller.showWall(0);
    final wall = controller.activeSurface!;
    controller.p2.placeCatalogComponent(
      entry: ComponentCatalogV2.require('lighting.switch.general'),
      surface: wall,
      position: const SurfacePointMm(1200, 900),
    );
    controller.p2.placeCatalogComponent(
      entry: ComponentCatalogV2.require('power.socket.general'),
      surface: wall,
      position: const SurfacePointMm(1200, 900),
    );

    final result = DrawingSimulationEngine.run(
      DrawingSimulationRequest(
        space: space,
        components: controller.p2.components,
        routes: const [],
      ),
    );

    expect(
      result.defects.any(
        (item) => item.kind == DrawingDefectKind.overlappingComponents,
      ),
      isTrue,
    );
  });
}
