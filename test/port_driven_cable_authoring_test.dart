import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/features/editor/cable_authoring_draft_bar.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:elecx/src/features/editor/engineering_selection_inspector.dart';
import 'package:elecx/src/features/editor/manual_cable_draft_persistence.dart';
import 'package:elecx/src/features/editor/port_driven_cable_authoring.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P12A.1 port-driven cable start', () {
    test('output port creates an exact physical first draft point', () {
      final controller = EditorController.demo();
      addTearDown(() {
        controller.disposeP2State();
        controller.dispose();
      });
      controller.showWall(0);
      final board = controller.p2.placeComponent(
        type: ElectricalComponentType.distributionBoard,
        surface: RoomSurfaceRef.wall('room-101', 0),
        position: const SurfacePointMm(700, 1200),
      );

      expect(
        controller.beginPortDrivenCableFromSelectedPort('power-out'),
        isTrue,
      );

      final binding = controller.portDrivenCableStartBinding;
      expect(binding, isNotNull);
      expect(binding!.componentId, board.id);
      expect(binding.portId, 'power-out');
      expect(binding.role, PortDrivenCableEndpointRole.source);
      expect(controller.tool, EditorTool.cableRoute);
      expect(controller.routeSegments, hasLength(1));
      expect(controller.routeSegments.single.surface, board.surface);
      expect(controller.routeSegments.single.points, [board.position]);
    });

    test('starting at socket input persists electrically directed route', () {
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

      expect(
        controller.beginPortDrivenCableFromSelectedPort('power-in'),
        isTrue,
      );
      expect(
        controller.portDrivenCableStartBinding?.role,
        PortDrivenCableEndpointRole.target,
      );

      controller.surfaceTap(board.position);
      expect(controller.routeSegments.single.points.first, socket.position);
      expect(controller.routeSegments.single.points.last, board.position);

      expect(
        controller.snapPortDrivenCableCompletionTarget(
          componentId: board.id,
          portId: 'power-out',
        ),
        isTrue,
      );
      expect(controller.portDrivenCableReadyToFinish, isTrue);
      expect(
        controller.finishManualCableDraft(endpointSnapRadiusMm: 40),
        isTrue,
      );
      expect(controller.portDrivenCableStartBinding, isNull);
      expect(controller.portDrivenCableCompletionBinding, isNull);
      expect(controller.routeSegments, isEmpty);
      expect(controller.p2.routes, hasLength(1));

      final route = controller.p2.routes.single;
      expect(route.source.componentId, board.id);
      expect(route.source.portId, 'power-out');
      expect(route.target.componentId, socket.id);
      expect(route.target.portId, 'power-in');
      expect(route.segments.single.points.first, board.position);
      expect(route.segments.single.points.last, socket.position);
    });

    test('stale source binding fails closed and preserves the draft', () {
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
      expect(
        controller.beginPortDrivenCableFromSelectedPort('power-out'),
        isTrue,
      );
      controller.surfaceTap(const SurfacePointMm(1200, 1200));

      controller.p2.placeComponent(
        type: ElectricalComponentType.socketOutlet,
        surface: wall,
        position: const SurfacePointMm(1200, 1200),
      );

      expect(controller.finishManualCableDraft(), isFalse);
      expect(controller.p2.routes, isEmpty);
      expect(controller.routeSegments, isNotEmpty);
      expect(controller.routeSegments.first.points.first, board.position);
      expect(controller.portDrivenCableStartBinding, isNotNull);
    });

    testWidgets(
        'selected socket exposes its physical input port in authoring UI',
        (tester) async {
      final controller = EditorController.demo();
      addTearDown(() {
        controller.disposeP2State();
        controller.dispose();
      });
      controller.showWall(0);
      final socket = controller.p2.placeComponent(
        type: ElectricalComponentType.socketOutlet,
        surface: RoomSurfaceRef.wall('room-101', 0),
        position: const SurfacePointMm(1500, 1200),
      );
      controller.setTool(EditorTool.cableRoute);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: controller,
              builder: (context, _) => CableAuthoringDraftBar(
                controller: controller,
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const ValueKey('cable-start-port-power-in')), findsOne);
      expect(
          find.byKey(const ValueKey('cable-start-port-earth')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('cable-start-port-power-in')));
      await tester.pump();

      expect(controller.routeSegments, hasLength(1));
      expect(controller.routeSegments.single.points, [socket.position]);
      expect(find.byKey(const ValueKey('cable-port-start-bound')), findsOne);
    });

    testWidgets(
        'component inspector starts cable authoring without preselecting C tool',
        (tester) async {
      final controller = EditorController.demo();
      addTearDown(() {
        controller.disposeP2State();
        controller.dispose();
      });
      controller.showWall(0);
      final socket = controller.p2.placeComponent(
        type: ElectricalComponentType.socketOutlet,
        surface: RoomSurfaceRef.wall('room-101', 0),
        position: const SurfacePointMm(1500, 1200),
      );

      expect(controller.tool, isNot(EditorTool.cableRoute));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              child: EngineeringSelectionInspector(controller: controller),
            ),
          ),
        ),
      );

      final startButton = find.byKey(const ValueKey('component-route-cable'));
      expect(startButton, findsOne);
      expect(find.text('Проложить кабель'), findsOne);

      await tester.tap(startButton);
      await tester.pump();

      expect(controller.tool, EditorTool.cableRoute);
      expect(controller.portDrivenCableStartBinding?.componentId, socket.id);
      expect(controller.portDrivenCableStartBinding?.portId, 'power-in');
      expect(controller.routeSegments, hasLength(1));
      expect(controller.routeSegments.single.points, [socket.position]);
    });
  });

  group('Multi-room routing discovery — non-authorizing', () {
    test('remote-room compatible loads are identified but cannot be snapped',
        () {
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
      final remote = controller.p2.placeComponent(
        type: ElectricalComponentType.socketOutlet,
        surface: RoomSurfaceRef.wall('room-102', 0),
        position: const SurfacePointMm(900, 1200),
      );
      controller.p2.select(board.id);
      expect(
          controller.beginPortDrivenCableFromSelectedPort('power-out'), isTrue);
      final remoteTargets = controller.blockedCrossRoomCableTargets;
      expect(remoteTargets, hasLength(1));
      expect(remoteTargets.single.componentId, remote.id);
      expect(remoteTargets.single.surface.spaceId, 'room-102');
      expect(controller.compatiblePortDrivenCableTargets, isEmpty);
      expect(
        controller.snapPortDrivenCableCompletionTarget(
          componentId: remote.id,
          portId: 'power-in',
        ),
        isFalse,
      );
      expect(controller.p2.routes, isEmpty);
      expect(controller.routeSegments, hasLength(1));
    });

    testWidgets('remote-room targets show a passage prerequisite, not a button',
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
      controller.p2.placeComponent(
        type: ElectricalComponentType.socketOutlet,
        surface: RoomSurfaceRef.wall('room-102', 0),
        position: const SurfacePointMm(900, 1200),
      );
      controller.p2.select(board.id);
      expect(controller.beginPortDrivenCableFromSelectedPort('power-out'),
          isTrue);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 520,
                child: CableAuthoringDraftBar(controller: controller),
              ),
            ),
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey('cable-cross-room-targets-blocked')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('cable-cross-room-passage-required')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('cable-completion-target-'
              'component-2-socket-outlet-power-in'),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('P12A.2 guided cable completion', () {
    test('compatible completion targets expose only electrically valid ports',
        () {
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
      final switchControl = controller.p2.placeComponent(
        type: ElectricalComponentType.switchControl,
        surface: wall,
        position: const SurfacePointMm(3000, 1200),
      );
      controller.p2.select(board.id);

      expect(
        controller.beginPortDrivenCableFromSelectedPort('power-out'),
        isTrue,
      );

      final targets = controller.compatiblePortDrivenCableTargets;
      expect(
        targets.any(
          (target) =>
              target.componentId == socket.id && target.portId == 'power-in',
        ),
        isTrue,
      );
      expect(
        targets.any(
          (target) =>
              target.componentId == switchControl.id &&
              target.portId == 'power-in',
        ),
        isTrue,
      );
      expect(targets.any((target) => target.portId == 'control-out'), isFalse);
      expect(targets.any((target) => target.portId == 'earth'), isFalse);
      expect(
        targets.every(
          (target) => target.role == PortDrivenCableEndpointRole.target,
        ),
        isTrue,
      );
    });

    test('semantic target snap binds exact port and enters ready state', () {
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
        controller.beginPortDrivenCableFromSelectedPort('power-out'),
        isTrue,
      );
      controller.surfaceTap(const SurfacePointMm(1400, 1200));

      expect(
        controller.snapPortDrivenCableCompletionTarget(
          componentId: socket.id,
          portId: 'power-in',
        ),
        isTrue,
      );

      final completion = controller.portDrivenCableCompletionBinding;
      expect(completion, isNotNull);
      expect(completion!.componentId, socket.id);
      expect(completion.portId, 'power-in');
      expect(completion.position, socket.position);
      expect(controller.routeSegments.last.points.last, socket.position);
      expect(controller.portDrivenCableReadyToFinish, isTrue);

      expect(
        controller.finishManualCableDraft(endpointSnapRadiusMm: 180),
        isTrue,
      );
      expect(controller.p2.routes.single.source.componentId, board.id);
      expect(controller.p2.routes.single.target.componentId, socket.id);
      expect(controller.p2.routes.single.target.portId, 'power-in');
    });

    test('exact completion binding fails closed on co-located ambiguity', () {
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
      controller.p2.placeComponent(
        type: ElectricalComponentType.socketOutlet,
        surface: wall,
        position: const SurfacePointMm(2200, 1200),
      );
      final requested = controller.p2.placeComponent(
        type: ElectricalComponentType.socketOutlet,
        surface: wall,
        position: const SurfacePointMm(2200, 1200),
      );
      controller.p2.select(board.id);
      expect(
        controller.beginPortDrivenCableFromSelectedPort('power-out'),
        isTrue,
      );
      controller.surfaceTap(const SurfacePointMm(1400, 1200));
      expect(
        controller.snapPortDrivenCableCompletionTarget(
          componentId: requested.id,
          portId: 'power-in',
        ),
        isTrue,
      );
      expect(controller.portDrivenCableReadyToFinish, isTrue);

      expect(controller.finishManualCableDraft(), isFalse);
      expect(controller.p2.routes, isEmpty);
      expect(controller.routeSegments, isNotEmpty);
      expect(controller.portDrivenCableCompletionBinding?.componentId,
          requested.id);
    });

    testWidgets('compatible target action exposes explicit ready-to-finish UI',
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
        controller.beginPortDrivenCableFromSelectedPort('power-out'),
        isTrue,
      );
      controller.surfaceTap(const SurfacePointMm(1400, 1200));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: controller,
              builder: (context, _) => CableAuthoringDraftBar(
                controller: controller,
              ),
            ),
          ),
        ),
      );

      final target = find.byKey(
        ValueKey('cable-completion-target-${socket.id}-power-in'),
      );
      expect(target, findsOneWidget);
      await tester.tap(target);
      await tester.pump();

      expect(controller.portDrivenCableReadyToFinish, isTrue);
      expect(find.byKey(const ValueKey('cable-ready-to-finish')), findsOne);
      expect(find.textContaining('READY TO FINISH'), findsOneWidget);
      final finish = tester.widget<FilledButton>(
        find.byKey(const ValueKey('cable-draft-commit')),
      );
      expect(finish.onPressed, isNotNull);
    });
  });
}
