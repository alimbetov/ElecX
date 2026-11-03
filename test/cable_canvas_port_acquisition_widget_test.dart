import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/engine/world_camera.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:elecx/src/features/editor/manual_cable_draft_persistence.dart';
import 'package:elecx/src/features/editor/port_driven_cable_authoring.dart';
import 'package:elecx/src/features/editor/surface_canvas.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Offset _screenPoint(
  WidgetTester tester,
  EditorController controller,
  SurfacePointMm point,
) {
  const width = 800.0;
  const height = 600.0;
  final wall = controller.activeWall!;
  final camera = const WorldCamera(
    centerMm: MmPoint(0, 0),
    mmPerPixel: 10,
  ).fitBounds(
    bounds: MmBounds(
      left: 0,
      bottom: 0,
      right: wall.lengthMm.round(),
      top: wall.heightMm,
    ),
    viewportWidthPx: width,
    viewportHeightPx: height,
    paddingPx: 88,
  );
  final mapped = camera.worldToScreen(
    viewportWidthPx: width,
    viewportHeightPx: height,
    point: MmPoint(point.xMm, point.yMm),
  );
  return tester.getTopLeft(find.byType(SurfaceCanvas)) +
      Offset(mapped.x, mapped.y);
}

void main() {
  testWidgets('P12A.3 hover previews without P2 mutation and tap pins port',
      (tester) async {
    final controller = EditorController.demo();
    addTearDown(() {
      controller.disposeP2State();
      controller.dispose();
    });
    controller.showWall(0);
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
    expect(
        controller.beginPortDrivenCableFromSelectedPort('power-out'), isTrue);
    final revision = controller.p2.history.mutationRevision;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: SurfaceCanvas(controller: controller),
          ),
        ),
      ),
    );
    await tester.pump();
    final point = _screenPoint(tester, controller, socket.position);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: point + const Offset(30, 0));
    await mouse.moveTo(point);
    await tester.pump();
    expect(controller.portDrivenCableCompletionBinding, isNull);
    expect(controller.p2.history.mutationRevision, revision);
    expect(controller.routeSegments.single.points, [board.position]);

    await tester.tapAt(point);
    await tester.pump();
    expect(controller.portDrivenCableCompletionBinding?.componentId, socket.id);
    expect(controller.portDrivenCableCompletionBinding?.portId, 'power-in');
    expect(controller.portDrivenCableReadyToFinish, isTrue);
    expect(controller.routeSegments.last.points.last, socket.position);
    expect(controller.p2.history.mutationRevision, revision);
    expect(controller.p2.routes, isEmpty);

    await tester.tapAt(
      _screenPoint(
        tester,
        controller,
        const SurfacePointMm(3600, 1200),
      ),
    );
    await tester.pump();
    expect(controller.portDrivenCableCompletionBinding, isNull);
    expect(controller.portDrivenCableReadyToFinish, isFalse);
    expect(controller.p2.routes, isEmpty);
    await mouse.removePointer();
  });

  testWidgets('P12A.3 co-located targets never auto-bind on canvas',
      (tester) async {
    final controller = EditorController.demo();
    addTearDown(() {
      controller.disposeP2State();
      controller.dispose();
    });
    controller.showWall(0);
    final surface = RoomSurfaceRef.wall('room-101', 0);
    final board = controller.p2.placeComponent(
      type: ElectricalComponentType.distributionBoard,
      surface: surface,
      position: const SurfacePointMm(500, 1200),
    );
    controller.p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: surface,
      position: const SurfacePointMm(2200, 1200),
    );
    final second = controller.p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: surface,
      position: const SurfacePointMm(2200, 1200),
    );
    controller.p2.select(board.id);
    expect(
        controller.beginPortDrivenCableFromSelectedPort('power-out'), isTrue);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: SurfaceCanvas(controller: controller),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tapAt(_screenPoint(tester, controller, second.position));
    await tester.pump();
    expect(controller.portDrivenCableCompletionBinding, isNull);
    expect(controller.portDrivenCableReadyToFinish, isFalse);
    expect(controller.p2.routes, isEmpty);
  });

  testWidgets('P12A.3 socket-first canvas click commits source-to-target',
      (tester) async {
    final controller = EditorController.demo();
    addTearDown(() {
      controller.disposeP2State();
      controller.dispose();
    });
    controller.showWall(0);
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
    expect(
        controller.beginPortDrivenCableFromSelectedPort('power-in'), isTrue);
    expect(controller.portDrivenCableStartBinding?.componentId, socket.id);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: SurfaceCanvas(controller: controller),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tapAt(_screenPoint(tester, controller, board.position));
    await tester.pump();
    expect(controller.portDrivenCableReadyToFinish, isTrue);
    expect(controller.portDrivenCableCompletionBinding?.componentId, board.id);
    expect(controller.finishManualCableDraft(endpointSnapRadiusMm: 40), isTrue);
    expect(controller.p2.routes, hasLength(1));
    final route = controller.p2.routes.single;
    expect(route.source.componentId, board.id);
    expect(route.source.portId, 'power-out');
    expect(route.target.componentId, socket.id);
    expect(route.target.portId, 'power-in');
    expect(route.segments.single.points.first, board.position);
    expect(route.segments.single.points.last, socket.position);
    expect(controller.portDrivenCableStartBinding, isNull);
    expect(controller.portDrivenCableCompletionBinding, isNull);
  });

}
