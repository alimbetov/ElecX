import 'package:elecx/src/domain/component_catalog_v2.dart';
import 'package:elecx/src/domain/electrical_routing.dart';
import 'package:elecx/src/domain/engineering_graph.dart';
import 'package:elecx/src/domain/engineering_topology.dart';
import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/engine/drawing_simulation_engine.dart';
import 'package:elecx/src/engine/engineering_analysis_profile.dart';
import 'package:elecx/src/engine/routing_constraints.dart';
import 'package:elecx/src/features/editor/catalog_component_placement.dart';
import 'package:elecx/src/features/editor/component_catalog_session.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('simulation finds route waste and missing directed path to board', () {
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
        profile: const EngineeringAnalysisProfile(
          routeImprovementThreshold: 0.05,
          maxRouteBends: 2,
        ),
        catalogResolver: controller.componentCatalog.byId,
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

  test('simulation detects overlapping and clearance violations', () {
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
    controller.p2.placeCatalogComponent(
      entry: ComponentCatalogV2.require('power.socket.general'),
      surface: wall,
      position: const SurfacePointMm(1250, 900),
    );

    final result = DrawingSimulationEngine.run(
      DrawingSimulationRequest(
        space: space,
        components: controller.p2.components,
        routes: const [],
        profile: const EngineeringAnalysisProfile(componentClearanceMm: 100),
      ),
    );

    expect(
      result.defects.any(
        (item) => item.kind == DrawingDefectKind.overlappingComponents,
      ),
      isTrue,
    );
    expect(
      result.defects.any(
        (item) => item.kind == DrawingDefectKind.componentClearanceViolation,
      ),
      isTrue,
    );
  });

  test('simulation detects route crossing a keep-out zone', () {
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
    final socket = controller.p2.placeCatalogComponent(
      entry: ComponentCatalogV2.require('power.socket.general'),
      surface: wall,
      position: const SurfacePointMm(3000, 300),
    );

    final route = ElectricalCableRoute(
      id: 'route-through-door-zone',
      source: ElectricalEndpointRef(
        componentId: board.id,
        portId: 'power-out',
      ),
      target: ElectricalEndpointRef(
        componentId: socket.id,
        portId: 'power-in',
      ),
      segments: [
        ElectricalRouteSegment(
          surface: wall,
          points: const [
            SurfacePointMm(300, 1500),
            SurfacePointMm(3000, 1500),
            SurfacePointMm(3000, 300),
          ],
        ),
      ],
    );

    final result = DrawingSimulationEngine.run(
      DrawingSimulationRequest(
        space: space,
        components: controller.p2.components,
        routes: [route],
        keepOutZones: [
          SurfaceKeepOutZone(
            id: 'door-clearance',
            surface: wall,
            bounds: const MmBounds(
              left: 1200,
              bottom: 0,
              right: 2200,
              top: 2200,
            ),
            reason: 'door opening/service clearance',
          ),
        ],
      ),
    );

    expect(
      result.defects.any(
        (item) => item.kind == DrawingDefectKind.routeKeepOutViolation,
      ),
      isTrue,
    );
  });

  test('simulation detects connected topology with wrong flow direction', () {
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
    final source = controller.p2.placeCatalogComponent(
      entry: ComponentCatalogV2.require('power.source.general'),
      surface: wall,
      position: const SurfacePointMm(1000, 1500),
    );

    final topology = EngineeringTopology(nodes: [
      EngineeringNodeFactory.fromPlacement(
        placement: board,
        entry: ComponentCatalogV2.require('power.distribution-board.general'),
      ),
      EngineeringNodeFactory.fromPlacement(
        placement: source,
        entry: ComponentCatalogV2.require('power.source.general'),
      ),
    ]);
    topology.connect(
      id: 'source-to-board',
      fromNodeId: source.id,
      fromPortId: 'power-out',
      toNodeId: board.id,
      toPortId: 'incoming',
      connectionType: EngineeringConnectionType.acSinglePhase,
      systemClass: EngineeringSystemClass.powerAc,
    );

    final result = DrawingSimulationEngine.run(
      DrawingSimulationRequest(
        space: space,
        components: controller.p2.components,
        routes: const [],
        topology: topology,
        boardNodeId: board.id,
      ),
    );

    expect(topology.hasPath(board.id, source.id), isTrue);
    expect(topology.hasDirectedPath(board.id, source.id), isFalse);
    expect(
      result.defects.any(
        (item) => item.kind == DrawingDefectKind.topologyWrongFlowDirection,
      ),
      isTrue,
    );
  });
}
