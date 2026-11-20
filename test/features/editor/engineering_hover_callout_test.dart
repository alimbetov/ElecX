import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/features/editor/engineering_hover_callout.dart';

void main() {
  const socket = EngineeringHoverInfo(
    id: 's1',
    type: ElectricalComponentType.socketOutlet,
    label: 'SK-01',
    anchor: Offset(130, 120),
    room: 'Гостиная',
  );
  const board = EngineeringHoverInfo(
    id: 'p1',
    type: ElectricalComponentType.distributionBoard,
    label: 'DB-01',
    anchor: Offset(400, 100),
  );

  testWidgets('delayed show, single target switch, and hide on exit',
      (tester) async {
    EngineeringHoverInfo? target = socket;
    late StateSetter update;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(builder: (context, setState) {
          update = setState;
          return SizedBox(
            width: 600,
            height: 400,
            child: EngineeringHoverCallout(
              target: target,
              viewportSize: const Size(600, 400),
            ),
          );
        }),
      ),
    ));

    expect(find.text('Розетка · SK-01'), findsNothing);
    await tester.pump(const Duration(milliseconds: 149));
    expect(find.text('Розетка · SK-01'), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('Розетка · SK-01'), findsOneWidget);
    expect(find.text('Гостиная'), findsOneWidget);

    update(() => target = board);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('Электрощит · DB-01'), findsOneWidget);
    expect(find.text('Гостиная'), findsNothing);

    update(() => target = null);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 130));
    expect(find.text('Электрощит · DB-01'), findsNothing);
  });

  testWidgets('short hover is canceled without appearing', (tester) async {
    EngineeringHoverInfo? target = socket;
    late StateSetter update;
    await tester.pumpWidget(MaterialApp(
      home: StatefulBuilder(builder: (context, setState) {
        update = setState;
        return EngineeringHoverCallout(
          target: target,
          viewportSize: const Size(400, 300),
        );
      }),
    ));
    await tester.pump(const Duration(milliseconds: 80));
    update(() => target = null);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));
    expect(find.text('Розетка · SK-01'), findsNothing);
  });

  testWidgets('reduced motion disables pulse', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: EngineeringHoverCallout(
          target: socket,
          viewportSize: Size(400, 300),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('Розетка · SK-01'), findsOneWidget);
  });
}
