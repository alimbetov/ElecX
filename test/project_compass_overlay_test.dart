import 'package:elecx/src/domain/project_orientation.dart';
import 'package:elecx/src/features/editor/project_compass_overlay.dart';
import 'package:elecx/src/features/editor/project_compass_projection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('unavailable projection renders no directional overlay',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProjectCompassOverlay(
            state: const CompassUnavailable(),
          ),
        ),
      ),
    );

    final overlay = find.byType(ProjectCompassOverlay);
    expect(
      find.descendant(
        of: overlay,
        matching: find.byKey(const ValueKey('project-compass-paint')),
      ),
      findsNothing,
    );
    expect(find.bySemanticsLabel(RegExp('Compass')), findsNothing);
  });

  testWidgets('unspecified north is explicit and read-only passes pointers',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProjectCompassOverlay(
            state: const CompassNorthUnspecified(),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel('Compass, Project North not set'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('project-compass-read-only')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('project-compass-action')),
      findsNothing,
    );
  });

  testWidgets('defined north exposes canonical semantics and interaction',
      (tester) async {
    var taps = 0;
    final north = ProjectEngineeringNorth.fromDegrees(32.5);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProjectCompassOverlay(
            state: CompassNorthDefined(
              canonicalNorth: north,
              screenMilliDegreesClockwiseFromUp: 32500,
            ),
            onTap: () => taps += 1,
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        'Compass, Project North 32.5 degrees clockwise from project up',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('project-compass-action')),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('project-compass-paint'))),
      const Size.square(74),
    );

    await tester.tap(find.byKey(const ValueKey('project-compass-action')));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('defined compass renders in light and dark themes',
      (tester) async {
    final north = ProjectEngineeringNorth.fromDegrees(90);

    for (final mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: mode,
          home: Scaffold(
            body: ProjectCompassOverlay(
              state: CompassNorthDefined(
                canonicalNorth: north,
                screenMilliDegreesClockwiseFromUp: 90000,
              ),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('project-compass-paint')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
  });

  test('invalid overlay size fails closed at construction', () {
    expect(
      () => ProjectCompassOverlay(
        state: const CompassNorthUnspecified(),
        size: 0,
      ),
      throwsArgumentError,
    );
  });
}
