import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/engine/selection_engine.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:elecx/src/features/editor/route_selection_session.dart';
import 'package:elecx/src/features/editor/surface_canvas.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const viewportSize = Size(800, 600);
  const wallWidthMm = 4200.0;
  const wallHeightMm = 3000.0;
  const fitPaddingPx = 88.0;

  double mmPerPixel() {
    final usableWidth = viewportSize.width - fitPaddingPx * 2;
    final usableHeight = viewportSize.height - fitPaddingPx * 2;
    return (wallWidthMm / usableWidth) > (wallHeightMm / usableHeight)
        ? wallWidthMm / usableWidth
        : wallHeightMm / usableHeight;
  }

  Offset viewportPoint(SurfacePointMm point) {
    final scale = mmPerPixel();
    return Offset(
      viewportSize.width / 2 + (point.xMm - wallWidthMm / 2) / scale,
      viewportSize.height / 2 - (point.yMm - wallHeightMm / 2) / scale,
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
        home: Scaffold(body: SurfaceCanvas(controller: controller)),
      ),
    );
    await tester.pump();
  }

  EditorController controllerWithWall() {
    final controller = EditorController.demo();
    controller.showWall(0);
    return controller;
  }

  testWidgets('component mouse drag commits one transactional history entry', (
    tester,
  ) async {
    final controller = controllerWithWall();
    addTearDown(controller.dispose);
    final surface = controller.activeSurface!;
    final component = controller.p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: surface,
      position: const SurfacePointMm(2100, 1500),
    );
    final depthBefore = controller.p2.history.undoDepth;

    await pumpCanvas(tester, controller);
    final canvasOrigin = tester.getTopLeft(find.byType(SurfaceCanvas));
    final start = canvasOrigin + viewportPoint(component.position);
    final target = canvasOrigin + viewportPoint(const SurfacePointMm(2500, 1500));

    final gesture = await tester.startGesture(start, kind: PointerDeviceKind.mouse);
    await gesture.moveTo(target);
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(controller.p2.selectedComponent?.position.xMm, 2500);
    expect(controller.p2.selectedComponent?.position.yMm, 1500);
    expect(controller.p2.history.undoDepth, depthBefore + 1);

    controller.p2.undo();
    expect(controller.p2.selectedComponent?.position, component.position);
  });

  testWidgets('second pointer cancels active component transform exactly', (
    tester,
  ) async {
    final controller = controllerWithWall();
    addTearDown(controller.dispose);
    final component = controller.p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: controller.activeSurface!,
      position: const SurfacePointMm(2100, 1500),
    );
    final depthBefore = controller.p2.history.undoDepth;

    await pumpCanvas(tester, controller);
    final origin = tester.getTopLeft(find.byType(SurfaceCanvas));
    final start = origin + viewportPoint(component.position);
    final moved = origin + viewportPoint(const SurfacePointMm(2500, 1500));

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
    await tester.pump();

    expect(controller.p2.selectedComponent?.position, component.position);
    expect(controller.p2.history.undoDepth, depthBefore);
  });

  testWidgets('endpoint drag snaps to compatible port and is one undo step', (
    tester,
  ) async {
    final controller = controllerWithWall();
    addTearDown(controller.dispose);
    final surface = controller.activeSurface!;
    final source = controller.p2.placeComponent(
      type: ElectricalComponentType.powerSource,
      surface: surface,
      position: const SurfacePointMm(1000, 1500),
    );
    final oldTarget = controller.p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: surface,
      position: const SurfacePointMm(3000, 1500),
    );
    final newTarget = controller.p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: surface,
      position: const SurfacePointMm(2100, 2200),
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
    final start = origin + viewportPoint(originalRoute.segments.last.points.last);
    final target = origin + viewportPoint(newTarget.position);

    final gesture = await tester.startGesture(start, kind: PointerDeviceKind.mouse);
    await gesture.moveTo(target);
    await tester.pump();
    await gesture.up();
    await tester.pump();

    final committed = controller.p2.routes.single;
    expect(committed.target.componentId, newTarget.id);
    expect(committed.segments.last.points.last, newTarget.position);
    expect(controller.p2.history.undoDepth, depthBefore + 1);

    controller.p2.undo();
    final restored = controller.p2.routes.single;
    expect(restored.target.componentId, oldTarget.id);
    expect(restored.segments.last.points.last, originalRoute.segments.last.points.last);
  });
}
