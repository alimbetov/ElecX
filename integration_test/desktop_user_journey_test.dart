import 'package:elecx/main.dart' as app;
import 'package:elecx/src/features/editor/spatial_canvas.dart';
import 'package:elecx/src/features/editor/unified_workspace_editor_screen.dart';
import 'package:elecx/src/features/projects/project_hub_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

Future<void> waitFor(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 300; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  expect(finder, findsWidgets);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native UI creates project, previews building and saves rooms',
      (tester) async {
    app.main();
    await tester.pumpAndSettle();
    for (final digit in ['1', '2', '3', '4']) {
      await tester.tap(find.widgetWithText(TextButton, digit));
      await tester.pump(const Duration(milliseconds: 150));
    }
    await tester.pumpAndSettle();
    expect(find.byType(ProjectHubScreen), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('create-project')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('new-project-name')),
        'ElecX Residential Acceptance');
    await tester.tap(find.byKey(const ValueKey('create-project-confirm')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('wizard-building-name')), 'Building A');
    final generate = find.byKey(const ValueKey('wizard-generate'));
    await tester.ensureVisible(generate);
    await tester.tap(generate);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('wizard-diff-list'), skipOffstage: false),
        findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('wizard-apply')));
    await tester.pumpAndSettle();
    expect(find.byType(UnifiedWorkspaceEditorScreen), findsOneWidget);
    final canvas = find.byType(SpatialCanvas);
    final rect = tester.getRect(canvas);
    for (final offset in [
      const Offset(.15, .15),
      const Offset(.5, .15),
      const Offset(.15, .4),
      const Offset(.5, .4),
    ]) {
      await tester.tap(find.byTooltip('Комната (R)'));
      await tester.pumpAndSettle();
      final start = rect.topLeft +
          Offset(rect.width * offset.dx, rect.height * offset.dy);
      await tester.tapAt(start);
      await tester.pump();
      await tester.tapAt(start + Offset(rect.width * .22, rect.height * .15));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byTooltip('Сохранить проект'));
    await waitFor(tester, find.text('Проект сохранён'));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(ProjectHubScreen), findsOneWidget);
    final continueProject = find.byWidgetPredicate((widget) {
      final key = widget.key;
      return key is ValueKey<String> &&
          key.value.startsWith('continue-project-');
    });
    await waitFor(tester, continueProject);
    await tester.ensureVisible(continueProject);
    await tester.tap(continueProject);
    await tester.pumpAndSettle();
    expect(find.byType(UnifiedWorkspaceEditorScreen), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('p12-review-open')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('p12-review-dialog')), findsOneWidget);
    expect(find.byKey(const ValueKey('p12-review-panel')), findsOneWidget);
    expect(find.byKey(const ValueKey('p12-review-apply-blocked')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('p12-review-diff-unavailable')),
        findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('p12-review-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('p12-review-dialog')), findsNothing);
    await tester.tap(find.byIcon(Icons.menu).first);
    await tester.pumpAndSettle();
    for (var number = 1; number <= 4; number++) {
      expect(find.text('Комната $number'), findsWidgets);
    }
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('project-inspector-open')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('engineering-context-scroll')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
