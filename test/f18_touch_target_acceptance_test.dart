import 'package:elecx/src/features/editor/canvas_component_controls.dart';
import 'package:elecx/src/features/editor/canvas_viewport_navigator.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:elecx/src/features/editor/editor_ui_tokens.dart';
import 'package:elecx/src/features/editor/unified_icon_toolbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('F18 shared target contract is 48 logical pixels', () {
    expect(EditorUiTokens.minimumTouchTarget, greaterThanOrEqualTo(48));
    expect(EditorUiTokens.commandTarget, greaterThanOrEqualTo(48));
    expect(EditorUiTokens.compactCommandTarget, greaterThanOrEqualTo(48));
    expect(
      EditorUiTokens.commandBarHeight,
      greaterThanOrEqualTo(EditorUiTokens.compactCommandTarget + 8),
    );
  });

  testWidgets('F18 viewport navigator exposes 48dp hit regions',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: CanvasViewportNavigator(
              onPan: (_, __) {},
              onZoomIn: () {},
              onZoomOut: () {},
              onFit: () {},
            ),
          ),
        ),
      ),
    );
    final size = tester.getSize(find.byTooltip('Сместить фокус вверх'));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('F18 component controls expose 48dp move and delete targets',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: CanvasComponentControls(
              label: 'Розетка',
              stepMm: 100,
              onStepChanged: (_) {},
              onMove: (_, __) {},
              onDelete: () {},
            ),
          ),
        ),
      ),
    );
    final move = tester.getSize(find.byTooltip('Влево на 100 мм'));
    final delete = tester.getSize(find.byTooltip('Удалить компонент'));
    expect(move.width, greaterThanOrEqualTo(48));
    expect(move.height, greaterThanOrEqualTo(48));
    expect(delete.width, greaterThanOrEqualTo(48));
    expect(delete.height, greaterThanOrEqualTo(48));
  });

  testWidgets('F18 editor toolbar target fits inside command bar',
      (tester) async {
    final controller = EditorController.demo();
    addTearDown(() {
      controller.disposeP2State();
      controller.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UnifiedEditorIconToolbar(controller: controller, compact: true),
        ),
      ),
    );
    await tester.pump();
    final button = tester.getSize(find.byTooltip('Выбор (V)'));
    expect(button.width, greaterThanOrEqualTo(48));
    expect(button.height, greaterThanOrEqualTo(48));
    expect(
      tester.getSize(find.byType(UnifiedEditorIconToolbar)).height,
      greaterThanOrEqualTo(56),
    );
  });
}
