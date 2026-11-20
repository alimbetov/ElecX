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
    expect(find.textContaining('Комната 101 · Стена'), findsOneWidget);
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
  testWidgets(
    'inspector reacts to draft and completes only a compatible physical route',
    (tester) async {
      final controller = EditorController.demo();
      addTearDown(() {
        controller.disposeP2State();
        controller.dispose();
      });
      final surface = RoomSurfaceRef.wall('room-101', 0);
      final board = controller.p2.placeComponent(
        type: ElectricalComponentType.distributionBoard,
        surface: surface,
        position: const SurfacePointMm(500, 1200),
      );
      final socket = controller.p2.placeComponent(
        type: ElectricalComponentType.socketOutlet,
        surface: surface,
        position: const SurfacePointMm(2200, 1200),
      );
      controller.p2.select(board.id);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ComponentConnectionActions(controller: controller),
          ),
        ),
      );
      expect(
          find.byKey(const ValueKey('component-cable-source')), findsNothing);
      await tester.tap(
        find.byKey(const ValueKey('component-connect-port-power-out')),
      );
      await tester.pump();
      expect(
          find.byKey(const ValueKey('component-cable-source')), findsOneWidget);
      expect(
        find.byKey(ValueKey('component-complete-${socket.id}-power-in')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('component-finish-route')),
            )
            .onPressed,
        isNull,
      );
      expect(controller.p2.routes, isEmpty);
      await tester.tap(
        find.byKey(ValueKey('component-complete-${socket.id}-power-in')),
      );
      await tester.pump();
      expect(
          find.byKey(const ValueKey('component-cable-ready')), findsOneWidget);
      expect(controller.p2.routes, isEmpty);
      await tester.tap(find.byKey(const ValueKey('component-finish-route')));
      await tester.pump();
      expect(controller.p2.routes, hasLength(1));
      expect(controller.p2.routes.single.source.componentId, board.id);
      expect(controller.p2.routes.single.target.componentId, socket.id);
      expect(controller.portDrivenCableStartBinding, isNull);
      expect(controller.routeSegments, isEmpty);
      controller.p2.undo();
      expect(controller.p2.routes, isEmpty);
      controller.p2.redo();
      expect(controller.p2.routes, hasLength(1));
    },
  );

  testWidgets('active cable draft locks navigation and supports safe cancel',
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
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('component-open-host')),
          )
          .onPressed,
      isNull,
    );
    expect(
      find.byKey(const ValueKey('component-connect-port-power-out')),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('component-cancel-route')));
    await tester.pump();
    expect(controller.routeSegments, isEmpty);
    expect(controller.portDrivenCableStartBinding, isNull);
    expect(controller.p2.routes, isEmpty);
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('component-open-host')),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('foreign-room endpoint remains blocked without a passage',
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
    final remote = controller.p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: RoomSurfaceRef.wall('corridor-1', 0),
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
    expect(
      find.byKey(const ValueKey('component-cross-room-blocked')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey('component-complete-${remote.id}-power-in')),
      findsNothing,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('component-finish-route')),
          )
          .onPressed,
      isNull,
    );
    expect(controller.p2.routes, isEmpty);
  });
  testWidgets('stale endpoint after load edit cannot be silently committed',
      (tester) async {
    final controller = EditorController.demo();
    addTearDown(() {
      controller.disposeP2State();
      controller.dispose();
    });
    final wall = RoomSurfaceRef.wall('room-101', 0);
    final board = controller.p2.placeComponent(
      type: ElectricalComponentType.distributionBoard,
      surface: wall,
      position: const SurfacePointMm(500, 1200),
    );
    final load = controller.p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: wall,
      position: const SurfacePointMm(2200, 1200),
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
    await tester.tap(
      find.byKey(ValueKey('component-complete-${load.id}-power-in')),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('component-cable-ready')), findsOneWidget);
    controller.p2.updateLoadElectricalData(
      componentId: load.id,
      ratedPowerW: 500,
      voltageV: 230,
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('component-cable-ready')), findsNothing);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('component-finish-route')),
          )
          .onPressed,
      isNull,
    );
    expect(controller.p2.routes, isEmpty);
  });
}
