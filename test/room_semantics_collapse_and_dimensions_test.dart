import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/engineering_inspector_panel.dart';
import 'package:elecx/src/features/editor/room_dimensions_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Room Semantic starts collapsed and opens only by icon row',
      (tester) async {
    final controller = EditorController.demo();
    addTearDown(() {
      controller.disposeP2State();
      controller.dispose();
    });
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 350,
          height: 650,
          child: EngineeringInspectorPanel(
            controller: controller,
            semanticsInspector: const Text('ROOM-SEMANTIC-CONTENT'),
          ),
        ),
      ),
    ));
    expect(find.byKey(const ValueKey('room-semantics-toggle')), findsOneWidget);
    expect(find.text('ROOM-SEMANTIC-CONTENT'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('room-semantics-toggle')));
    await tester.pump();
    expect(find.text('ROOM-SEMANTIC-CONTENT'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('room-semantics-toggle')));
    await tester.pump();
    expect(find.text('ROOM-SEMANTIC-CONTENT'), findsNothing);
  });

  testWidgets('room dimensions dialog returns exact mm sizes and coordinates',
      (tester) async {
    RoomDimensionsInput? result;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await showDialog<RoomDimensionsInput>(
                context: context,
                builder: (context) => const RoomDimensionsDialog(),
              );
            },
            child: const Text('Open room'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Open room'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('room-name-input')), 'Кухня');
    await tester.enterText(
        find.byKey(const ValueKey('room-width-input')), '4200');
    await tester.enterText(
        find.byKey(const ValueKey('room-length-input')), '3100');
    await tester.enterText(find.byKey(const ValueKey('room-x-input')), '1000');
    await tester.enterText(find.byKey(const ValueKey('room-y-input')), '-500');
    await tester.tap(find.byKey(const ValueKey('room-dimensions-submit')));
    await tester.pumpAndSettle();
    expect(result?.name, 'Кухня');
    expect(result?.widthMm, 4200);
    expect(result?.lengthMm, 3100);
    expect(result?.xMm, 1000);
    expect(result?.yMm, -500);
  });

  testWidgets('room dimensions reject dimensions below minimum',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showDialog<RoomDimensionsInput>(
              context: context,
              builder: (context) => const RoomDimensionsDialog(),
            ),
            child: const Text('Open room'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Open room'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('room-width-input')), '120');
    await tester.tap(find.byKey(const ValueKey('room-dimensions-submit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('room-dimensions-dialog')), findsOneWidget);
    expect(find.text('От 300 до 100 000 мм'), findsOneWidget);
  });
}
