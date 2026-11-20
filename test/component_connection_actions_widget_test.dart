import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/features/editor/component_connection_actions.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:elecx/src/features/editor/port_driven_cable_authoring.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('selected device exposes actual host navigation', (tester) async {
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
    controller.p2.select(board.id);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ComponentConnectionActions(controller: controller),
        ),
      ),
    );
    expect(find.textContaining(board.label), findsOneWidget);
    expect(find.textContaining('500 × 1200 мм'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('component-open-host')));
    await tester.pump();
    expect(controller.activeSurface, board.surface);
    expect(controller.viewMode, EditorViewMode.surface);
    expect(controller.p2.selectedComponent?.id, board.id);
  });

  testWidgets('port click starts physical draft but never commits a cable',
      (tester) async {
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
    controller.p2.select(board.id);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ComponentConnectionActions(controller: controller),
        ),
      ),
    );
    await tester.tap(
      find.byKey(const ValueKey('component-connect-port-power-out')),
    );
    await tester.pump();
    expect(controller.tool, EditorTool.cableRoute);
    expect(controller.portDrivenCableStartBinding?.componentId, board.id);
    expect(controller.portDrivenCableStartBinding?.portId, 'power-out');
    expect(controller.routeSegments, hasLength(1));
    expect(controller.p2.routes, isEmpty);
  });

  testWidgets('without selection no action appears', (tester) async {
    final controller = EditorController.demo();
    addTearDown(() {
      controller.disposeP2State();
      controller.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ComponentConnectionActions(controller: controller),
        ),
      ),
    );
    expect(
      find.byKey(const ValueKey('component-connection-actions')),
      findsNothing,
    );
  });
}
