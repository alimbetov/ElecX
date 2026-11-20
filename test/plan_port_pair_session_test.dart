import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:elecx/src/features/editor/plan_port_pair_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('two explicit ports create no route before apply and preserve Undo/Redo',
      () {
    final controller = EditorController.demo();
    addTearDown(() {
      controller.disposeP2State();
      controller.dispose();
    });
    final host = RoomSurfaceRef.wall('room-101', 0);
    final board = controller.p2.placeComponent(
      type: ElectricalComponentType.distributionBoard,
      surface: host,
      position: const SurfacePointMm(500, 1200),
    );
    final socket = controller.p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: host,
      position: const SurfacePointMm(2200, 1200),
    );
    controller.showPlan();
    final pair = controller.planPortPair;
    final revision = controller.p2.history.mutationRevision;
    expect(pair.start(componentId: board.id, portId: 'power-out'), isTrue);
    expect(controller.viewMode, EditorViewMode.plan);
    expect(controller.p2.history.mutationRevision, revision);
    expect(controller.p2.routes, isEmpty);
    expect(
      pair.compatiblePortsFor(socket).map((port) => port.id),
      contains('power-in'),
    );
    expect(
      pair.chooseTarget(componentId: socket.id, portId: 'power-in'),
      isTrue,
    );
    expect(pair.ready, isTrue);
    expect(pair.straightLengthMm, 1700);
    expect(controller.p2.routes, isEmpty);

    expect(pair.applyStraightRoute(), isTrue);
    expect(pair.active, isFalse);
    expect(controller.viewMode, EditorViewMode.plan);
    expect(controller.tool, EditorTool.select);
    expect(controller.p2.routes, hasLength(1));
    final route = controller.p2.routes.single;
    expect(route.source.componentId, board.id);
    expect(route.source.portId, 'power-out');
    expect(route.target.componentId, socket.id);
    expect(route.target.portId, 'power-in');
    expect(controller.p2.history.mutationRevision, revision + 1);
    controller.p2.undo();
    expect(controller.p2.routes, isEmpty);
    controller.p2.redo();
    expect(controller.p2.routes.single.id, route.id);
  });

  test('cross-room targets require verified physical routing', () {
    final controller = EditorController.demo();
    addTearDown(() {
      controller.disposeP2State();
      controller.dispose();
    });
    final board = controller.p2.placeComponent(
      type: ElectricalComponentType.distributionBoard,
      surface: RoomSurfaceRef.wall('room-101', 0),
      position: const SurfacePointMm(500, 1200),
    );
    final remote = controller.p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: RoomSurfaceRef.wall('corridor-1', 0),
      position: const SurfacePointMm(500, 1200),
    );
    controller.showPlan();
    final pair = controller.planPortPair;
    expect(pair.start(componentId: board.id, portId: 'power-out'), isTrue);
    expect(pair.compatiblePortsFor(remote), isEmpty);
    expect(
      pair.chooseTarget(componentId: remote.id, portId: 'power-in'),
      isFalse,
    );
    expect(pair.ready, isFalse);
    expect(pair.applyStraightRoute(), isFalse);
    expect(controller.p2.routes, isEmpty);
  });

  test('mutated load invalidates proposal and cannot commit', () {
    final controller = EditorController.demo();
    addTearDown(() {
      controller.disposeP2State();
      controller.dispose();
    });
    final host = RoomSurfaceRef.wall('room-101', 0);
    final board = controller.p2.placeComponent(
      type: ElectricalComponentType.distributionBoard,
      surface: host,
      position: const SurfacePointMm(500, 1200),
    );
    final socket = controller.p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: host,
      position: const SurfacePointMm(2200, 1200),
    );
    controller.showPlan();
    final pair = controller.planPortPair;
    expect(pair.start(componentId: board.id, portId: 'power-out'), isTrue);
    expect(
      pair.chooseTarget(componentId: socket.id, portId: 'power-in'),
      isTrue,
    );
    controller.p2.updateLoadElectricalData(
      componentId: socket.id,
      ratedPowerW: 500,
      voltageV: 230,
    );
    expect(pair.revisionCurrent, isFalse);
    expect(pair.ready, isFalse);
    expect(pair.applyStraightRoute(), isFalse);
    expect(controller.p2.routes, isEmpty);
    pair.reset();
    expect(pair.active, isFalse);
  });
}
