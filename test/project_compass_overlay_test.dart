import 'package:elecx/src/domain/project_orientation.dart';
import 'package:elecx/src/features/editor/project_compass_overlay.dart';
import 'package:elecx/src/features/editor/project_compass_projection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('unavailable projection renders no directional overlay',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProjectCompassOverlay(
            state: CompassUnavailable(),
          ),
        ),
      ),
    );

    expect(find.byType(CustomPaint), findsNothing);
    expect(find.bySemanticsLabel(RegExp('Compass')), findsNothing);
  });

  testWidgets('unspecified north is explicit and read-only passes pointers',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProjectCompassOverlay(
            state: CompassNorthUnspecified(),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel('Compass, Project North not set'),
      findsOneWidget,
    );
    expect(find.byType(IgnorePointer), findsOneWidget);
    expect(find.byType(InkWell), findsNothing);
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
    expect(find.byType(InkWell), findsOneWidget);

    await tester.tap(find.byType(InkWell));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('legacy compatibility input cannot fabricate a projection',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProjectCompassOverlay(
            projectNorth: Object(),
          ),
        ),
      ),
    );

    expect(find.byType(CustomPaint), findsNothing);
  });
}
