import 'dart:async';

import 'package:elecx/src/features/editor/project_structure_authoring_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P5C ProjectStructureAuthoringControls', () {
    testWidgets('desktop baseline exposes discoverable labeled actions', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProjectStructureAuthoringControls(
              onAddBuilding: () {},
              onAddLevel: () {},
              onAddRoom: () {},
            ),
          ),
        ),
      );

      expect(find.text('+ Building'), findsOneWidget);
      expect(find.text('+ Level'), findsOneWidget);
      expect(find.text('+ Room'), findsOneWidget);
      expect(find.byType(OutlinedButton), findsNWidgets(3));
    });

    testWidgets('disabled callbacks produce disabled authoring buttons', (
      tester,
    ) async {
      var buildingCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProjectStructureAuthoringControls(
              onAddBuilding: () => buildingCalls++,
              onAddLevel: null,
              onAddRoom: null,
            ),
          ),
        ),
      );

      await tester.tap(find.text('+ Building'));
      await tester.pump();
      expect(buildingCalls, 1);

      final levelButton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, '+ Level'),
      );
      final roomButton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, '+ Room'),
      );
      expect(levelButton.onPressed, isNull);
      expect(roomButton.onPressed, isNull);
    });

    testWidgets('one async authoring action disables every structural action', (
      tester,
    ) async {
      final release = Completer<void>();
      var roomCalls = 0;
      var buildingCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProjectStructureAuthoringControls(
              onAddBuilding: () => buildingCalls++,
              onAddLevel: () {},
              onAddRoom: () async {
                roomCalls++;
                await release.future;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('+ Room'));
      await tester.pump();

      expect(roomCalls, 1);
      for (final label in ['+ Building', '+ Level', '+ Room']) {
        final button = tester.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, label),
        );
        expect(button.onPressed, isNull, reason: '$label must be serialized');
      }

      await tester.tap(find.text('+ Building'), warnIfMissed: false);
      await tester.pump();
      expect(buildingCalls, 0);

      release.complete();
      await tester.pumpAndSettle();

      final buildingButton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, '+ Building'),
      );
      expect(buildingButton.onPressed, isNotNull);
    });

    testWidgets('compact mode keeps all primary actions available', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProjectStructureAuthoringControls(
              compact: true,
              onAddBuilding: () {},
              onAddLevel: () {},
              onAddRoom: () {},
            ),
          ),
        ),
      );

      expect(find.byType(Wrap), findsOneWidget);
      expect(find.text('+ Building'), findsOneWidget);
      expect(find.text('+ Level'), findsOneWidget);
      expect(find.text('+ Room'), findsOneWidget);
    });
  });
}
