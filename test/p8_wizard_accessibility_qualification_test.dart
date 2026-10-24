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
  for (final width in <double>[599, 900, 1400]) {
    testWidgets(
        'Wizard primary touch targets are at least 48dp at width $width',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 900);
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.view.resetPhysicalSize();
      });

      final project = _project('touch-${width.toInt()}');
      final session = WizardSession(
        target: SiteWizardTarget(
          projectId: project.id,
          siteId: project.siteId,
          baseVersion: project.version,
        ),
        registry: WizardProviderRegistry([BasicBuildingWizardProvider()]),
        mutations: SharedProjectWizardMutationPort(
          mutations: ProjectMutationSession(project),
          idFactory: SecureRandomEntityIdFactory(
            random: Random(9200 + width.toInt()),
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(home: ProjectWizardScreen(session: session)),
      );
      await tester.pumpAndSettle();

      for (final key in <String>['wizard-generate', 'wizard-cancel']) {
        final size = tester.getSize(find.byKey(ValueKey(key)));
        expect(
          size.height,
          greaterThanOrEqualTo(48),
          reason: '$key height at width $width is ${size.height}',
        );
        expect(
          size.width,
          greaterThanOrEqualTo(48),
          reason: '$key width at width $width is ${size.width}',
        );
      }

      await tester.tap(find.byKey(const ValueKey('wizard-generate')));
      await tester.pumpAndSettle();
      final applySize = tester.getSize(
        find.byKey(const ValueKey('wizard-apply')),
      );
      expect(applySize.height, greaterThanOrEqualTo(48));
      expect(applySize.width, greaterThanOrEqualTo(48));
    });
  }
}

ProjectAggregateRoot _project(String suffix) {
  final projectId = ProjectId('p8-accessibility-project-$suffix');
  final siteId = SiteId('p8-accessibility-site-$suffix');
  return ProjectAggregateRoot(
    id: projectId,
    siteId: siteId,
    version: LocalProjectVersion(0),
    stores: ProjectEntityStores(
      sites: {
        siteId: ProjectSiteEntity(
          id: siteId,
          name: 'Site $suffix',
          buildingIds: const <BuildingId>{},
        ),
      },
    ),
  );
}
