import 'package:elecx/src/features/editor/cable_trajectory_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('selected cable shows actual endpoints and physical lengths',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CableTrajectorySummary(
            sourceLabel: 'Щит ЩР',
            targetLabel: 'Розетка 1',
            geometricLengthMm: 5100,
            installationLengthMm: 5355,
            segmentCount: 3,
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('trajectory-selected-summary')),
      findsOneWidget,
    );
    expect(find.text('Откуда: Щит ЩР'), findsOneWidget);
    expect(find.text('Куда: Розетка 1'), findsOneWidget);
    expect(find.text('Геометрическая длина: 5100 мм'), findsOneWidget);
    expect(find.text('Монтажная длина: 5355 мм'), findsOneWidget);
    expect(find.text('Участков: 3'), findsOneWidget);
  });
}
