import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/features/editor/component_connection_actions.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:elecx/src/features/editor/plan_port_pair_session.dart';
import 'package:elecx/src/features/editor/spatial_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('click source port, click device on plan, preview and apply',
      (tester) async {
    final controller = EditorController.demo();
    addTearDown(() {
      controller.disposeP2State();
      controller.dispose();
    });
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
    controller.showPlan();
    controller.p2.select(board.id);

    await tester.binding.setSurfaceSize(const Size(1400, 860));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              Expanded(child: SpatialCanvas(controller: controller)),
              SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: ComponentConnectionActions(controller: controller),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('plan-port-start-power-out')));
    await tester.pump();
    expect(controller.planPortPair.choosingTarget, isTrue);
    expect(controller.p2.routes, isEmpty);
    expect(controller.viewMode, EditorViewMode.plan);
    await tester.tap(find.byKey(ValueKey('plan-component-${socket.id}')));
    await tester.pump();
    expect(controller.planPortPair.ready, isTrue);
    expect(controller.p2.routes, isEmpty);
    expect(
        find.byKey(const ValueKey('plan-port-pair-overlay')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('plan-port-apply-on-plan')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('plan-port-apply-on-plan')));
    await tester.pump();
    expect(controller.p2.routes, hasLength(1));
    expect(controller.p2.routes.single.source.componentId, board.id);
    expect(controller.p2.routes.single.target.componentId, socket.id);
    expect(controller.viewMode, EditorViewMode.plan);
    expect(controller.planPortPair.active, isFalse);
    expect(
      find.byKey(const ValueKey('plan-port-pair-overlay')),
      findsNothing,
    );
    controller.p2.undo();
    expect(controller.p2.routes, isEmpty);
    controller.p2.redo();
    expect(controller.p2.routes, hasLength(1));
  });

  testWidgets('foreign room tap cannot create a fake straight plan route',
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
      position: const SurfacePointMm(1100, 1200),
    );
    controller.showPlan();
    controller.p2.select(board.id);
    await tester.binding.setSurfaceSize(const Size(1400, 860));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              Expanded(child: SpatialCanvas(controller: controller)),
              SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: ComponentConnectionActions(controller: controller),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('plan-port-start-power-out')));
    await tester.pump();
    expect(controller.planPortPair.choosingTarget, isTrue);
    await tester.tap(find.byKey(ValueKey('plan-component-${remote.id}')));
    await tester.pump();
    expect(controller.planPortPair.ready, isFalse);
    expect(controller.p2.routes, isEmpty);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('plan-port-apply-on-plan')),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const ValueKey('plan-port-cancel-on-plan')));
    await tester.pump();
    expect(controller.planPortPair.active, isFalse);
    expect(controller.p2.routes, isEmpty);
  });
  testWidgets('door crossing disables plan Apply and explains obstruction',
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
    final socket = controller.p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: wall,
      position: const SurfacePointMm(2200, 1200),
    );
    controller.showPlan();
    controller.p2.select(board.id);
    expect(
      controller.planPortPair.start(
        componentId: board.id,
        portId: 'power-out',
      ),
      isTrue,
    );
    expect(
      controller.planPortPair.chooseTarget(
        componentId: socket.id,
        portId: 'power-in',
      ),
      isTrue,
    );
    await tester.binding.setSurfaceSize(const Size(1400, 860));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              Expanded(child: SpatialCanvas(controller: controller)),
              SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: ComponentConnectionActions(controller: controller),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    expect(
      find.byKey(const ValueKey('plan-port-physical-blocked')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('plan-port-geometry-blocked')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('plan-port-apply-on-plan')),
          )
          .onPressed,
      isNull,
    );
    expect(controller.p2.routes, isEmpty);
  });

}
