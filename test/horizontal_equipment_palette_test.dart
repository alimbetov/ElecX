import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:elecx/src/features/editor/horizontal_equipment_palette.dart';
import 'package:elecx/src/features/editor/surface_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('equipment palette filters, collapses, and restores groups',
      (tester) async {
    final controller = EditorController.demo();
    addTearDown(() {
      controller.disposeP2State();
      controller.dispose();
    });
    var expanded = true;
    await tester.binding.setSurfaceSize(const Size(1100, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: StatefulBuilder(
        builder: (context, setState) => Scaffold(
          body: Column(
            children: [
              HorizontalEquipmentPalette(
                controller: controller,
                expanded: expanded,
                onToggle: () => setState(() => expanded = !expanded),
              ),
              const Expanded(child: SizedBox()),
            ],
          ),
        ),
      ),
    ));
    expect(find.byKey(const ValueKey('equipment-palette-scroll')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('equipment-palette-categories')),
        findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('equipment-palette-toggle')));
    await tester.pump();
    expect(find.byKey(const ValueKey('equipment-palette-scroll')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('equipment-palette-toggle')));
    await tester.pump();
    expect(find.byKey(const ValueKey('equipment-palette-scroll')),
        findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('equipment-palette-search')),
      'socket.general',
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('equipment-palette-scroll')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('drag from palette onto compatible wall creates P2 component',
      (tester) async {
    final controller = EditorController.demo();
    addTearDown(() {
      controller.disposeP2State();
      controller.dispose();
    });
    controller.selectSpace(controller.level.spaces.first.id);
    controller.showWall(0);
    await tester.binding.setSurfaceSize(const Size(1200, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            HorizontalEquipmentPalette(
              controller: controller,
              expanded: true,
              onToggle: () {},
            ),
            Expanded(child: SurfaceCanvas(controller: controller)),
          ],
        ),
      ),
    ));
    await tester.pump();
    final card = find.byKey(
      const ValueKey('equipment-palette-item-power.socket.general'),
    );
    expect(card, findsOneWidget);
    final before = controller.p2.components.length;
    final canvas = find.byType(SurfaceCanvas);
    final gesture = await tester.startGesture(tester.getCenter(card));
    await gesture.moveBy(const Offset(0, 45));
    await tester.pump();
    await gesture.moveTo(tester.getCenter(canvas));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(controller.p2.components.length, before + 1);
    expect(controller.p2.components.last.componentTypeId,
        'power.socket.general');
    expect(tester.takeException(), isNull);
  });
}
