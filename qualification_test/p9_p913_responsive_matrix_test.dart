import 'dart:math';

import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_candidate_set_service.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_wizard_parameters.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_wizard_provider.dart';
import 'package:elecx/src/application/project/wizard/project_wizard_mutation_port.dart';
import 'package:elecx/src/application/project/wizard/wizard_contracts.dart';
import 'package:elecx/src/application/project/wizard/wizard_session.dart';
import 'package:elecx/src/domain/apartment_topology.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/features/projects/apartment_wizard_screen.dart';
import 'package:elecx/src/features/projects/project_wizard_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'P9.13 D-F viewport locale scale theme matrix preserves reserved semantics',
      (tester) async {
    final harness = _Harness.create(seed: 91301);
    _prepareReservedPreview(harness);
    final preview = harness.session.preview!;
    final normalizedIntentKey = preview.normalizedIntentKey;
    final reservation = preview.reservation;
    final semanticKeys = preview.semanticChangeSet.operations
        .map((operation) => operation.semanticKey)
        .toList(growable: false);
    final projectVersion = harness.mutations.current.version;

    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final presentation in _matrix) {
      tester.view.physicalSize = presentation.size;
      await tester.pumpWidget(
        MaterialApp(
          locale: presentation.locale,
          supportedLocales: ProjectWizardLocalizations.supportedLocales,
          localizationsDelegates:
              ProjectWizardLocalizations.localizationsDelegates,
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
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.takeException(),
        isNull,
        reason: presentation.label,
      );
      expect(harness.session.preview, same(preview), reason: presentation.label);
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
        find.byKey(const ValueKey('apartment-apply')),
        findsOneWidget,
        reason: '${presentation.label}: primary Apply action must stay reachable',
      );
    }
  });
}

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

void _prepareReservedPreview(_Harness harness) {
  expect(harness.session.begin(), isTrue);
  expect(
    harness.session.selectFamily(ApartmentWizardProvider.familyId),
    isTrue,
  );
  expect(harness.session.updateParameters(harness.parameters), isTrue);
  expect(
    harness.session.generatePreview(),
    isTrue,
    reason: '${harness.session.failure}',
  );
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
