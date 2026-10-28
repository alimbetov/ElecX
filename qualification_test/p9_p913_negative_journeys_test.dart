import 'dart:math';

import 'package:elecx/src/application/project/canonical_project_persistence_owner.dart';
import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_repository.dart';
import 'package:elecx/src/application/project/project_snapshot.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_candidate_set_service.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_topology_vector_renderer.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_wizard_exploration.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_wizard_parameters.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_wizard_provider.dart';
import 'package:elecx/src/application/project/wizard/project_wizard_mutation_port.dart';
import 'package:elecx/src/application/project/wizard/wizard_contracts.dart';
import 'package:elecx/src/application/project/wizard/wizard_session.dart';
import 'package:elecx/src/domain/apartment_topology.dart';
import 'package:elecx/src/domain/apartment_topology/apartment_topology_catalog_v4.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/features/projects/apartment_wizard_screen.dart';
import 'package:elecx/src/features/projects/project_wizard_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'NG-02 unsupported valid request preserves input shows blockers and mutates nothing',
      (tester) async {
    final fixture = _fixture('ng02');
    final unsupported = _findUnsupportedValidRequest(fixture);
    final result = unsupported.result;
    expect(result.accepted, isFalse);
    expect(result.failures.any((failure) => failure.isBlocker), isTrue);

    final mutations = ProjectMutationSession(fixture.project);
    final session = WizardSession(
      target: fixture.target,
      registry: WizardProviderRegistry(const [ApartmentWizardProvider()]),
      mutations: SharedProjectWizardMutationPort(
        mutations: mutations,
        idFactory: SecureRandomEntityIdFactory(random: Random(9130200)),
      ),
    );
    expect(session.begin(), isTrue);
    expect(session.selectFamily(ApartmentWizardProvider.familyId), isTrue);
    expect(
      session.updateParameters(
        ApartmentWizardParameters(request: unsupported.request),
      ),
      isTrue,
    );

    final versionBefore = mutations.current.version;
    final storesBefore = mutations.current.stores;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_localizedApp(ApartmentWizardScreen(session: session)));
    await tester.pumpAndSettle();

    final generate = find.byKey(const ValueKey('apartment-generate-candidates'));
    await tester.ensureVisible(generate);
    await tester.tap(generate);
    await tester.pumpAndSettle();

    final blocker = result.failures.firstWhere((failure) => failure.isBlocker);
    expect(
      find.byKey(ValueKey('apartment-generation-failure-${blocker.code}')),
      findsWidgets,
    );
    expect(find.byKey(const ValueKey('apartment-apply')), findsNothing);
    expect(mutations.current.version, versionBefore);
    expect(mutations.current.stores, same(storesBefore));

    final rooms = tester.widget<TextField>(
      find.byKey(const ValueKey('apartment-rooms')),
    );
    final area = tester.widget<TextField>(
      find.byKey(const ValueKey('apartment-area')),
    );
    expect(
      rooms.controller!.text,
      unsupported.request.habitableRoomCount.toString(),
    );
    expect(
      area.controller!.text,
      (unsupported.request.approximateAreaDm2 / 100).toStringAsFixed(1),
    );
    expect(tester.takeException(), isNull);
  });

  test('NG-06 renderer failure cannot mutate candidate or canonical project', () {
    final fixture = _fixture('ng06');
    const service = ApartmentCandidateSetService();
    final generated = service.generate(
      input: _supportedRequest,
      target: fixture.target,
      project: fixture.project,
    );
    expect(generated.accepted, isTrue);
    final selected = generated.candidateSet!.recommendedCandidate;
    final fingerprintBefore = selected.rankedCandidate.candidate.geometryFingerprint;
    final versionBefore = fixture.project.version;
    final storesBefore = fixture.project.stores;

    final catalog = P9ApartmentTopologyCatalogV4.create();
    final mismatchedTemplate = catalog.templates.firstWhere(
      (template) =>
          template.templateId != selected.template.templateId ||
          template.templateVersion != selected.template.templateVersion,
    );
    final rendered = const ApartmentTopologyVectorRenderer().render(
      rankedCandidate: selected.rankedCandidate,
      template: mismatchedTemplate,
    );

    expect(rendered.accepted, isFalse);
    expect(rendered.scene, isNull);
    expect(rendered.failures.any((failure) => failure.isBlocker), isTrue);
    expect(
      selected.rankedCandidate.candidate.geometryFingerprint,
      fingerprintBefore,
    );
    expect(fixture.project.version, versionBefore);
    expect(fixture.project.stores, same(storesBefore));
  });

  test('NG-07 failed repository save leaves previous durable project intact',
      () async {
    final fixture = _fixture('ng07');
    final now = DateTime.utc(2026, 10, 28, 4);
    final baseline = ProjectSnapshot(
      aggregate: fixture.project,
      name: 'P9.13 NG-07',
      createdAt: now,
      updatedAt: now,
    );
    final repository = _FailingSaveRepository(baseline);
    final owner = CanonicalProjectPersistenceOwner(
      snapshot: baseline,
      repository: repository,
    );

    final mutations = ProjectMutationSession(fixture.project);
    final session = WizardSession(
      target: fixture.target,
      registry: WizardProviderRegistry(const [ApartmentWizardProvider()]),
      mutations: SharedProjectWizardMutationPort(
        mutations: mutations,
        idFactory: SecureRandomEntityIdFactory(random: Random(9130700)),
      ),
    );
    final generated = const ApartmentCandidateSetService().generate(
      input: _supportedRequest,
      target: fixture.target,
      project: fixture.project,
    );
    expect(generated.accepted, isTrue);
    final set = generated.candidateSet!;

    expect(session.begin(), isTrue);
    expect(session.selectFamily(ApartmentWizardProvider.familyId), isTrue);
    expect(
      session.updateParameters(
        ApartmentWizardParameters(
          request: _supportedRequest,
          selection: set.selectionFor(set.recommendedCandidate),
        ),
      ),
      isTrue,
    );
    expect(session.generatePreview(), isTrue, reason: '${session.failure}');
    expect(session.confirm(), isTrue, reason: '${session.failure}');
    final committed = session.commitResult!.mutation;
    owner.acceptMutation(
      sessionProject: committed.project,
      result: committed,
      now: now.add(const Duration(minutes: 1)),
    );
    expect(
      owner.project.engineeringMetadata.generationProvenanceRegistry.manifests,
      isNotEmpty,
    );

    await expectLater(owner.save(), throwsA(isA<StateError>()));

    final durable = await repository.load(fixture.project.id);
    expect(durable, isNotNull);
    expect(durable!.aggregate.version, baseline.aggregate.version);
    expect(durable.aggregate.stores, same(baseline.aggregate.stores));
    expect(
      durable.aggregate.engineeringMetadata.generationProvenanceRegistry
          .manifests,
      isEmpty,
    );
    expect(repository.saveAttempts, 1);
  });
}

Widget _localizedApp(Widget home) => MaterialApp(
      locale: const Locale('en'),
      supportedLocales: ProjectWizardLocalizations.supportedLocales,
      localizationsDelegates: ProjectWizardLocalizations.localizationsDelegates,
      home: home,
    );

final class _UnsupportedCase {
  const _UnsupportedCase(this.request, this.result);

  final ApartmentRequestInput request;
  final ApartmentCandidateSetGenerationResult result;
}

_UnsupportedCase _findUnsupportedValidRequest(_Fixture fixture) {
  const service = ApartmentCandidateSetService();
  const normalizer = ApartmentRequestNormalizer();
  const areas = <int>[1800, 2500, 3500, 5000, 8000, 12000, 18000, 28000];

  for (var rooms = 1; rooms <= 10; rooms++) {
    for (final area in areas) {
      for (final kitchen in ApartmentKitchenMode.values) {
        for (final corridor in ApartmentCorridorMode.values) {
          for (var bathrooms = 1; bathrooms <= 3; bathrooms++) {
            final request = ApartmentRequestInput(
              habitableRoomCount: rooms,
              approximateAreaDm2: area,
              bathroomCount: bathrooms,
              separateWcCount: 0,
              balconyCount: 0,
              balconyKind: ApartmentBalconyKind.none,
              kitchenMode: kitchen,
              corridorMode: corridor,
              exteriorExposurePreference:
                  ApartmentExteriorExposurePreference.any,
            );
            final normalized = normalizer.normalize(request);
            if (normalized.request == null || normalized.hasBlockers) continue;
            final result = service.generate(
              input: request,
              target: fixture.target,
              project: fixture.project,
            );
            if (!result.accepted &&
                result.failures.any((failure) => failure.isBlocker)) {
              return _UnsupportedCase(request, result);
            }
          }
        }
      }
    }
  }
  throw StateError(
    'P9.13 NG-02 requires at least one normalized-but-unsupported fixture.',
  );
}

const _supportedRequest = ApartmentRequestInput(
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

final class _FailingSaveRepository implements ProjectRepository {
  _FailingSaveRepository(this._durable);

  final ProjectSnapshot _durable;
  int saveAttempts = 0;

  @override
  Future<ProjectSnapshot?> load(ProjectId projectId) async =>
      projectId == _durable.id ? _durable : null;

  @override
  Future<void> save(ProjectSnapshot snapshot) async {
    saveAttempts++;
    throw StateError('P9.13 injected repository save failure');
  }

  @override
  Future<List<ProjectSummary>> list() async => const <ProjectSummary>[];
}

final class _Fixture {
  const _Fixture({required this.project, required this.target});

  final ProjectAggregateRoot project;
  final LevelWizardTarget target;
}

_Fixture _fixture(String suffix) {
  final projectId = ProjectId('p9-p913-$suffix-project');
  final siteId = SiteId('p9-p913-$suffix-site');
  final buildingId = BuildingId('p9-p913-$suffix-building');
  final levelId = LevelId('p9-p913-$suffix-level');
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
