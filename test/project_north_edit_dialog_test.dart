import 'package:elecx/src/domain/project_orientation.dart';
import 'package:elecx/src/features/editor/project_north_edit_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('invalid input stays open and exposes validation text',
      (tester) async {
    ProjectEngineeringNorth? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await showDialog<ProjectEngineeringNorth>(
                context: context,
                builder: (_) => const ProjectNorthEditDialog(
                  initialValue: null,
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('project-north-angle-input')),
      'not-a-number',
    );
    await tester.tap(find.byKey(const ValueKey('apply-project-north')));
    await tester.pump();

    expect(find.byKey(const ValueKey('project-north-dialog')), findsOneWidget);
    expect(
        find.text('Введите конечное числовое значение угла.'), findsOneWidget);
    expect(result, isNull);
  });

  testWidgets('valid value closes cleanly and returns canonical north',
      (tester) async {
    ProjectEngineeringNorth? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await showDialog<ProjectEngineeringNorth>(
                context: context,
                builder: (_) => ProjectNorthEditDialog(
                  initialValue: ProjectEngineeringNorth.fromDegrees(90),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('project-north-angle-input')),
      '32,5',
    );
    await tester.tap(find.byKey(const ValueKey('apply-project-north')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('project-north-dialog')), findsNothing);
    expect(result?.degrees, 32.5);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancel returns no value and performs no implicit mutation',
      (tester) async {
    ProjectEngineeringNorth? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await showDialog<ProjectEngineeringNorth>(
                context: context,
                builder: (_) => ProjectNorthEditDialog(
                  initialValue: ProjectEngineeringNorth.fromDegrees(12),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cancel-project-north')));
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(tester.takeException(), isNull);
  });
}
