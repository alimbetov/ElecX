import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/engine/editor_layers.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:elecx/src/features/editor/manual_cable_draft_persistence.dart';
import 'package:elecx/src/features/editor/port_driven_cable_authoring.dart';
import 'package:elecx/src/features/editor/spatial_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('real committed P2 cable appears on plan and respects layer',
      (tester) async {
    final controller = EditorController.demo();
    addTearDown(() {
      controller.disposeP2State();
      controller.dispose();
    });
    controller.showWall(0);
    final wall = RoomSurfaceRef.wall('room-101', 0);
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
    expect(controller.p2.routes, hasLength(1));
    controller.showPlan();

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 900,
          height: 700,
          child: SpatialCanvas(controller: controller),
        ),
      ),
    ));
    expect(
      find.byKey(const ValueKey('plan-p2-cable-overlay-status')),
      findsOneWidget,
    );
    expect(find.textContaining('P2 трассы (не P11)'), findsOneWidget);
    expect(tester.takeException(), isNull);

    controller.p2.setLayerVisible(EditorLayerId.cableRoutes, false);
    await tester.pump();
    expect(
      find.byKey(const ValueKey('plan-p2-cable-overlay-status')),
      findsNothing,
    );
    controller.p2.setLayerVisible(EditorLayerId.cableRoutes, true);
    await tester.pump();
    expect(
      find.byKey(const ValueKey('plan-p2-cable-overlay-status')),
      findsOneWidget,
    );
  });
}
