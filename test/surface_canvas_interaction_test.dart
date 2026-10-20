import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/engine/normative_route_engine.dart';
import 'package:elecx/src/engine/selection_engine.dart';
import 'package:elecx/src/features/editor/cable_edit_access.dart';
import 'package:elecx/src/features/editor/cable_editor_ui_session.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_keyboard_scope.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:elecx/src/features/editor/route_selection_session.dart';
import 'package:elecx/src/features/editor/surface_canvas.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const viewportSize = Size(800, 600);
  const fitPaddingPx = 88.0;
  const gestureDrain = Duration(milliseconds: 60);

  double mmPerPixel(EditorController controller) {
    final wall = controller.activeWall!;
    final usableWidth = viewportSize.width - fitPaddingPx * 2;
    final usableHeight = viewportSize.height - fitPaddingPx * 2;
    final widthScale = wall.lengthMm / usableWidth;
    final heightScale = wall.heightMm / usableHeight;
    return widthScale > heightScale ? widthScale : heightScale;
  }

  Offset viewportPoint(
    EditorController controller,
    SurfacePointMm point,
  ) {
    final wall = controller.activeWall!;
    final scale = mmPerPixel(controller);
    return Offset(
      viewportSize.width / 2 + (point.xMm - wall.lengthMm / 2) / scale,
      viewportSize.height / 2 - (point.yMm - wall.heightMm / 2) / scale,
    );
  }

  Future<void> pumpCanvas(
    WidgetTester tester,
    EditorController controller,
  ) async {
    await tester.binding.setSurfaceSize(viewportSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EditorKeyboardScope(
            controller: controller,
            child: SurfaceCanvas(controller: controller),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> drainGestureTimers(WidgetTester tester) async {
    await tester.pump(gestureDrain);
  }

  EditorController controllerWithClearWall() {
    final controller = EditorController.demo();
    // Wall 1 has no architectural openings in the demo fixture. Keeping the
    // interaction fixture clear makes these tests exercise input/session wiring
    // rather than obstacle migration semantics from an existing legacy route.
    controller.showWall(1);
    return controller;
  }

  testWidgets('component mouse drag commits one transactional history entry', (
    tester,
  ) async {
    final controller = controllerWithClearWall();
    addTearDown(controller.dispose);
    final component = controller.p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: controller.activeSurface!,
      position: const SurfacePointMm(1600, 1500),
    );
    final depthBefore = controller.p2.history.undoDepth;

    await pumpCanvas(tester, controller);
    final canvasOrigin = tester.getTopLeft(find.byType(SurfaceCanvas));
    final start = canvasOrigin + viewportPoint(controller, component.position);
    final target = canvasOrigin +
        viewportPoint(controller, const SurfacePointMm(2000, 1500));

    final gesture = await tester.startGesture(
      start,
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveTo(target);
    await tester.pump();
    await gesture.up();
    await drainGestureTimers(tester);

    expect(controller.p2.selectedComponent?.position.xMm, 2000);
    expect(controller.p2.selectedComponent?.position.yMm, 1500);
    expect(controller.p2.history.undoDepth, depthBefore + 1);

    controller.p2.undo();
    expect(controller.p2.selectedComponent?.position, component.position);
  });

  testWidgets('component stylus drag uses the same transform transaction', (
    tester,
  ) async {
    final controller = controllerWithClearWall();
    addTearDown(controller.dispose);
    final component = controller.p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: controller.activeSurface!,
      position: const SurfacePointMm(1600, 1500),
    );
    final depthBefore = controller.p2.history.undoDepth;

    await pumpCanvas(tester, controller);
    final origin = tester.getTopLeft(find.byType(SurfaceCanvas));
    final start = origin + viewportPoint(controller, component.position);
    final target =
        origin + viewportPoint(controller, const SurfacePointMm(2000, 1500));

    final gesture = await tester.startGesture(
      start,
      kind: PointerDeviceKind.stylus,
    );
    await gesture.moveTo(target);
    await tester.pump();
    await gesture.up();
    await drainGestureTimers(tester);

    expect(controller.p2.selectedComponent?.position.xMm, 2000);
    expect(controller.p2.selectedComponent?.position.yMm, 1500);
    expect(controller.p2.history.undoDepth, depthBefore + 1);
    controller.p2.undo();
    expect(controller.p2.selectedComponent?.position, component.position);
  });

  testWidgets('escape cancels active pointer transform without history', (
    tester,
  ) async {
    final controller = controllerWithClearWall();
    addTearDown(controller.dispose);
    final component = controller.p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: controller.activeSurface!,
      position: const SurfacePointMm(1600, 1500),
    );
    final depthBefore = controller.p2.history.undoDepth;

    await pumpCanvas(tester, controller);
    final origin = tester.getTopLeft(find.byType(SurfaceCanvas));
    final start = origin + viewportPoint(controller, component.position);
    final moved =
        origin + viewportPoint(controller, const SurfacePointMm(2000, 1500));

    final gesture = await tester.startGesture(
      start,
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveTo(moved);
    await tester.pump();
    expect(
      controller.p2.selectedComponent?.position,
      isNot(component.position),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(controller.p2.selectedComponent?.position, component.position);
    expect(controller.p2.history.undoDepth, depthBefore);

    await gesture.up();
    await drainGestureTimers(tester);
    expect(controller.p2.selectedComponent?.position, component.position);
    expect(controller.p2.history.undoDepth, depthBefore);
  });

  testWidgets('second pointer cancels active component transform exactly', (
    tester,
  ) async {
    final controller = controllerWithClearWall();
    addTearDown(controller.dispose);
    final component = controller.p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: controller.activeSurface!,
      position: const SurfacePointMm(1600, 1500),
    );
    final depthBefore = controller.p2.history.undoDepth;

    await pumpCanvas(tester, controller);
    final origin = tester.getTopLeft(find.byType(SurfaceCanvas));
    final start = origin + viewportPoint(controller, component.position);
    final moved =
        origin + viewportPoint(controller, const SurfacePointMm(2000, 1500));

    final first = await tester.startGesture(
      start,
      pointer: 1,
      kind: PointerDeviceKind.touch,
    );
    await first.moveTo(moved);
    await tester.pump();
    final second = await tester.startGesture(
      origin + const Offset(100, 100),
      pointer: 2,
      kind: PointerDeviceKind.touch,
    );
    await tester.pump();
    await second.up();
    await first.up();
    await drainGestureTimers(tester);

    expect(controller.p2.selectedComponent?.position, component.position);
    expect(controller.p2.history.undoDepth, depthBefore);
  });

  testWidgets('endpoint drag snaps to compatible port and is one undo step', (
    tester,
  ) async {
    final controller = controllerWithClearWall();
    addTearDown(controller.dispose);
    final surface = controller.activeSurface!;
    final source = controller.p2.placeComponent(
      type: ElectricalComponentType.powerSource,
      surface: surface,
      position: const SurfacePointMm(600, 1500),
    );
    final oldTarget = controller.p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: surface,
      position: const SurfacePointMm(2600, 1500),
    );
    final newTarget = controller.p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: surface,
      position: const SurfacePointMm(1600, 2200),
    );
    controller.p2.select(source.id);
    controller.p2.select(oldTarget.id, mode: SelectionMode.add);
    expect(
      controller.p2.autoRouteSelectedPair(space: controller.selectedSpace),
      isTrue,
    );
    final originalRoute = controller.p2.routes.single;
    controller.routeSelection.select(originalRoute.id);
    final depthBefore = controller.p2.history.undoDepth;

    await pumpCanvas(tester, controller);
    final origin = tester.getTopLeft(find.byType(SurfaceCanvas));
    final start = origin +
        viewportPoint(controller, originalRoute.segments.last.points.last);
    final target = origin + viewportPoint(controller, newTarget.position);

    final gesture = await tester.startGesture(
      start,
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveTo(target);
    await tester.pump();

    expect(controller.cableEndpointTransform.active, isTrue);
    final preview = controller.cableEndpointTransform.previewState;
    expect(preview, isNotNull);
    expect(preview!.route.target.componentId, newTarget.id);

    await gesture.up();
    await drainGestureTimers(tester);

    final committed = controller.p2.routes.single;
    expect(committed.target.componentId, newTarget.id);
    expect(committed.segments.last.points.last, newTarget.position);
    expect(controller.p2.history.undoDepth, depthBefore + 1);

    controller.p2.undo();
    final restored = controller.p2.routes.single;
    expect(restored.target.componentId, oldTarget.id);
    expect(
      restored.segments.last.points.last,
      originalRoute.segments.last.points.last,
    );
  });

  testWidgets('assisted first segment drag keeps endpoints and is undoable', (
    tester,
  ) async {
    final controller = controllerWithClearWall();
    addTearDown(controller.dispose);
    final surface = controller.activeSurface!;
    final source = controller.p2.placeComponent(
      type: ElectricalComponentType.powerSource,
      surface: surface,
      position: const SurfacePointMm(600, 1000),
    );
    final target = controller.p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: surface,
      position: const SurfacePointMm(2600, 2200),
    );
    controller.p2.select(source.id);
    controller.p2.select(target.id, mode: SelectionMode.add);
    expect(
      controller.p2.autoRouteSelectedPair(space: controller.selectedSpace),
      isTrue,
    );
    final original = controller.p2.routes.single;
    expect(original.segments.single.points.length, greaterThanOrEqualTo(3));
    controller.routeSelection.select(original.id);
    controller.cableUi.setMode(CableRoutingMode.assisted);
    final depthBefore = controller.p2.history.undoDepth;

    await pumpCanvas(tester, controller);
    final points = original.segments.single.points;
    final edgeA = points[0];
    final edgeB = points[1];
    final midpoint = SurfacePointMm(
      (edgeA.xMm + edgeB.xMm) ~/ 2,
      (edgeA.yMm + edgeB.yMm) ~/ 2,
    );
    final horizontal = edgeA.yMm == edgeB.yMm;
    final dragTarget = horizontal
        ? SurfacePointMm(midpoint.xMm, midpoint.yMm + 300)
        : SurfacePointMm(midpoint.xMm + 300, midpoint.yMm);
    final origin = tester.getTopLeft(find.byType(SurfaceCanvas));

    final gesture = await tester.startGesture(
      origin + viewportPoint(controller, midpoint),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveTo(origin + viewportPoint(controller, dragTarget));
    await tester.pump();

    expect(controller.cableRouteEdit.active, isTrue);
    expect(controller.cableRouteEdit.previewState, isNotNull);

    await gesture.up();
    await drainGestureTimers(tester);

    final committed = controller.p2.routes.single;
    expect(committed.segments.single.points,
        isNot(original.segments.single.points));
    expect(committed.segments.single.points.first, points.first);
    expect(committed.segments.single.points.last, points.last);
    expect(controller.p2.history.undoDepth, depthBefore + 1);

    controller.p2.undo();
    expect(controller.p2.routes.single.segments.single.points, points);
  });

  testWidgets('endpoint outside compatible ports is invalid and not committed',
      (
    tester,
  ) async {
    final controller = controllerWithClearWall();
    addTearDown(controller.dispose);
    final surface = controller.activeSurface!;
    final source = controller.p2.placeComponent(
      type: ElectricalComponentType.powerSource,
      surface: surface,
      position: const SurfacePointMm(600, 1500),
    );
    final oldTarget = controller.p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: surface,
      position: const SurfacePointMm(2600, 1500),
    );
    controller.p2.select(source.id);
    controller.p2.select(oldTarget.id, mode: SelectionMode.add);
    expect(
      controller.p2.autoRouteSelectedPair(space: controller.selectedSpace),
      isTrue,
    );
    final originalRoute = controller.p2.routes.single;
    controller.routeSelection.select(originalRoute.id);
    final depthBefore = controller.p2.history.undoDepth;

    await pumpCanvas(tester, controller);
    final origin = tester.getTopLeft(find.byType(SurfaceCanvas));
    final start = origin +
        viewportPoint(controller, originalRoute.segments.last.points.last);
    final emptyPoint =
        origin + viewportPoint(controller, const SurfacePointMm(1600, 700));

    final gesture = await tester.startGesture(
      start,
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveTo(emptyPoint);
    await tester.pump();

    expect(controller.cableEndpointTransform.active, isTrue);
    expect(controller.cableEndpointTransform.previewState, isNull);
    expect(find.textContaining('Недопустимый preview'), findsOneWidget);
    expect(controller.p2.routes.single.target, originalRoute.target);

    await gesture.up();
    await drainGestureTimers(tester);

    expect(controller.p2.routes.single.target, originalRoute.target);
    expect(
      controller.p2.routes.single.segments.last.points.last,
      originalRoute.segments.last.points.last,
    );
    expect(controller.p2.history.undoDepth, depthBefore);
  });
}
