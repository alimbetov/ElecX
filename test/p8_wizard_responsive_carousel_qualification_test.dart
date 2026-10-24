import 'dart:math';

import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/wizard/basic_building_wizard_provider.dart';
import 'package:elecx/src/application/project/wizard/project_wizard_mutation_port.dart';
import 'package:elecx/src/application/project/wizard/wizard_contracts.dart';
import 'package:elecx/src/application/project/wizard/wizard_preview_scene.dart';
import 'package:elecx/src/application/project/wizard/wizard_session.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/features/projects/project_wizard_screen.dart';
import 'package:elecx/src/features/projects/wizard_candidate_carousel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'all responsive breakpoint crossings preserve frozen preview and history',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(599, 900);
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.view.resetPhysicalSize();
      });

      final project = _project('breakpoints');
      final mutations = ProjectMutationSession(project);
      final session = _session(project, mutations, 811);

      await tester.pumpWidget(
        MaterialApp(home: ProjectWizardScreen(session: session)),
      );
      await tester.tap(find.byKey(const ValueKey('wizard-generate')));
      await tester.pumpAndSettle();

      final frozen = session.preview!;
      final frozenBuildingId =
          frozen.reservation.entityId<BuildingId>('building');
      expect(mutations.current.version.value, 0);
      expect(mutations.undoDepth, 0);

      for (final width in <double>[600, 899, 900, 1399, 1400, 900, 600, 599]) {
        tester.view.physicalSize = Size(width, 900);
        await tester.pumpAndSettle();

        expect(
          identical(session.preview, frozen),
          isTrue,
          reason: 'Preview regenerated while crossing width $width.',
        );
        expect(
          session.preview!.reservation.entityId<BuildingId>('building'),
          frozenBuildingId,
          reason: 'Reserved identity changed at width $width.',
        );
        expect(mutations.current.version.value, 0);
        expect(mutations.undoDepth, 0);
      }
    },
  );

  testWidgets('non-numeric UI input fails before Wizard mutation preview',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(500, 900);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    final project = _project('invalid-input');
    final mutations = ProjectMutationSession(project);
    final session = _session(project, mutations, 821);

    await tester.pumpWidget(
      MaterialApp(home: ProjectWizardScreen(session: session)),
    );
    await tester.enterText(
      find.byKey(const ValueKey('wizard-floor-count')),
      'not-a-number',
    );
    await tester.tap(find.byKey(const ValueKey('wizard-generate')));
    await tester.pump();

    expect(
      find.text('Количество этажей и высота должны быть числами.'),
      findsOneWidget,
    );
    expect(session.preview, isNull);
    expect(mutations.current.version.value, 0);
    expect(mutations.undoDepth, 0);
  });

  testWidgets('carousel keyboard navigation clamps and selects stable ids',
      (tester) async {
    var selectedId = 'candidate-b';
    late StateSetter updateHost;
    final candidates = _cards();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              updateHost = setState;
              return SizedBox(
                width: 700,
                height: 500,
                child: WizardCandidateCarousel(
                  candidates: candidates,
                  selectedId: selectedId,
                  onSelected: (id) {
                    selectedId = id;
                    updateHost(() {});
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(selectedId, 'candidate-c');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(selectedId, 'candidate-c');

    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pumpAndSettle();
    expect(selectedId, 'candidate-a');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(selectedId, 'candidate-a');

    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pumpAndSettle();
    expect(selectedId, 'candidate-c');
  });

  testWidgets('carousel swipe converges on the same stable candidate selection',
      (tester) async {
    var selectedId = 'candidate-a';
    final candidates = _cards();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SizedBox(
              width: 700,
              height: 500,
              child: WizardCandidateCarousel(
                candidates: candidates,
                selectedId: selectedId,
                onSelected: (id) => setState(() => selectedId = id),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(PageView), const Offset(-600, 0));
    await tester.pumpAndSettle();

    expect(selectedId, 'candidate-b');
  });
}

List<WizardCandidateCard> _cards() => [
      for (final suffix in <String>['a', 'b', 'c'])
        WizardCandidateCard(
          id: 'candidate-$suffix',
          title: 'Candidate ${suffix.toUpperCase()}',
          scene: WizardPreviewScene(
            width: 200,
            height: 120,
            semanticLabel: 'Candidate $suffix preview',
            elements: [
              WizardPreviewRect(
                key: 'rect-$suffix',
                role: WizardPreviewRole.buildingFrame,
                x: 10,
                y: 10,
                width: 180,
                height: 100,
              ),
            ],
          ),
        ),
    ];

WizardSession _session(
  ProjectAggregateRoot project,
  ProjectMutationSession mutations,
  int randomSeed,
) =>
    WizardSession(
      target: SiteWizardTarget(
        projectId: project.id,
        siteId: project.siteId,
        baseVersion: project.version,
      ),
      registry: WizardProviderRegistry([BasicBuildingWizardProvider()]),
      mutations: SharedProjectWizardMutationPort(
        mutations: mutations,
        idFactory: SecureRandomEntityIdFactory(random: Random(randomSeed)),
      ),
    );

ProjectAggregateRoot _project(String suffix) {
  final projectId = ProjectId('p8-responsive-$suffix');
  final siteId = SiteId('p8-responsive-site-$suffix');
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
