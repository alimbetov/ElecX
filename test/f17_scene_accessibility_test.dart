import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/engine/editor_layers.dart';
import 'package:elecx/src/engine/selection_engine.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_keyboard_scope.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:elecx/src/features/editor/route_selection_session.dart';
import 'package:elecx/src/features/editor/surface_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('F17 canvas publishes component and route semantics',
      (tester) async {
    final controller = EditorController.demo();
    addTearDown(() {
      controller.disposeP2State();
      controller.dispose();
    });
    controller.showWall(1);
    final surface = controller.activeSurface!;
    final source = controller.p2.placeComponent(
      type: ElectricalComponentType.powerSource,
      surface: surface,
      position: const SurfacePointMm(300, 900),
    );
    final target = controller.p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: surface,
      position: const SurfacePointMm(2400, 900),
    );
    controller.p2.select(source.id);
    controller.p2.select(target.id, mode: SelectionMode.add);
    expect(
      controller.p2.autoRouteSelectedPair(space: controller.selectedSpace),
      isTrue,
    );
    controller.p2.clearSelection();
    controller.routeSelection.clear();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SurfaceCanvas(controller: controller)),
      ),
    );
    await tester.pump();
    expect(
      find.semantics.byLabel('${source.label}, электрический компонент'),
      findsOne,
    );
    expect(
      find.semantics.byLabel(
        'Кабельная трасса ${controller.p2.routes.single.id}',
      ),
      findsOne,
    );
  });

  testWidgets('F17 Ctrl+Tab and Ctrl+Shift+Tab traverse visible scene objects',
      (tester) async {
    final controller = EditorController.demo();
    addTearDown(() {
      controller.disposeP2State();
      controller.dispose();
    });
    controller.showWall(1);
    final surface = controller.activeSurface!;
    final first = controller.p2.placeComponent(
      type: ElectricalComponentType.powerSource,
      surface: surface,
      position: const SurfacePointMm(300, 900),
    );
    final second = controller.p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: surface,
      position: const SurfacePointMm(2400, 900),
    );
    controller.p2.select(first.id);
    controller.p2.select(second.id, mode: SelectionMode.add);
    expect(
      controller.p2.autoRouteSelectedPair(space: controller.selectedSpace),
      isTrue,
    );
    final routeId = controller.p2.routes.single.id;
    controller.p2.clearSelection();
    controller.routeSelection.clear();
    await tester.pumpWidget(
      MaterialApp(
        home: EditorKeyboardScope(
          controller: controller,
          child: const Scaffold(body: SizedBox.expand()),
        ),
      ),
    );
    await tester.pump();
    await _sendControlTab(tester);
    expect(controller.p2.selection.primaryId, first.id);
    await _sendControlTab(tester);
    expect(controller.p2.selection.primaryId, second.id);
    await _sendControlTab(tester);
    expect(controller.routeSelection.selectedRouteId, routeId);
    expect(controller.p2.selection.ids, isEmpty);
    await _sendControlTab(tester, reverse: true);
    expect(controller.p2.selection.primaryId, second.id);
    expect(controller.routeSelection.selectedRouteId, isNull);
  });

  testWidgets('F17 hidden layers are omitted from keyboard scene traversal',
      (tester) async {
    final controller = EditorController.demo();
    addTearDown(() {
      controller.disposeP2State();
      controller.dispose();
    });
    controller.showWall(1);
    final component = controller.p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: controller.activeSurface!,
      position: const SurfacePointMm(800, 900),
    );
    controller.p2.clearSelection();
    controller.p2.setLayerVisible(EditorLayerId.electrical, false);
    await tester.pumpWidget(
      MaterialApp(
        home: EditorKeyboardScope(
          controller: controller,
          child: const Scaffold(body: SizedBox.expand()),
        ),
      ),
    );
    await tester.pump();
    await _sendControlTab(tester);
    expect(controller.p2.selection.contains(component.id), isFalse);
  });
}

Future<void> _sendControlTab(
  WidgetTester tester, {
  bool reverse = false,
}) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  if (reverse) {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  }
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  if (reverse) {
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  }
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
}
