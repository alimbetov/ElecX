import 'package:elecx/src/features/projects/apartment_engineering_preview_panel.dart';
import 'package:elecx/src/features/projects/project_wizard_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Q107 topology-only engineering state is localized in Russian',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('ru'),
        supportedLocales: ProjectWizardLocalizations.supportedLocales,
        localizationsDelegates:
            ProjectWizardLocalizations.localizationsDelegates,
        home: Scaffold(
          body: SizedBox(
            width: 900,
            height: 700,
            child: ApartmentEngineeringPreviewPanel(proposal: null),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('apartment-engineering-topology-only')),
      findsOneWidget,
    );
    expect(find.text('Предпросмотр только топологии'), findsOneWidget);
    expect(
      find.textContaining('Электрические параметры не предполагаются'),
      findsOneWidget,
    );
    expect(find.text('Topology-only preview'), findsNothing);
  });
}
