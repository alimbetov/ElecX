import 'dart:math';

import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/wizard/basic_building_wizard_provider.dart';
import 'package:elecx/src/application/project/wizard/project_wizard_mutation_port.dart';
import 'package:elecx/src/application/project/wizard/wizard_contracts.dart';
import 'package:elecx/src/application/project/wizard/wizard_preview_scene.dart';
import 'package:elecx/src/application/project/wizard/wizard_session.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/features/projects/project_wizard_localizations.dart';
import 'package:elecx/src/features/projects/project_wizard_screen.dart';
import 'package:elecx/src/features/projects/wizard_candidate_carousel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maximum Basic Building preview-ready stays inside 500ms p99 gate', () {
    for (var i = 0; i < 3; i++) {
      _measureMaximumPreview(i + 9000);
    }

    final samples = <Duration>[
      for (var i = 0; i < 101; i++) _measureMaximumPreview(i + 10000),
    ];

    expect(
      _percentile(samples, 0.99),
      lessThanOrEqualTo(const Duration(milliseconds: 500)),
      reason: 'Basic Building preview-ready p99 budget',
    );
  });

  group('P8 RU/EN text scaling matrix', () {
    for (final locale in ProjectWizardLocalizations.supportedLocales) {
      for (final scale in <double>[1.0, 1.3, 2.0]) {
        for (final width in <double>[390, 900, 1440]) {
          testWidgets(
            '${locale.languageCode} text scale $scale at ${width.toInt()}dp has no overflow',
            (tester) async {
              tester.view.devicePixelRatio = 1;
              tester.view.physicalSize = Size(width, 1000);
              addTearDown(() {
                tester.view.resetDevicePixelRatio();
                tester.view.resetPhysicalSize();
              });

              final session = _session(
                _project(
                  'scale-${locale.languageCode}-$scale-${width.toInt()}',
                ),
                11000 +
                    width.toInt() +
                    (scale * 10).round() +
                    (locale.languageCode == 'ru' ? 1000 : 0),
              );

              await tester.pumpWidget(
                _localizedApp(
                  locale: locale,
                  session: session,
                  textScale: scale,
                ),
              );
              await tester.pumpAndSettle();

              expect(
                find.byKey(const ValueKey('wizard-cancel')),
                findsOneWidget,
              );
              expect(tester.takeException(), isNull);

              final parameterList = find.byType(ListView).first;
              await tester.drag(parameterList, const Offset(0, -1000));
              await tester.pumpAndSettle();
              expect(
                find.byKey(const ValueKey('wizard-generate')),
                findsOneWidget,
              );
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }
  });

  group('P8 RU/EN reduced-motion matrix', () {
    for (final locale in ProjectWizardLocalizations.supportedLocales) {
      testWidgets(
        '${locale.languageCode} carousel changes selection without animation',
        (tester) async {
          var selected = 'a';
          final scene = WizardPreviewScene(
            width: 100,
            height: 100,
            semanticLabel: 'preview',
            elements: const [
              WizardPreviewRect(
                key: 'frame',
                role: WizardPreviewRole.buildingFrame,
                x: 0,
                y: 0,
                width: 100,
                height: 100,
              ),
            ],
          );
          final candidates = [
            WizardCandidateCard(id: 'a', title: 'A', scene: scene),
            WizardCandidateCard(id: 'b', title: 'B', scene: scene),
          ];

          await tester.pumpWidget(
            MaterialApp(
              locale: locale,
              supportedLocales: ProjectWizardLocalizations.supportedLocales,
              localizationsDelegates:
                  ProjectWizardLocalizations.localizationsDelegates,
              home: MediaQuery(
                data: const MediaQueryData(disableAnimations: true),
                child: Scaffold(
                  body: StatefulBuilder(
                    builder: (context, setState) => WizardCandidateCarousel(
                      candidates: candidates,
                      selectedId: selected,
                      onSelected: (id) => setState(() => selected = id),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.sendKeyEvent(LogicalKeyboardKey.end);
          await tester.pump();

          expect(selected, 'b');
          expect(tester.binding.transientCallbackCount, 0);
          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}

Widget _localizedApp({
  required Locale locale,
  required WizardSession session,
  required double textScale,
}) =>
    MaterialApp(
      locale: locale,
      supportedLocales: ProjectWizardLocalizations.supportedLocales,
      localizationsDelegates: ProjectWizardLocalizations.localizationsDelegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: ProjectWizardScreen(session: session),
    );

Duration _measureMaximumPreview(int seed) {
  final project = _project('max-$seed');
  final mutations = ProjectMutationSession(project);
  final port = SharedProjectWizardMutationPort(
    mutations: mutations,
    idFactory: SecureRandomEntityIdFactory(random: Random(seed)),
  );
  final provider = BasicBuildingWizardProvider();
  final watch = Stopwatch()..start();
  final preview = port.preview(
    provider.generateTyped(
      const BasicBuildingWizardParameters(
        buildingName: 'Maximum Building',
        aboveGroundLevelCount: 200,
        basementLevelCount: 30,
        floorToFloorHeightMm: 3000,
        createGroundLevel: true,
      ),
      WizardGenerationContext(
        target: _target(project),
        project: project,
      ),
    ),
  );
  watch.stop();
  expect(preview.candidate.stores.levels, hasLength(231));
  return watch.elapsed;
}

Duration _percentile(List<Duration> samples, double percentile) {
  final sorted = samples.map((value) => value.inMicroseconds).toList()..sort();
  final index = ((sorted.length - 1) * percentile).ceil();
  return Duration(microseconds: sorted[index]);
}

WizardSession _session(ProjectAggregateRoot project, int seed) => WizardSession(
      target: _target(project),
      registry: WizardProviderRegistry([BasicBuildingWizardProvider()]),
      mutations: SharedProjectWizardMutationPort(
        mutations: ProjectMutationSession(project),
        idFactory: SecureRandomEntityIdFactory(random: Random(seed)),
      ),
    );

SiteWizardTarget _target(ProjectAggregateRoot project) => SiteWizardTarget(
      projectId: project.id,
      siteId: project.siteId,
      baseVersion: project.version,
    );

ProjectAggregateRoot _project(String suffix) {
  final projectId = ProjectId('p8-r23-project-$suffix');
  final siteId = SiteId('p8-r23-site-$suffix');
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
