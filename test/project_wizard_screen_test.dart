import 'dart:math';

import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/wizard/basic_building_wizard_provider.dart';
import 'package:elecx/src/application/project/wizard/project_wizard_mutation_port.dart';
import 'package:elecx/src/application/project/wizard/wizard_contracts.dart';
import 'package:elecx/src/application/project/wizard/wizard_session.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/features/projects/project_wizard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('responsive Wizard keeps exact frozen preview across resize',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(500, 900);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    final project = _project();
    final mutations = ProjectMutationSession(project);
    final session = WizardSession(
      target: SiteWizardTarget(
        projectId: project.id,
        siteId: project.siteId,
        baseVersion: project.version,
      ),
      registry: WizardProviderRegistry([BasicBuildingWizardProvider()]),
      mutations: SharedProjectWizardMutationPort(
        mutations: mutations,
        idFactory: SecureRandomEntityIdFactory(random: Random(607)),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: ProjectWizardScreen(session: session)),
    );
    expect(find.byKey(const ValueKey('wizard-building-name')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('wizard-generate')));
    await tester.pumpAndSettle();

    final frozen = session.preview;
    expect(frozen, isNotNull);
    final buildingId = frozen!.reservation.entityId<BuildingId>('building');
    expect(session.status, WizardSessionStatus.previewReady);

    tester.view.physicalSize = const Size(1500, 900);
    await tester.pumpAndSettle();

    expect(identical(session.preview, frozen), isTrue);
    expect(
      session.preview!.reservation.entityId<BuildingId>('building'),
      buildingId,
    );
    expect(find.byKey(const ValueKey('wizard-diff-list')), findsOneWidget);
    expect(find.text('Применить всё'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('wizard-apply')));
    await tester.pump();
    expect(session.status, WizardSessionStatus.completed);
    expect(mutations.current.stores.buildings.keys, contains(buildingId));
    expect(mutations.canUndo, isTrue);
  });
}

ProjectAggregateRoot _project() {
  final projectId = ProjectId('wizard-responsive-project');
  final siteId = SiteId('wizard-responsive-site');
  return ProjectAggregateRoot(
    id: projectId,
    siteId: siteId,
    version: LocalProjectVersion(0),
    stores: ProjectEntityStores(
      sites: {
        siteId: ProjectSiteEntity(
          id: siteId,
          name: 'Site',
          buildingIds: const <BuildingId>{},
        ),
      },
    ),
  );
}
