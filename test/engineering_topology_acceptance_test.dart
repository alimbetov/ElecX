import 'package:elecx/src/domain/component_catalog_v2.dart';
import 'package:elecx/src/domain/engineering_graph.dart';
import 'package:elecx/src/domain/engineering_topology.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/features/editor/catalog_component_placement.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('two different components connect through junction node to distribution board', () {
    final controller = EditorController.demo();
    addTearDown(controller.dispose);

    controller.showWall(0);
    final wall = controller.activeSurface!;
    final switchPlacement = controller.p2.placeCatalogComponent(
      entry: ComponentCatalogV2.require('lighting.switch.general'),
      surface: wall,
      position: const SurfacePointMm(900, 900),
    );
    final junctionPlacement = controller.p2.placeCatalogComponent(
      entry: ComponentCatalogV2.require('power.junction-box.general'),
      surface: wall,
      position: const SurfacePointMm(1800, 2400),
    );
    final boardPlacement = controller.p2.placeCatalogComponent(
      entry: ComponentCatalogV2.require('power.distribution-board.general'),
      surface: wall,
      position: const SurfacePointMm(350, 1500),
    );

    controller.showCeiling();
    final ceiling = controller.activeSurface!;
    final lightPlacement = controller.p2.placeCatalogComponent(
      entry: ComponentCatalogV2.require('lighting.luminaire.general'),
      surface: ceiling,
      position: const SurfacePointMm(2100, 1800),
    );

    final topology = EngineeringTopology(
      nodes: [
        EngineeringNodeFactory.fromPlacement(
          placement: boardPlacement,
          entry: ComponentCatalogV2.require('power.distribution-board.general'),
        ),
        EngineeringNodeFactory.fromPlacement(
          placement: junctionPlacement,
          entry: ComponentCatalogV2.require('power.junction-box.general'),
        ),
        EngineeringNodeFactory.fromPlacement(
          placement: switchPlacement,
          entry: ComponentCatalogV2.require('lighting.switch.general'),
        ),
        EngineeringNodeFactory.fromPlacement(
          placement: lightPlacement,
          entry: ComponentCatalogV2.require('lighting.luminaire.general'),
        ),
      ],
    );

    topology.connect(
      id: 'edge-board-junction',
      fromNodeId: boardPlacement.id,
      fromPortId: 'outgoing',
      toNodeId: junctionPlacement.id,
      toPortId: 'in',
      connectionType: EngineeringConnectionType.acSinglePhase,
      systemClass: EngineeringSystemClass.lighting,
      circuitId: 'lighting-01',
    );
    topology.connect(
      id: 'edge-junction-switch',
      fromNodeId: junctionPlacement.id,
      fromPortId: 'out',
      toNodeId: switchPlacement.id,
      toPortId: 'power-in',
      connectionType: EngineeringConnectionType.acSinglePhase,
      systemClass: EngineeringSystemClass.lighting,
      circuitId: 'lighting-01',
    );
    topology.connect(
      id: 'edge-switch-light',
      fromNodeId: switchPlacement.id,
      fromPortId: 'switched-out',
      toNodeId: lightPlacement.id,
      toPortId: 'power-in',
      connectionType: EngineeringConnectionType.acSinglePhase,
      systemClass: EngineeringSystemClass.lighting,
      circuitId: 'lighting-01',
    );

    expect(controller.p2.components, hasLength(4));
    expect(switchPlacement.componentTypeId, 'lighting.switch.general');
    expect(lightPlacement.componentTypeId, 'lighting.luminaire.general');
    expect(switchPlacement.surface.type, SurfacePlaneType.wall);
    expect(lightPlacement.surface.type, SurfacePlaneType.ceiling);
    expect(topology.edges, hasLength(3));
    expect(topology.hasPath(lightPlacement.id, boardPlacement.id), isTrue);
    expect(topology.hasPath(switchPlacement.id, boardPlacement.id), isTrue);
    expect(topology.edges.map((edge) => edge.circuitId).toSet(), {
      'lighting-01',
    });
  });

  test('topology rejects incompatible connection direction', () {
    final controller = EditorController.demo();
    addTearDown(controller.dispose);
    controller.showWall(0);
    final wall = controller.activeSurface!;

    final boardPlacement = controller.p2.placeCatalogComponent(
      entry: ComponentCatalogV2.require('power.distribution-board.general'),
      surface: wall,
      position: const SurfacePointMm(300, 1500),
    );
    final switchPlacement = controller.p2.placeCatalogComponent(
      entry: ComponentCatalogV2.require('lighting.switch.general'),
      surface: wall,
      position: const SurfacePointMm(1200, 900),
    );

    final topology = EngineeringTopology(
      nodes: [
        EngineeringNodeFactory.fromPlacement(
          placement: boardPlacement,
          entry: ComponentCatalogV2.require('power.distribution-board.general'),
        ),
        EngineeringNodeFactory.fromPlacement(
          placement: switchPlacement,
          entry: ComponentCatalogV2.require('lighting.switch.general'),
        ),
      ],
    );

    expect(
      () => topology.connect(
        id: 'invalid',
        fromNodeId: switchPlacement.id,
        fromPortId: 'power-in',
        toNodeId: boardPlacement.id,
        toPortId: 'incoming',
        connectionType: EngineeringConnectionType.acSinglePhase,
        systemClass: EngineeringSystemClass.lighting,
      ),
      throwsStateError,
    );
  });
}
