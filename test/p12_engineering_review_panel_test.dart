import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elecx/src/domain/canonical_power_selection.dart';
import 'package:elecx/src/features/editor/p12_engineering_review_panel.dart';

import 'support/p1010_service_anchor_fixture.dart';

void main() {
  testWidgets('P12 review reports missing canonical runtime honestly',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: P12EngineeringReviewPanel(project: null),
        ),
      ),
    ));
    expect(find.byKey(const ValueKey('p12-review-no-project')), findsOneWidget);
    expect(find.byKey(const ValueKey('p12-review-apply-blocked')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('p12-review-project-version')),
        findsNothing);
  });

  testWidgets('P12 review inspects project-owned state, no invented diff',
      (tester) async {
    final project = P1010ServiceAnchorFixture().project;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: P12EngineeringReviewPanel(project: project),
        ),
      ),
    ));
    expect(find.byKey(const ValueKey('p12-review-project-version')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('p12-review-circuit-count')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('p12-review-selection-count')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('p12-review-rcd-count')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('p12-review-diff-unavailable')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('p12-review-apply-blocked')),
        findsOneWidget);
  });

  testWidgets('P12 diff is only shown when frozen baseline is supplied',
      (tester) async {
    final project = P1010ServiceAnchorFixture().project;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: P12EngineeringReviewPanel(
            project: project,
            baselineSelections: const CanonicalPowerSelectionRegistry.empty(),
          ),
        ),
      ),
    ));
    expect(find.byKey(const ValueKey('p12-review-diff-unavailable')),
        findsNothing);
    expect(find.byKey(const ValueKey('p12-review-diff-empty')),
        findsOneWidget);
  });
}
