import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/engine/editor_layers.dart';
import 'package:elecx/src/features/editor/component_transform_session.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:elecx/src/features/editor/manual_cable_draft_persistence.dart';
import 'package:elecx/src/features/editor/port_driven_cable_authoring.dart';
import 'package:elecx/src/features/editor/spatial_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('plan drag moves wall device and its connected route atomically',
      (tester) async {
    final controller = EditorController.demo();
    addTearDown(() {
      controller.disposeP2State();
      controller.dispose();
    });
    controller.showWall(0);
    final wall = RoomSurfaceRef.wall('room-101', 1);
    final board = controller.p2.placeComponent(
      type: ElectricalComponentType.distributionBoard,
      surface: wall,
      position: const SurfacePointMm(500, 1200),
    );
    final socket = controller.p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: wall,
      position: const SurfacePointMm(2200, 1200),
    );
    controller.p2.select(board.id);
    expect(
        controller.beginPortDrivenCableFromSelectedPort('power-out'), isTrue);
    controller.surfaceTap(socket.position);
    expect(
      controller.snapPortDrivenCableCompletionTarget(
        componentId: socket.id,
        portId: 'power-in',
      ),
      isTrue,
    );
    expect(controller.finishManualCableDraft(), isTrue);
    final routeId = controller.p2.routes.single.id;
    controller.p2.select(socket.id);
    // Move the socket on an opening-free physical wall: the demo's first wall
    // contains a door, so moving the board into it would correctly be rejected.
    expect(controller.p2.beginMoveSelectedComponent(), isTrue);
    expect(
      controller.p2.previewMoveSelectedComponent(
        const SurfacePointMm(2500, 1200),
      ),
      isTrue,
    );
    controller.p2.cancelMoveSelectedComponent();
    final before =
        controller.p2.components.firstWhere((item) => item.id == socket.id);
    controller.setTool(EditorTool.select);
    controller.showPlan();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 900,
            height: 700,
            child: SpatialCanvas(controller: controller),
          ),
        ),
      ),
    );
    await tester.drag(
      find.byKey(ValueKey('plan-component-${socket.id}')),
      const Offset(0, -40),
    );
    await tester.pump();
    final after =
        controller.p2.components.firstWhere((item) => item.id == socket.id);
    expect(after.id, before.id);
    expect(after.surface, before.surface);
    expect(after.position.xMm, greaterThan(before.position.xMm));
    expect(after.position.yMm, before.position.yMm);
    expect(controller.p2.routes.single.id, routeId);
    expect(controller.p2.routes.single.source.componentId, board.id);
    expect(controller.p2.routes.single.target.componentId, socket.id);
    expect(controller.componentTransform.active, isFalse);

    controller.p2.undo();
    expect(
      controller.p2.components
          .firstWhere((item) => item.id == socket.id)
          .position,
      before.position,
    );
    expect(controller.p2.routes.single.id, routeId);
    controller.p2.redo();
    expect(
      controller.p2.components
          .firstWhere((item) => item.id == socket.id)
          .position,
      after.position,
    );
  });

  testWidgets('drag away from host wall fails closed and restores placement',
      (tester) async {
    final controller = EditorController.demo();
    addTearDown(() {
      controller.disposeP2State();
      controller.dispose();
    });
    controller.showWall(0);
    final board = controller.p2.placeComponent(
      type: ElectricalComponentType.distributionBoard,
      surface: RoomSurfaceRef.wall('room-101', 0),
      position: const SurfacePointMm(500, 1200),
    );
    controller.showPlan();
    final undoDepth = controller.p2.history.undoDepth;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 900,
            height: 700,
            child: SpatialCanvas(controller: controller),
          ),
        ),
      ),
    );
    await tester.drag(
      find.byKey(ValueKey('plan-component-${board.id}')),
      const Offset(0, -110),
    );
    await tester.pump();
    expect(controller.p2.components.single.position, board.position);
    expect(controller.p2.routes, isEmpty);
    expect(controller.p2.history.undoDepth, undoDepth);
    expect(controller.componentTransform.active, isFalse);
  });

  testWidgets('electrical layer lock prevents plan drag', (tester) async {
    final controller = EditorController.demo();
    addTearDown(() {
      controller.disposeP2State();
      controller.dispose();
    });
    controller.showWall(0);
    final board = controller.p2.placeComponent(
      type: ElectricalComponentType.distributionBoard,
      surface: RoomSurfaceRef.wall('room-101', 0),
      position: const SurfacePointMm(500, 1200),
    );
    controller.showPlan();
    controller.p2.setLayerLocked(EditorLayerId.electrical, true);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 900,
            height: 700,
            child: SpatialCanvas(controller: controller),
          ),
        ),
      ),
    );
    await tester.drag(
      find.byKey(ValueKey('plan-component-${board.id}')),
      const Offset(55, 0),
    );
    await tester.pump();
    expect(controller.p2.components.single.position, board.position);
    expect(controller.componentTransform.active, isFalse);
  });
}
