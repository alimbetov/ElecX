import 'dart:math';

import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_candidate_set_service.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_wizard_parameters.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_wizard_provider.dart';
import 'package:elecx/src/application/project/wizard/project_wizard_mutation_port.dart';
import 'package:elecx/src/application/project/wizard/wizard_contracts.dart';
import 'package:elecx/src/application/project/wizard/wizard_diff.dart';
import 'package:elecx/src/application/project/wizard/wizard_session.dart';
import 'package:elecx/src/domain/apartment_topology.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/features/projects/apartment_wizard_screen.dart';
import 'package:elecx/src/features/projects/project_wizard_localizations.dart';
import 'package:elecx/src/features/projects/wizard_candidate_carousel.dart';
import 'package:elecx/src/features/projects/wizard_diff_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P9.10 production presentation acceptance', () {
    test('viewport changes stay outside reserved Preview identity', () {
      final harness = _Harness.create(seed: 9201);
      _prepareReservedPreview(harness);
      final preview = harness.session.preview!;
      final normalizedIntentKey = preview.normalizedIntentKey;
      final reservation = preview.reservation;
      final semanticKeys = preview.semanticChangeSet.operations
          .map((operation) => operation.semanticKey)
          .toList();
      final version = harness.mutations.current.version;
      final viewport = PreviewViewportState();
      addTearDown(viewport.dispose);

      viewport.zoomIn();
      expect(viewport.scale, greaterThan(1));
      viewport.zoomOut();
      viewport.resetView();

      expect(viewport.scale, 1);
      expect(harness.session.preview, same(preview));
      expect(harness.session.preview!.normalizedIntentKey, normalizedIntentKey);
      expect(harness.session.preview!.reservation, same(reservation));
      expect(
        harness.session.preview!.semanticChangeSet.operations
            .map((operation) => operation.semanticKey)
            .toList(),
        semanticKeys,
      );
      expect(harness.mutations.current.version, version);
      expect(harness.mutations.undoDepth, 0);
    });

    testWidgets('grouped Diff hides raw boundary edges from default UX',
        (tester) async {
      final harness = _Harness.create(seed: 9202);
      _prepareReservedPreview(harness);
      final model = const WizardDiffProjector().project(
        before: harness.fixture.project,
        preview: harness.session.preview!,
      );
      final boundaryEntries = model.entries
          .where(
            (entry) =>
                entry.category == WizardDiffEntityCategory.boundaryTopology,
          )
          .toList();
      final boundaryGroups = model.grouped().where(
            (group) => group.entries.any(
              (entry) =>
                  entry.category == WizardDiffEntityCategory.boundaryTopology,
            ),
          );
      expect(boundaryEntries, isNotEmpty);

      await tester.pumpWidget(
        _localizedApp(
          home: Scaffold(body: WizardDiffPanel(model: model)),
        ),
      );
      await tester.pumpAndSettle();

      for (final group in boundaryGroups) {
        expect(
          find.byKey(ValueKey('wizard-boundary-group-${group.key}')),
          findsOneWidget,
        );
      }
      for (final entry in boundaryEntries) {
        expect(
          find.byKey(ValueKey('wizard-diff-${entry.semanticKey}')),
          findsNothing,
        );
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '390px textScale 2.0 reaches full Diff and duplicate Apply commits once',
        (tester) async {
      final harness = _Harness.create(seed: 9203, preselectCandidate: false);
      _seedEditingParameters(harness);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final versionBefore = harness.mutations.current.version;

      await tester.pumpWidget(
        _localizedApp(
          textScale: 2,
          home: _Launcher(session: harness.session),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('launch-apartment-wizard')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester
          .tap(find.byKey(const ValueKey('apartment-generate-candidates')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('apartment-prepare-preview')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('apartment-prepare-preview')));
      await tester.pumpAndSettle();
      expect(harness.session.status, WizardSessionStatus.previewReady);
      expect(
        find.byKey(const ValueKey('wizard-preview-zoom-in')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('wizard-preview-reset-view')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('apartment-apply')), findsOneWidget);
      expect(tester.takeException(), isNull);

      final changesDestination = find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Changes'),
      );
      expect(changesDestination, findsOneWidget);
      await tester.tap(changesDestination);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('wizard-diff-list')), findsOneWidget);
      expect(tester.takeException(), isNull);

      final apply = tester.widget<FilledButton>(
        find.byKey(const ValueKey('apartment-apply')),
      );
      expect(apply.onPressed, isNotNull);
      apply.onPressed!.call();
      apply.onPressed!.call();
      await tester.pumpAndSettle();

      expect(
        harness.mutations.current.version.value,
        versionBefore.value + 1,
      );
      expect(harness.mutations.undoDepth, 1);
      expect(harness.session.status, WizardSessionStatus.completed);
      expect(tester.takeException(), isNull);
    });

    testWidgets('responsive relayout preserves the exact reserved Preview',
        (tester) async {
      final harness = _Harness.create(seed: 9204, preselectCandidate: false);
      _seedEditingParameters(harness);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _localizedApp(home: _Launcher(session: harness.session)),
      );
      await tester.tap(find.byKey(const ValueKey('launch-apartment-wizard')));
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey('apartment-generate-candidates')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('apartment-prepare-preview')));
      await tester.pumpAndSettle();

      final preview = harness.session.preview!;
      final intent = preview.normalizedIntentKey;
      final reservation = preview.reservation;
      final semanticKeys = preview.semanticChangeSet.operations
          .map((operation) => operation.semanticKey)
          .toList();

      for (final size in const <Size>[
        Size(900, 900),
        Size(1440, 1000),
        Size(390, 844),
      ]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        expect(harness.session.preview, same(preview));
        expect(harness.session.preview!.normalizedIntentKey, intent);
        expect(harness.session.preview!.reservation, same(reservation));
        expect(
          harness.session.preview!.semanticChangeSet.operations
              .map((operation) => operation.semanticKey)
              .toList(),
          semanticKeys,
        );
        expect(tester.takeException(), isNull);
      }
    });
  });
}

Widget _localizedApp({
  required Widget home,
  double textScale = 1,
}) =>
    MaterialApp(
      locale: const Locale('en'),
      supportedLocales: ProjectWizardLocalizations.supportedLocales,
      localizationsDelegates: ProjectWizardLocalizations.localizationsDelegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: home,
    );

final class _Launcher extends StatelessWidget {
  const _Launcher({required this.session});

  final WizardSession session;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: FilledButton(
            key: const ValueKey('launch-apartment-wizard'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ApartmentWizardScreen(session: session),
              ),
            ),
            child: const Text('Launch'),
          ),
        ),
      );
}

void _seedEditingParameters(_Harness harness) {
  expect(harness.session.begin(), isTrue);
  expect(
    harness.session.selectFamily(ApartmentWizardProvider.familyId),
    isTrue,
  );
  expect(
    harness.session.updateParameters(
      ApartmentWizardParameters(request: harness.request),
    ),
    isTrue,
  );
}

void _prepareReservedPreview(_Harness harness) {
  expect(harness.parameters, isNotNull);
  expect(harness.session.begin(), isTrue);
  expect(
    harness.session.selectFamily(ApartmentWizardProvider.familyId),
    isTrue,
  );
  expect(harness.session.updateParameters(harness.parameters!), isTrue);
  expect(
    harness.session.generatePreview(),
    isTrue,
    reason: '${harness.session.failure}',
  );
}

final class _Harness {
  const _Harness({
    required this.fixture,
    required this.request,
    required this.parameters,
    required this.mutations,
    required this.session,
  });

  factory _Harness.create({
    required int seed,
    bool preselectCandidate = true,
  }) {
    final fixture = _fixture();
    final request = _request();
    final generation = const ApartmentCandidateSetService().generate(
      input: request,
      target: fixture.target,
      project: fixture.project,
    );
    expect(generation.accepted, isTrue);
    final set = generation.candidateSet!;
    final card = set.candidates.first;
    final parameters = preselectCandidate
        ? ApartmentWizardParameters(
            request: request,
            selection: set.selectionFor(card),
          )
        : null;
    final mutations = ProjectMutationSession(fixture.project);
    final session = WizardSession(
      target: fixture.target,
      registry: WizardProviderRegistry([const ApartmentWizardProvider()]),
      mutations: SharedProjectWizardMutationPort(
        mutations: mutations,
        idFactory: SecureRandomEntityIdFactory(random: Random(seed)),
      ),
    );
    return _Harness(
      fixture: fixture,
      request: request,
      parameters: parameters,
      mutations: mutations,
      session: session,
    );
  }

  final _Fixture fixture;
  final ApartmentRequestInput request;
  final ApartmentWizardParameters? parameters;
  final ProjectMutationSession mutations;
  final WizardSession session;
}

ApartmentRequestInput _request() => const ApartmentRequestInput(
      habitableRoomCount: 3,
      approximateAreaDm2: 7800,
      bathroomCount: 1,
      separateWcCount: 0,
      balconyCount: 0,
      balconyKind: ApartmentBalconyKind.none,
      kitchenMode: ApartmentKitchenMode.separate,
      corridorMode: ApartmentCorridorMode.auto,
      exteriorExposurePreference: ApartmentExteriorExposurePreference.any,
    );

final class _Fixture {
  const _Fixture({required this.project, required this.target});

  final ProjectAggregateRoot project;
  final LevelWizardTarget target;
}

_Fixture _fixture() {
  final projectId = ProjectId('p9-ui-project');
  final siteId = SiteId('p9-ui-site');
  final buildingId = BuildingId('p9-ui-building');
  final levelId = LevelId('p9-ui-level');
  final version = LocalProjectVersion(11);
  final project = ProjectAggregateRoot(
    id: projectId,
    siteId: siteId,
    version: version,
    stores: ProjectEntityStores(
      sites: {
        siteId: ProjectSiteEntity(
          id: siteId,
          name: 'Site',
          buildingIds: {buildingId},
        ),
      },
      buildings: {
        buildingId: ProjectBuildingEntity(
          id: buildingId,
          siteId: siteId,
          name: 'Building',
          levelIds: {levelId},
        ),
      },
      levels: {
        levelId: ProjectLevelEntity(
          id: levelId,
          buildingId: buildingId,
          name: 'Level 1',
          levelNumber: 1,
          elevationMm: 3000,
          kind: ProjectLevelKind.residential,
        ),
      },
    ),
  );
  return _Fixture(
    project: project,
    target: LevelWizardTarget(
      projectId: projectId,
      siteId: siteId,
      baseVersion: version,
      buildingId: buildingId,
      levelId: levelId,
    ),
  );
}
