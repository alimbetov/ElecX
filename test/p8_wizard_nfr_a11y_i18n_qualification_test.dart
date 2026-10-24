import 'dart:io';
import 'dart:math';

import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/wizard/basic_building_wizard_provider.dart';
import 'package:elecx/src/application/project/wizard/project_wizard_mutation_port.dart';
import 'package:elecx/src/application/project/wizard/wizard_contracts.dart';
import 'package:elecx/src/application/project/wizard/wizard_diff.dart';
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

const _mib = 1024 * 1024;

void main() {
  group('P8 hard NFR qualification', () {
    test('10k semantic diff model stays inside p95/p99 and memory budgets', () {
      // Warm the allocator and sort implementation before measured samples.
      for (var i = 0; i < 3; i++) {
        final warm = _buildDiffModel(1000, seed: i);
        expect(warm.entries, hasLength(1000));
      }

      final samples = <Duration>[];
      WizardDiffModel? retained;
      final rssBefore = ProcessInfo.currentRss;
      for (var run = 0; run < 20; run++) {
        final watch = Stopwatch()..start();
        retained = _buildDiffModel(10000, seed: run + 100);
        watch.stop();
        expect(retained.entries, hasLength(10000));
        expect(
          retained.filtered(query: 'level 9999'),
          isNotEmpty,
          reason: '10k diff search must remain functional',
        );
        samples.add(watch.elapsed);
      }
      final rssAfter = ProcessInfo.currentRss;
      final additionalRss = max(0, rssAfter - rssBefore);

      expect(
        _percentile(samples, 0.95),
        lessThanOrEqualTo(const Duration(seconds: 2)),
        reason: '10k semantic diff p95 budget',
      );
      expect(
        _percentile(samples, 0.99),
        lessThanOrEqualTo(const Duration(milliseconds: 3500)),
        reason: '10k semantic diff p99 budget',
      );
      expect(
        additionalRss,
        lessThanOrEqualTo(150 * _mib),
        reason: '10k semantic diff additional RSS must be <=150 MiB',
      );
      expect(retained, isNotNull);
    });

    test('maximum Basic Building preview-ready stays inside 300/500ms gates', () {
      for (var i = 0; i < 3; i++) {
        _measureMaximumPreview(i + 1);
      }
      final samples = <Duration>[
        for (var i = 0; i < 30; i++) _measureMaximumPreview(i + 1000),
      ];
      final p95 = _percentile(samples, 0.95);
      expect(
        p95,
        lessThanOrEqualTo(const Duration(milliseconds: 300)),
        reason: 'Basic Building <=231 Levels generation p95 budget',
      );
      expect(
        p95,
        lessThanOrEqualTo(const Duration(milliseconds: 500)),
        reason: 'preview-ready p95 budget',
      );
    });

    test('local parameter interaction stays inside 100ms p95 gate', () {
      final project = _project('interaction');
      final session = _session(project, 3001);
      expect(session.begin(), isTrue);
      expect(
        session.selectFamily(BasicBuildingWizardProvider.familyId),
        isTrue,
      );

      final samples = <Duration>[];
      for (var i = 0; i < 200; i++) {
        final watch = Stopwatch()..start();
        final updated = session.updateParameters(
          BasicBuildingWizardParameters(
            buildingName: 'Interaction $i',
            aboveGroundLevelCount: 2,
            basementLevelCount: 1,
            floorToFloorHeightMm: 3000 + i,
          ),
        );
        watch.stop();
        expect(updated, isTrue);
        samples.add(watch.elapsed);
      }
      expect(
        _percentile(samples, 0.95),
        lessThanOrEqualTo(const Duration(milliseconds: 100)),
        reason: 'local Wizard interaction p95 budget',
      );
    });

    test('frozen candidate commit stays inside 3s p95 gate', () {
      final samples = <Duration>[];
      for (var i = 0; i < 20; i++) {
        final project = _project('commit-$i');
        final mutations = ProjectMutationSession(project);
        final port = SharedProjectWizardMutationPort(
          mutations: mutations,
          idFactory: SecureRandomEntityIdFactory(random: Random(4100 + i)),
        );
        final provider = BasicBuildingWizardProvider();
        final command = provider.generateTyped(
          const BasicBuildingWizardParameters(
            buildingName: 'Commit benchmark',
            aboveGroundLevelCount: 200,
            basementLevelCount: 30,
            floorToFloorHeightMm: 3000,
            createGroundLevel: true,
          ),
          WizardGenerationContext(
            target: _target(project),
            project: project,
          ),
        );
        final preview = port.preview(command);
        final watch = Stopwatch()..start();
        final result = port.commitPreview(preview);
        watch.stop();
        expect(result.after.stores.levels, hasLength(231));
        samples.add(watch.elapsed);
      }
      expect(
        _percentile(samples, 0.95),
        lessThanOrEqualTo(const Duration(seconds: 3)),
        reason: 'commit excluding storage synchronization p95 budget',
      );
    });
  });

  group('P8 RU/EN localization qualification', () {
    for (final locale in ProjectWizardLocalizations.supportedLocales) {
      testWidgets('Wizard resources render completely for ${locale.languageCode}',
          (tester) async {
        final session = _session(
          _project('locale-${locale.languageCode}'),
          locale.languageCode == 'ru' ? 5101 : 5102,
        );
        await tester.pumpWidget(
          _localizedApp(locale: locale, session: session),
        );
        await tester.pumpAndSettle();

        if (locale.languageCode == 'ru') {
          expect(find.text('Создание здания'), findsOneWidget);
          expect(find.text('Параметры'), findsWidgets);
          expect(find.text('Сформировать'), findsOneWidget);
          expect(find.text('Отмена'), findsOneWidget);
        } else {
          expect(find.text('Create building'), findsOneWidget);
          expect(find.text('Parameters'), findsWidgets);
          expect(find.text('Generate'), findsOneWidget);
          expect(find.text('Cancel'), findsOneWidget);
        }

        await tester.tap(find.byKey(const ValueKey('wizard-generate')));
        await tester.pumpAndSettle();
        if (locale.languageCode == 'ru') {
          expect(find.text('Применить всё'), findsOneWidget);
          expect(find.textContaining('Изменения ('), findsOneWidget);
        } else {
          expect(find.text('Apply all'), findsOneWidget);
          expect(find.textContaining('Changes ('), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('P8 screen-reader semantics matrix', () {
    for (final locale in ProjectWizardLocalizations.supportedLocales) {
      for (final width in <double>[390, 900, 1440]) {
        testWidgets(
            'primary semantics ${locale.languageCode} at ${width.toInt()}dp',
            (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, 900);
          addTearDown(() {
            tester.view.resetDevicePixelRatio();
            tester.view.resetPhysicalSize();
          });
          final semantics = tester.ensureSemantics();
          addTearDown(semantics.dispose);
          final session = _session(
            _project('sem-${locale.languageCode}-${width.toInt()}'),
            6000 + width.toInt(),
          );
          await tester.pumpWidget(
            _localizedApp(locale: locale, session: session),
          );
          await tester.pumpAndSettle();

          final generateNode = tester.getSemantics(
            find.byKey(const ValueKey('wizard-generate')),
          );
          final cancelNode = tester.getSemantics(
            find.byKey(const ValueKey('wizard-cancel')),
          );
          final nameNode = tester.getSemantics(
            find.byKey(const ValueKey('wizard-building-name')),
          );
          expect(generateNode.hasFlag(SemanticsFlag.isButton), isTrue);
          expect(cancelNode.hasFlag(SemanticsFlag.isButton), isTrue);
          expect(nameNode.hasFlag(SemanticsFlag.isTextField), isTrue);
          expect(generateNode.label, isNotEmpty);
          expect(cancelNode.label, isNotEmpty);
          expect(nameNode.label, isNotEmpty);

          await tester.tap(find.byKey(const ValueKey('wizard-generate')));
          await tester.pumpAndSettle();
          final applyNode = tester.getSemantics(
            find.byKey(const ValueKey('wizard-apply')),
          );
          expect(applyNode.hasFlag(SemanticsFlag.isButton), isTrue);
          expect(applyNode.label, isNotEmpty);
          expect(find.byType(WizardPreviewCanvas), findsOneWidget);
          final previewNode = tester.getSemantics(
            find.byType(WizardPreviewCanvas),
          );
          expect(previewNode.hasFlag(SemanticsFlag.isImage), isTrue);
          expect(previewNode.label, isNotEmpty);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('P8 text scaling matrix', () {
    for (final scale in <double>[1.0, 1.3, 2.0]) {
      for (final width in <double>[390, 900, 1440]) {
        testWidgets('text scale $scale at ${width.toInt()}dp has no overflow',
            (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, 1000);
          addTearDown(() {
            tester.view.resetDevicePixelRatio();
            tester.view.resetPhysicalSize();
          });
          final session = _session(
            _project('scale-$scale-${width.toInt()}'),
            7000 + width.toInt() + (scale * 10).round(),
          );
          await tester.pumpWidget(
            _localizedApp(
              locale: const Locale('en'),
              session: session,
              textScale: scale,
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byKey(const ValueKey('wizard-generate')), findsOneWidget);
          expect(find.byKey(const ValueKey('wizard-cancel')), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  testWidgets('reduced-motion carousel changes selection without animation',
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
        locale: const Locale('en'),
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
  });
}

Widget _localizedApp({
  required Locale locale,
  required WizardSession session,
  double textScale = 1,
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

WizardDiffModel _buildDiffModel(int count, {required int seed}) {
  final random = Random(seed);
  return WizardDiffModel(
    List<WizardDiffEntry>.generate(
      count,
      (index) => WizardDiffEntry(
        kind: WizardDiffKind.update,
        category: WizardDiffEntityCategory.level,
        title: 'Level $index',
        semanticKey: 'level:${index.toString().padLeft(5, '0')}',
        sortKey:
            '2|${random.nextInt(count * 2).toString().padLeft(6, '0')}|$index',
        fields: [
          WizardFieldChange(
            field: 'Elevation',
            beforeValue: '${index * 3000} mm',
            afterValue: '${index * 3000 + 10} mm',
          ),
        ],
      ),
    ),
  );
}

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
  final projectId = ProjectId('p8-nfr-project-$suffix');
  final siteId = SiteId('p8-nfr-site-$suffix');
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
