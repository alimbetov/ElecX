from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    if old not in text:
        raise SystemExit(f'anchor not found in {path}: {old[:140]!r}')
    p.write_text(text.replace(old, new, 1))

replace_once(
    'lib/src/features/editor/editor_keyboard_scope.dart',
    "import '../../domain/surfaces.dart';\n",
    "import '../../domain/surfaces.dart';\nimport '../../engine/editor_layers.dart';\n",
)
replace_once(
    'lib/src/features/editor/editor_keyboard_scope.dart',
    "import 'manual_cable_draft_persistence.dart';\n",
    "import 'manual_cable_draft_persistence.dart';\nimport 'route_selection_session.dart';\n",
)
replace_once(
    'lib/src/features/editor/editor_keyboard_scope.dart',
    "  void _undo() {\n",
    r'''  void _cycleSceneSelection({required bool reverse}) {
    if (_persistentEditActive) return;
    final surface = controller.activeSurface;
    if (surface == null) return;
    final items = <({String id, bool route})>[];
    if (controller.p2.layers.isVisible(EditorLayerId.electrical)) {
      for (final component in controller.p2.components) {
        if (component.surface == surface) {
          items.add((id: component.id, route: false));
        }
      }
    }
    if (controller.p2.layers.isVisible(EditorLayerId.cableRoutes)) {
      for (final route in controller.p2.routes) {
        if (route.segments.any((segment) => segment.surface == surface)) {
          items.add((id: route.id, route: true));
        }
      }
    }
    if (items.isEmpty) return;
    final selectedRouteId = controller.routeSelection.selectedRouteId;
    final selectedComponentId = controller.p2.selection.primaryId;
    var currentIndex = -1;
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      final selected = item.route
          ? item.id == selectedRouteId
          : item.id == selectedComponentId;
      if (selected) {
        currentIndex = index;
        break;
      }
    }
    final nextIndex = currentIndex < 0
        ? (reverse ? items.length - 1 : 0)
        : (currentIndex + (reverse ? -1 : 1)) % items.length;
    final normalizedIndex = nextIndex < 0 ? items.length - 1 : nextIndex;
    final next = items[normalizedIndex];
    if (next.route) {
      controller.p2.clearSelection();
      controller.routeSelection.select(next.id);
    } else {
      controller.routeSelection.clear();
      controller.p2.select(next.id);
    }
  }

  void _undo() {
''',
)
replace_once(
    'lib/src/features/editor/editor_keyboard_scope.dart',
    "        const SingleActivator(LogicalKeyboardKey.escape): _cancelActiveEdit,\n",
    "        const SingleActivator(LogicalKeyboardKey.escape): _cancelActiveEdit,\n        const SingleActivator(LogicalKeyboardKey.tab): () =>\n            _cycleSceneSelection(reverse: false),\n        const SingleActivator(LogicalKeyboardKey.tab, shift: true): () =>\n            _cycleSceneSelection(reverse: true),\n",
)
replace_once(
    'lib/src/features/editor/surface_canvas.dart',
    "import 'package:flutter/material.dart';\n",
    "import 'package:flutter/material.dart';\nimport 'package:flutter/semantics.dart';\n",
)
replace_once(
    'lib/src/features/editor/surface_canvas.dart',
    "  @override\n  void paint(Canvas canvas, Size size) {\n",
    r'''  @override
  SemanticsBuilderCallback get semanticsBuilder => (Size size) {
        final nodes = <CustomPainterSemantics>[];
        final surface = controller.activeSurface;
        if (surface == null) return nodes;
        if (electricalVisible) {
          for (final component in controller.p2.components) {
            if (component.surface != surface) continue;
            final center = projection.surfaceToViewport(component.position);
            nodes.add(
              CustomPainterSemantics(
                key: ValueKey<String>('component-semantics-${component.id}'),
                rect: Rect.fromCenter(center: center, width: 48, height: 48),
                properties: SemanticsProperties(
                  label: '${component.label}, электрический компонент',
                  value:
                      '${component.position.xMm} на ${component.position.yMm} мм',
                  hint: 'Двойное касание выбирает компонент',
                  textDirection: TextDirection.ltr,
                  button: true,
                  selected: controller.p2.selection.contains(component.id),
                  onTap: () {
                    controller.routeSelection.clear();
                    controller.p2.select(component.id);
                  },
                ),
              ),
            );
          }
        }
        if (cableRoutesVisible) {
          for (final route in controller.p2.routes) {
            final points = <Offset>[];
            for (final segment in route.segments) {
              if (segment.surface != surface) continue;
              for (final point in segment.points) {
                points.add(projection.surfaceToViewport(point));
              }
            }
            if (points.isEmpty) continue;
            var left = points.first.dx;
            var right = points.first.dx;
            var top = points.first.dy;
            var bottom = points.first.dy;
            for (final point in points.skip(1)) {
              left = math.min(left, point.dx);
              right = math.max(right, point.dx);
              top = math.min(top, point.dy);
              bottom = math.max(bottom, point.dy);
            }
            final raw = Rect.fromLTRB(left, top, right, bottom);
            nodes.add(
              CustomPainterSemantics(
                key: ValueKey<String>('route-semantics-${route.id}'),
                rect: Rect.fromCenter(
                  center: raw.center,
                  width: math.max(48, raw.width + 24),
                  height: math.max(48, raw.height + 24),
                ),
                properties: SemanticsProperties(
                  label: 'Кабельная трасса ${route.id}',
                  value: route.medium.id,
                  hint: 'Двойное касание выбирает трассу',
                  textDirection: TextDirection.ltr,
                  button: true,
                  selected: selectedRouteId == route.id,
                  onTap: () {
                    controller.p2.clearSelection();
                    controller.routeSelection.select(route.id);
                  },
                ),
              ),
            );
          }
        }
        return nodes;
      };

  @override
  void paint(Canvas canvas, Size size) {
''',
)

Path('test/f17_scene_accessibility_test.dart').write_text(r'''import 'package:elecx/src/domain/electrical_placement.dart';
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
    final semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SurfaceCanvas(controller: controller)),
      ),
    );
    await tester.pump();
    expect(
      find.bySemanticsLabel('${source.label}, электрический компонент'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        'Кабельная трасса ${controller.p2.routes.single.id}',
      ),
      findsOneWidget,
    );
  });

  testWidgets('F17 Tab and Shift Tab traverse visible scene objects',
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
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(controller.p2.selection.primaryId, first.id);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(controller.p2.selection.primaryId, second.id);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(controller.routeSelection.selectedRouteId, routeId);
    expect(controller.p2.selection.ids, isEmpty);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(controller.p2.selection.primaryId, second.id);
    expect(controller.routeSelection.selectedRouteId, isNull);
  });

  testWidgets('F17 hidden layers are omitted from keyboard traversal',
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
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(controller.p2.selection.contains(component.id), isFalse);
  });
}
''')