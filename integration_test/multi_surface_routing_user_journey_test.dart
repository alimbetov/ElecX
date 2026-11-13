import 'package:elecx/main.dart' as app;
import 'package:elecx/src/features/editor/spatial_canvas.dart';
import 'package:elecx/src/features/projects/project_hub_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

Future<void> waitForUi(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 300; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) {
      await tester.pumpAndSettle();
      return;
    }
  }
  expect(finder, findsWidgets);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('production UI creates five adjacent rooms and honest P12 review',
      (tester) async {
    WidgetController.hitTestWarningShouldBeFatal = true;
    app.main();
    await tester.pumpAndSettle();
    for (final digit in ['1', '2', '3', '4']) {
      await tester.tap(find.widgetWithText(TextButton, digit));
      await tester.pump(const Duration(milliseconds: 150));
    }
    await waitForUi(tester, find.byKey(const ValueKey('create-project')));
    await tester.tap(find.byKey(const ValueKey('create-project')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('new-project-name')),
        'ElecX Multi-Surface Routing Acceptance');
    await tester.tap(find.byKey(const ValueKey('create-project-confirm')));
    await waitForUi(tester, find.byKey(const ValueKey('wizard-building-name')));
    await tester.enterText(find.byKey(const ValueKey('wizard-building-name')),
        'Residential Building A');
    // The form visibly defaults to a separate Ground. This scenario uses Level 1.
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    final generate = find.byKey(const ValueKey('wizard-generate'));
    await tester.ensureVisible(generate);
    await tester.tap(generate);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('wizard-apply')));
    await waitForUi(tester, find.byType(SpatialCanvas));
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byTooltip('Уменьшить (-)'));
      await tester.pumpAndSettle();
    }
    // Read only the displayed CAD scale; all geometry is authored with clicks.
    final scales = tester
        .widgetList<Text>(find.byType(Text))
        .map((w) => w.data)
        .whereType<String>()
        .where((s) => s.contains('mm/px'));
    final scale = double.parse(
        RegExp(r'([0-9.]+) mm/px').firstMatch(scales.first)!.group(1)!);
    final canvas = tester.getRect(find.byType(SpatialCanvas));
    final origin = canvas.topLeft + const Offset(80, 90);
    // x/y are test inputs in mm. Shared edges are identical click positions.
    // Order: Corridor, Living Room, Bedroom, Kitchen, Bathroom.
    const rooms = [
      Rect.fromLTRB(0, 0, 6000, 1500),
      Rect.fromLTRB(0, 1500, 5000, 5500),
      Rect.fromLTRB(5000, 1500, 9000, 5000),
      Rect.fromLTRB(6000, -1500, 10000, 1500),
      Rect.fromLTRB(3500, -2000, 6000, 0),
    ];
    for (final room in rooms) {
      final start = origin + Offset(room.left / scale, room.top / scale);
      final end = origin + Offset(room.right / scale, room.bottom / scale);
      expect(canvas.contains(start) && canvas.contains(end), isTrue);
      await tester.tap(find.byTooltip('Комната (R)'));
      await tester.pumpAndSettle();
      await tester.tapAt(start);
      await tester.pump();
      await tester.tapAt(end);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(const ValueKey('project-save')));
    await waitForUi(tester, find.text('Проект сохранён'));
    await tester.tap(find.byKey(const ValueKey('p12-review-open')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('p12-review-proposal-unavailable')),
        findsOneWidget);
    expect(
        find.byKey(const ValueKey('p12-review-apply-blocked')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('p12-review-close')));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await waitForUi(tester, find.byType(ProjectHubScreen));
    final resume = find.byWidgetPredicate((w) =>
        w.key is ValueKey<String> &&
        (w.key! as ValueKey<String>).value.startsWith('continue-project-'));
    await waitForUi(tester, resume);
    await tester.ensureVisible(resume);
    await tester.tap(resume);
    await waitForUi(tester, find.byType(SpatialCanvas));
    await tester.tap(find.byIcon(Icons.menu).first);
    await tester.pumpAndSettle();
    for (var i = 1; i <= 5; i++) {
      expect(find.text('Комната $i'), findsWidgets);
    }
    expect(find.text('Level 1'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
