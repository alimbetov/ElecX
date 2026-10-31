import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/features/editor/cable_authoring_draft_bar.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_keyboard_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P12A.0 cable authoring UX', () {
    testWidgets('draft bar exposes host, length and explicit cancel lifecycle',
        (tester) async {
      final controller = EditorController.demo();
      addTearDown(controller.dispose);
      controller.showWall(0);
      controller.setTool(EditorTool.cableRoute);
      controller.surfaceTap(const SurfacePointMm(100, 300));
      controller.surfaceTap(const SurfacePointMm(900, 300));

      await tester.pumpWidget(_barHarness(controller));

      expect(find.byKey(const ValueKey('cable-authoring-draft-bar')), findsOne);
      expect(find.textContaining('Прокладка кабеля · Стена 1'), findsOne);
      expect(find.textContaining('800 мм'), findsOne);
      expect(find.byKey(const ValueKey('cable-draft-commit')), findsOne);

      await tester.tap(find.byKey(const ValueKey('cable-draft-cancel')));
      await tester.pump();

      expect(controller.routeSegments, isEmpty);
      expect(controller.tool, EditorTool.select);
    });

    testWidgets('surface-less cable entry exposes explicit wall host selection',
        (tester) async {
      final controller = EditorController.demo();
      addTearDown(controller.dispose);
      controller.setTool(EditorTool.cableRoute);

      await tester.pumpWidget(_barHarness(controller));

      expect(controller.activeSurface, isNull);
      expect(find.textContaining('выберите поверхность'), findsOne);
      await tester.tap(find.byKey(const ValueKey('cable-host-wall-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('cable-host-wall-0')));
      await tester.pumpAndSettle();

      expect(controller.activeSurface?.type, SurfacePlaneType.wall);
      expect(controller.activeSurface?.wallIndex, 0);
      expect(find.textContaining('Прокладка кабеля · Стена 1'), findsOne);
    });

    testWidgets('unproven wall to ceiling switch is visible and not committable',
        (tester) async {
      final controller = EditorController.demo();
      addTearDown(controller.dispose);
      controller.showWall(0);
      controller.setTool(EditorTool.cableRoute);
      controller.surfaceTap(const SurfacePointMm(100, 300));
      controller.surfaceTap(const SurfacePointMm(900, 300));

      await tester.pumpWidget(_barHarness(controller));
      await tester.tap(find.byKey(const ValueKey('cable-host-ceiling')));
      await tester.pump();

      expect(controller.activeSurface?.type, SurfacePlaneType.ceiling);
      expect(
        find.byKey(const ValueKey('cable-host-transition-warning')),
        findsOne,
      );
      final commit = tester.widget<FilledButton>(
        find.byKey(const ValueKey('cable-draft-commit')),
      );
      expect(commit.onPressed, isNull);
    });

    testWidgets('C enters cable mode on a concrete wall host and Esc exits it',
        (tester) async {
      final controller = EditorController.demo();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: ListenableBuilder(
            listenable: controller,
            builder: (context, _) => EditorKeyboardScope(
              controller: controller,
              child: const Scaffold(body: SizedBox.expand()),
            ),
          ),
        ),
      );

      expect(controller.activeSurface, isNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.pump();

      expect(controller.tool, EditorTool.cableRoute);
      expect(controller.activeSurface?.type, SurfacePlaneType.wall);
      expect(controller.activeSurface?.wallIndex, 0);
      expect(find.byKey(const ValueKey('cable-authoring-draft-bar')), findsOne);

      controller.surfaceTap(const SurfacePointMm(100, 300));
      controller.surfaceTap(const SurfacePointMm(900, 300));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(controller.routeSegments, isEmpty);
      expect(controller.tool, EditorTool.select);
    });
  });
}

Widget _barHarness(EditorController controller) => MaterialApp(
      home: Scaffold(
        body: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => Align(
            alignment: Alignment.bottomCenter,
            child: CableAuthoringDraftBar(controller: controller),
          ),
        ),
      ),
    );
