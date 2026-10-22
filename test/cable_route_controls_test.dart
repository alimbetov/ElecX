import 'package:elecx/src/engine/normative_route_engine.dart';
import 'package:elecx/src/features/editor/cable_route_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host({
    RouteConstraintResult? validation,
    bool previewInvalid = false,
  }) => MaterialApp(
    home: Scaffold(
      body: CableRouteControls(
        mode: CableRoutingMode.assisted,
        onModeChanged: (_) {},
        segmentFocused: false,
        segmentLocked: false,
        onToggleSegmentLock: null,
        pointFocused: false,
        pointIsWaypoint: false,
        onToggleWaypoint: null,
        validation: validation,
        previewInvalid: previewInvalid,
      ),
    ),
  );

  testWidgets('invalid semantic preview is exposed as text, not color only', (
    tester,
  ) async {
    await tester.pumpWidget(host(previewInvalid: true));

    expect(find.textContaining('Недопустимый preview'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });

  testWidgets('warning preview exposes engineering reason', (tester) async {
    const message = 'Маршрут содержит лишние повороты.';
    await tester.pumpWidget(
      host(
        validation: const RouteConstraintResult([
          RouteConstraintIssue(
            code: 'route.excessive-bends',
            message: message,
            severity: RouteConstraintSeverity.warning,
          ),
        ]),
      ),
    );

    expect(find.text(message), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  });

  testWidgets('valid preview announces that commit is allowed', (tester) async {
    await tester.pumpWidget(host(validation: const RouteConstraintResult([])));

    expect(find.text('Маршрут допустим к фиксации.'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
  });
}
