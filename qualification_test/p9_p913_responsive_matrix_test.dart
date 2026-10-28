import 'dart:math';

import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_candidate_set_service.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_preview_presentation.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_wizard_parameters.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_wizard_provider.dart';
import 'package:elecx/src/application/project/wizard/project_wizard_mutation_port.dart';
import 'package:elecx/src/application/project/wizard/wizard_contracts.dart';
import 'package:elecx/src/application/project/wizard/wizard_session.dart';
import 'package:elecx/src/domain/apartment_topology.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/features/projects/apartment_wizard_screen.dart';
import 'package:elecx/src/features/projects/elecx_presentation_policy.dart';
import 'package:elecx/src/features/projects/project_wizard_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('P9.13 D-F authoritative width breakpoints are exact', () {
    expect(
      ElecXPresentationPolicy.widthClassFor(599),
      ElecXResponsiveWidthClass.compact,
    );
    expect(
      ElecXPresentationPolicy.widthClassFor(600),
      ElecXResponsiveWidthClass.medium,
    );
    expect(
      ElecXPresentationPolicy.widthClassFor(1023),
      ElecXResponsiveWidthClass.medium,
    );
    expect(
      ElecXPresentationPolicy.widthClassFor(1024),
      ElecXResponsiveWidthClass.expanded,
    );
    expect(
      ElecXPresentationPolicy.widthClassFor(1439),
      ElecXResponsiveWidthClass.expanded,
    );
    expect(
      ElecXPresentationPolicy.widthClassFor(1440),
      ElecXResponsiveWidthClass.large,
    );
  });

  testWidgets(
      'P9.13 GJ-03 viewport locale scale theme transitions preserve and apply exact reservation',
      (tester) async {
    final harness = _Harness.create(seed: 91301);
    _primeEditingParameters(harness);

    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    const initialPresentation = _PresentationCase(
      label: 'qualification bootstrap 1440x900',
      size: Size(1440, 900),
    );
    tester.view.physicalSize = initialPresentation.size;
    await tester.pumpWidget(
      _app(harness: harness, presentation: initialPresentation),
    );
    await tester.pumpAndSettle();

    final generateButton =
        find.byKey(const ValueKey('apartment-generate-candidates'));
    await tester.ensureVisible(generateButton);
    await tester.tap(generateButton);
    await tester.pumpAndSettle();

    final preparePreviewButton =
        find.byKey(const ValueKey('apartment-prepare-preview'));
    expect(preparePreviewButton, findsOneWidget);
    await tester.tap(preparePreviewButton);
    await tester.pumpAndSettle();

    expect(harness.session.preview, isNotNull);
    final preview = harness.session.preview!;
    final normalizedIntentKey = preview.normalizedIntentKey;
    final reservation = preview.reservation;
    final semanticKeys = preview.semanticChangeSet.operations
        .map((operation) => operation.semanticKey)
        .toList(growable: false);
    final projectVersion = harness.mutations.current.version;
    final undoDepth = harness.mutations.undoDepth;

    for (final presentation in _matrix) {
      tester.view.physicalSize = presentation.size;
      await tester.pumpWidget(
        _app(harness: harness, presentation: presentation),
      );
      await tester.pumpAndSettle();

      expect(
        tester.takeException(),
        isNull,
        reason: presentation.label,
      );
      expect(
        harness.session.preview,
        same(preview),
        reason: presentation.label,
      );
      expect(
        harness.session.preview!.normalizedIntentKey,
        normalizedIntentKey,
        reason: presentation.label,
      );
      expect(
        harness.session.preview!.reservation,
        same(reservation),
        reason: presentation.label,
      );
      expect(
        harness.session.preview!.semanticChangeSet.operations
            .map((operation) => operation.semanticKey)
            .toList(growable: false),
        semanticKeys,
        reason: presentation.label,
      );
      expect(
        harness.mutations.current.version,
        projectVersion,
        reason: '${presentation.label}: presentation must not mutate project',
      );
      expect(
        harness.mutations.undoDepth,
        undoDepth,
        reason: '${presentation.label}: relayout must not create history',
      );
      expect(
        find.byKey(const ValueKey('apartment-apply')),
        findsOneWidget,
        reason:
            '${presentation.label}: primary Apply action must stay reachable',
      );
    }

    const compactDiffPresentation = _PresentationCase(
      label: 'GJ-03 compact Diff 390x844 EN',
      size: Size(390, 844),
    );
    tester.view.physicalSize = compactDiffPresentation.size;
    await tester.pumpWidget(
      _app(harness: harness, presentation: compactDiffPresentation),
    );
    await tester.pumpAndSettle();
    final changesDestination = find.descendant(
      of: find.byType(NavigationBar),
      matching: find.byIcon(Icons.difference_outlined),
    );
    expect(changesDestination, findsOneWidget);
    await tester.tap(changesDestination);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('wizard-diff-list')), findsOneWidget);
    expect(tester.takeException(), isNull);

    const finalPresentation = _PresentationCase(
      label: 'GJ-03 final desktop 1440x900',
      size: Size(1440, 900),
    );
    tester.view.physicalSize = finalPresentation.size;
    await tester.pumpWidget(
      _app(harness: harness, presentation: finalPresentation),
    );
    await tester.pumpAndSettle();

    expect(harness.session.preview, same(preview));
    expect(harness.session.preview!.reservation, same(reservation));
    expect(harness.session.preview!.normalizedIntentKey, normalizedIntentKey);
    expect(tester.takeException(), isNull);

    final apply = find.byKey(const ValueKey('apartment-apply'));
    expect(apply, findsOneWidget);
    await tester.tap(apply);
    await tester.pumpAndSettle();

    expect(harness.session.status, WizardSessionStatus.completed);
    expect(harness.mutations.current.version.value, projectVersion.value + 1);
    expect(harness.mutations.undoDepth, undoDepth + 1);
    expect(tester.takeException(), isNull);
  });
}

Widget _app({
  required _Harness harness,
  required _PresentationCase presentation,
}) =>
    MaterialApp(
      locale: presentation.locale,
      supportedLocales: ProjectWizardLocalizations.supportedLocales,
      localizationsDelegates: ProjectWizardLocalizations.localizationsDelegates,
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: presentation.dark ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(presentation.textScale),
        ),
        child: child!,
      ),
      home: ApartmentWizardScreen(session: harness.session),
    );

final class _PresentationCase {
  const _PresentationCase({
    required this.label,
    required this.size,
    this.locale = const Locale('en'),
    this.textScale = 1,
    this.dark = false,
  });

  final String label;
  final Size size;
  final Locale locale;
  final double textScale;
  final bool dark;
}

const _matrix = <_PresentationCase>[
  _PresentationCase(
    label: 'phone portrait 390x844 RU scale2 light',
    size: Size(390, 844),
    locale: Locale('ru'),
    textScale: 2,
  ),
  _PresentationCase(
    label: 'phone landscape 844x390 RU scale2 dark',
    size: Size(844, 390),
    locale: Locale('ru'),
    textScale: 2,
    dark: true,
  ),
  _PresentationCase(label: 'breakpoint 599', size: Size(599, 844)),
  _PresentationCase(label: 'breakpoint 600', size: Size(600, 844)),
  _PresentationCase(
    label: 'tablet portrait 768x1024 RU scale2',
    size: Size(768, 1024),
    locale: Locale('ru'),
    textScale: 2,
  ),
  _PresentationCase(label: 'tablet landscape 1024x768', size: Size(1024, 768)),
  _PresentationCase(label: 'breakpoint 1023', size: Size(1023, 768)),
  _PresentationCase(label: 'breakpoint 1024', size: Size(1024, 768)),
  _PresentationCase(label: 'large tablet 1366x1024', size: Size(1366, 1024)),
  _PresentationCase(
    label: 'minimum desktop 800x600 RU scale2 dark',
    size: Size(800, 600),
    locale: Locale('ru'),
    textScale: 2,
    dark: true,
  ),
  _PresentationCase(label: 'compact desktop 1280x720', size: Size(1280, 720)),
  _PresentationCase(label: 'breakpoint 1439', size: Size(1439, 900)),
  _PresentationCase(
    label: 'desktop 1440x900 EN scale1',
    size: Size(1440, 900),
  ),
  _PresentationCase(
    label: 'desktop 1440x900 EN scale1.3 dark',
    size: Size(1440, 900),
    textScale: 1.3,
    dark: true,
  ),
  _PresentationCase(label: 'large desktop 1920x1080', size: Size(1920, 1080)),
];

void _primeEditingParameters(_Harness harness) {
  expect(harness.session.begin(), isTrue);
  expect(
    harness.session.selectFamily(ApartmentWizardProvider.familyId),
    isTrue,
  );
  expect(harness.session.updateParameters(harness.parameters), isTrue);
}

final class _Harness {
  const _Harness({
    required this.parameters,
    required this.mutations,
    required this.session,
  });

  factory _Harness.create({required int seed}) {
    final fixture = _fixture();
    final request = _request();
    final generation = const ApartmentCandidateSetService().generate(
      input: request,
      target: fixture.target,
      project: fixture.project,
    );
    expect(generation.accepted, isTrue);
    final set = generation.candidateSet!;
    final parameters = ApartmentWizardParameters(
      request: request,
      selection: set.selectionFor(set.candidates.first),
    );
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
      parameters: parameters,
      mutations: mutations,
      session: session,
    );
  }

  final ApartmentWizardParameters parameters;
  final ProjectMutationSession mutations;
  final WizardSession session;
}

ApartmentRequestInput _request() => const ApartmentRequestInput(
      habitableRoomCount: 3,
      approximateAreaDm2: 7850,
      bathroomCount: 1,
      separateWcCount: 0,
      balconyCount: 1,
      balconyKind: ApartmentBalconyKind.loggia,
      kitchenMode: ApartmentKitchenMode.kitchenLiving,
      corridorMode: ApartmentCorridorMode.auto,
      exteriorExposurePreference: ApartmentExteriorExposurePreference.any,
    );

final class _Fixture {
  const _Fixture({required this.project, required this.target});

  final ProjectAggregateRoot project;
  final LevelWizardTarget target;
}

_Fixture _fixture() {
  final projectId = ProjectId('p9-p913-responsive-project');
  final siteId = SiteId('p9-p913-responsive-site');
  final buildingId = BuildingId('p9-p913-responsive-building');
  final levelId = LevelId('p9-p913-responsive-level');
  final version = LocalProjectVersion(13);
  final project = ProjectAggregateRoot(
    id: projectId,
    siteId: siteId,
    version: version,
    stores: ProjectEntityStores(
      sites: {
        siteId: ProjectSiteEntity(
          id: siteId,
          name: 'P9.13 Site',
          buildingIds: {buildingId},
        ),
      },
      buildings: {
        buildingId: ProjectBuildingEntity(
          id: buildingId,
          siteId: siteId,
          name: 'P9.13 Building',
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
          spaceIds: const {},
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
