import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/engine/editor_layers.dart';
import 'package:elecx/src/engine/selection_engine.dart';
import 'package:flutter/services.dart';
import 'package:elecx/src/features/editor/component_catalog_session.dart';
import 'package:elecx/src/features/editor/component_transform_session.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_keyboard_scope.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:elecx/src/features/editor/engineering_placement_cursor_session.dart';
import 'package:elecx/src/features/editor/manual_cable_draft_persistence.dart';
import 'package:elecx/src/features/editor/surface_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('F10 locked electrical layer blocks catalog cursor placement', () {
    final controller = EditorController.demo();
    addTearDown(() {
      controller.disposeP2State();
      controller.dispose();
    });
    controller.showWall(1);
    final entry = controller.componentCatalog
        .forSurface(SurfacePlaneType.wall)
        .first;
    controller.p2.setLayerLocked(EditorLayerId.electrical, true);
    controller.placementCursor.beginCatalogPlacement(entry.id);

    expect(controller.placementCursor.confirm(), isFalse);
    expect(controller.p2.components, isEmpty);
  });

  test('F10 cable layer lock protects connected route and route metadata', () {
    final controller = EditorController.demo();
    addTearDown(() {
      controller.disposeP2State();
      controller.dispose();
    });
    controller.showWall(1);
    final surface = controller.activeSurface!;
    final board = controller.p2.placeComponent(
      type: ElectricalComponentType.distributionBoard,
      surface: surface,
      position: const SurfacePointMm(200, 1000),
    );
    final load = controller.p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: surface,
      position: const SurfacePointMm(2800, 1000),
    );
    controller.p2.select(board.id);
    controller.p2.select(load.id, mode: SelectionMode.add);
    expect(
      controller.p2.autoRouteSelectedPair(space: controller.selectedSpace),
      isTrue,
    );
    final route = controller.p2.routes.single;
    controller.p2.setLayerLocked(EditorLayerId.cableRoutes, true);

    expect(controller.p2.toggleRouteSegmentLock(route.id, 0), isFalse);
    controller.p2.select(load.id);
    expect(controller.p2.deleteSelection(), isFalse);
    expect(controller.p2.routes.single.id, route.id);
    expect(controller.p2.components.any((item) => item.id == load.id), isTrue);
  });

  test('F11 manual draft finishes into persistent ElectricalCableRoute', () {
    final controller = EditorController.demo();
    addTearDown(() {
      controller.disposeP2State();
      controller.dispose();
    });
    controller.showWall(1);
    final surface = controller.activeSurface!;
    final board = controller.p2.placeComponent(
      type: ElectricalComponentType.distributionBoard,
      surface: surface,
      position: const SurfacePointMm(200, 1000),
    );
    final load = controller.p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: surface,
      position: const SurfacePointMm(2800, 1000),
    );
    controller.setTool(EditorTool.cableRoute);
    controller.surfaceTap(board.position);
    controller.surfaceTap(const SurfacePointMm(1500, 1000));
    controller.surfaceTap(load.position);

    expect(controller.finishManualCableDraft(endpointSnapRadiusMm: 20), isTrue);
    expect(controller.routeSegments, isEmpty);
    expect(controller.tool, EditorTool.select);
    expect(controller.p2.routes, hasLength(1));
    expect(controller.p2.routes.single.source.componentId, board.id);
    expect(controller.p2.routes.single.target.componentId, load.id);
  });

  testWidgets('F11 first Escape clears manual draft, second exits tool', (
    tester,
  ) async {
    final controller = EditorController.demo();
    addTearDown(() {
      controller.disposeP2State();
      controller.dispose();
    });
    controller.showWall(1);
    controller.setTool(EditorTool.cableRoute);
    controller.surfaceTap(const SurfacePointMm(200, 1000));
    controller.surfaceTap(const SurfacePointMm(800, 1000));
    await tester.pumpWidget(
      MaterialApp(
        home: EditorKeyboardScope(
          controller: controller,
          child: const Scaffold(body: SizedBox.expand()),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(controller.routeSegments, isEmpty);
    expect(controller.tool, EditorTool.cableRoute);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(controller.tool, EditorTool.select);
  });

  testWidgets('F13 invalid component target remains visible and uncommitted', (
    tester,
  ) async {
    final controller = EditorController.demo();
    addTearDown(() {
      controller.disposeP2State();
      controller.dispose();
    });
    controller.showWall(1);
    final component = controller.p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: controller.activeSurface!,
      position: const SurfacePointMm(1000, 500),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SurfaceCanvas(controller: controller)),
      ),
    );
    await tester.pump();

    expect(controller.componentTransform.begin(), isTrue);
    expect(
      controller.componentTransform.preview(
        const SurfacePointMm(5000, 500),
        isValid: false,
      ),
      isFalse,
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('component-preview-invalid')),
      findsOneWidget,
    );
    expect(
      controller.componentTransform.previewState!.position,
      const SurfacePointMm(5000, 500),
    );
    expect(
      controller.p2.components
          .singleWhere((item) => item.id == component.id)
          .position,
      component.position,
    );
    expect(controller.componentTransform.commit(), isFalse);
    controller.componentTransform.cancel();
    expect(
      controller.p2.components
          .singleWhere((item) => item.id == component.id)
          .position,
      component.position,
    );
  });
}
