import 'package:elecx/src/application/project/wizard/apartment/apartment_candidate_set_service.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_preview_presentation.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_wizard_exploration.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_wizard_parameters.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_wizard_provider.dart';
import 'package:elecx/src/application/project/wizard/wizard_contracts.dart';
import 'package:elecx/src/domain/apartment_topology.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_space_semantics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _ProjectFixture empty;
  late _ProjectFixture nonEmpty;
  late ApartmentRequestInput requestA;
  late ApartmentRequestInput requestB;
  late ApartmentCandidateSetGenerationResult generatedA;
  late ApartmentCandidateSetGenerationResult generatedB;

  setUpAll(() {
    empty = _projectFixture();
    nonEmpty = _projectFixture(withSpace: true);
    requestA = _request(areaDm2: 7800);
    requestB = _request(areaDm2: 7900);
    generatedA = const ApartmentCandidateSetService().generate(
      input: requestA,
      target: empty.target,
      project: empty.project,
    );
    generatedB = const ApartmentCandidateSetService().generate(
      input: requestB,
      target: empty.target,
      project: empty.project,
    );
    expect(generatedA.accepted, isTrue);
    expect(generatedB.accepted, isTrue);
    expect(generatedA.candidateSet!.candidates, isNotEmpty);
    expect(generatedB.candidateSet!.candidates, isNotEmpty);
  });

  group('P9.9 ApartmentWizardProvider', () {
    test('P9.9-AT-001 Apartment appears only for Level scope', () {
      final registry =
          WizardProviderRegistry(const [ApartmentWizardProvider()]);
      final level = registry.availableFor(empty.target);
      final building = registry.availableFor(
        BuildingWizardTarget(
          projectId: empty.project.id,
          siteId: empty.project.siteId,
          baseVersion: empty.project.version,
          buildingId: empty.buildingId,
        ),
      );

      expect(
        level.map((descriptor) => descriptor.familyId),
        contains(ApartmentWizardProvider.familyId),
      );
      expect(building, isEmpty);
    });

    test('P9.9-AT-002 non-empty Level blocks generation', () {
      final result = const ApartmentCandidateSetService().generate(
        input: requestA,
        target: nonEmpty.target,
        project: nonEmpty.project,
      );

      expect(result.accepted, isFalse);
      expect(
        result.failures.map((failure) => failure.code),
        contains('p9.provider.target-not-empty'),
      );
    });

    test('P9.9-AT-003 semantic parameter edit invalidates selection and set',
        () {
      final controller = ApartmentWizardExplorationController(
        initialParameters: ApartmentWizardParameters(request: requestA),
      );
      final ticket = controller.beginGeneration();
      expect(controller.publishGeneration(ticket, generatedA), isTrue);
      final set = generatedA.candidateSet!;
      final selected = set.candidates.first;
      controller.selectCandidate(selected.candidateFingerprint);
      expect(controller.parameters.selection, isNotNull);
      expect(
        controller.parameters.selection!.candidateSetFingerprint,
        set.candidateSetFingerprint,
      );
      expect(controller.candidateSet, isNotNull);

      controller.updateRequest(requestB);

      expect(controller.parameters.selection, isNull);
      expect(controller.candidateSet, isNull);
      expect(controller.requestRevision, 1);
    });

    test('P9.9-AT-004 selecting a card mutates no canonical state', () {
      final controller = ApartmentWizardExplorationController(
        initialParameters: ApartmentWizardParameters(request: requestA),
      );
      final version = empty.project.version;
      final stores = empty.project.stores;
      final ticket = controller.beginGeneration();
      controller.publishGeneration(ticket, generatedA);
      controller.selectCandidate(
        generatedA.candidateSet!.candidates.first.candidateFingerprint,
      );

      expect(empty.project.version, same(version));
      expect(empty.project.stores, same(stores));
    });

    test('P9.9-AT-005 missing selection blocks Preview validation', () {
      const provider = ApartmentWizardProvider();
      final validation = provider.validateTypedParameters(
        ApartmentWizardParameters(request: requestA),
        empty.target,
      );

      expect(validation.hasBlockers, isTrue);
      expect(
        validation.issues.map((issue) => issue.code),
        contains('p9.provider.selection-required'),
      );
    });

    test('P9.9-AT-006 stale and unknown fingerprints fail closed', () {
      const provider = ApartmentWizardProvider();
      final set = generatedA.candidateSet!;
      final card = set.candidates.first;
      final unknown = ApartmentCandidateSelection(
        candidateFingerprint: '${card.candidateFingerprint}-unknown',
        templateIdValue: card.identity.templateIdValue,
        templateVersion: card.identity.templateVersion,
        variantSeedId: card.identity.variantSeedId,
        candidateSetFingerprint: set.candidateSetFingerprint,
      );
      final stale = ApartmentCandidateSelection(
        candidateFingerprint: card.candidateFingerprint,
        templateIdValue: card.identity.templateIdValue,
        templateVersion: card.identity.templateVersion + 1,
        variantSeedId: card.identity.variantSeedId,
        candidateSetFingerprint: set.candidateSetFingerprint,
      );

      expect(
        () => provider.generateTyped(
          ApartmentWizardParameters(request: requestA, selection: unknown),
          WizardGenerationContext(target: empty.target, project: empty.project),
        ),
        throwsA(
          isA<ApartmentWizardProviderException>().having(
            (error) => error.code,
            'code',
            'p9.provider.selection-not-found',
          ),
        ),
      );
      expect(
        () => provider.generateTyped(
          ApartmentWizardParameters(request: requestA, selection: stale),
          WizardGenerationContext(target: empty.target, project: empty.project),
        ),
        throwsA(
          isA<ApartmentWizardProviderException>().having(
            (error) => error.code,
            'code',
            'p9.provider.selection-stale',
          ),
        ),
      );
    });

    test('P9.9-AT-007 exact selected candidate reaches reserved command', () {
      const provider = ApartmentWizardProvider();
      final set = generatedA.candidateSet!;
      final card = set.candidates.first;
      final command = provider.generateTyped(
        ApartmentWizardParameters(
          request: requestA,
          selection: set.selectionFor(card),
        ),
        WizardGenerationContext(target: empty.target, project: empty.project),
      );

      expect(command, isA<ApartmentReservedProjectCommand>());
      final apartment = command as ApartmentReservedProjectCommand;
      expect(
        apartment.candidateIdentity.candidateFingerprint,
        card.candidateFingerprint,
      );
      expect(
        apartment.selectedCandidate.geometryFingerprint,
        card.rankedCandidate.candidate.geometryFingerprint,
      );
      expect(
        apartment.candidateSetFingerprint,
        set.candidateSetFingerprint,
      );
    });

    test('P9.9-AT-008 provider has no cross-session selection leak', () {
      const provider = ApartmentWizardProvider();
      final set = generatedA.candidateSet!;
      final first = set.candidates.first;
      final second = set.candidates.last;
      final context =
          WizardGenerationContext(target: empty.target, project: empty.project);

      final firstCommand = provider.generateTyped(
        ApartmentWizardParameters(
          request: requestA,
          selection: set.selectionFor(first),
        ),
        context,
      ) as ApartmentReservedProjectCommand;
      final secondCommand = provider.generateTyped(
        ApartmentWizardParameters(
          request: requestA,
          selection: set.selectionFor(second),
        ),
        context,
      ) as ApartmentReservedProjectCommand;

      expect(
        firstCommand.candidateIdentity.candidateFingerprint,
        first.candidateFingerprint,
      );
      expect(
        secondCommand.candidateIdentity.candidateFingerprint,
        second.candidateFingerprint,
      );
      if (first.candidateFingerprint != second.candidateFingerprint) {
        expect(
          secondCommand.candidateIdentity.candidateFingerprint,
          isNot(firstCommand.candidateIdentity.candidateFingerprint),
        );
      }
    });

    test('P9.9-AT-009 wizard-exit cleanup preserves canonical version/stores',
        () {
      final controller = ApartmentWizardExplorationController(
        initialParameters: ApartmentWizardParameters(request: requestA),
      );
      final version = empty.project.version;
      final stores = empty.project.stores;
      final ticket = controller.beginGeneration();
      controller.publishGeneration(ticket, generatedA);
      controller.selectCandidate(
        generatedA.candidateSet!.candidates.first.candidateFingerprint,
      );

      controller.discardTransientState();

      expect(
        controller.status,
        ApartmentWizardExplorationStatus.editingParameters,
      );
      expect(controller.candidateSet, isNull);
      expect(controller.parameters.selection, isNull);
      expect(empty.project.version, same(version));
      expect(empty.project.stores, same(stores));
    });

    test('P9.9-AT-010 provider validation exposes localization keys', () {
      const provider = ApartmentWizardProvider();
      final validation = provider.validateTypedParameters(
        ApartmentWizardParameters(request: requestA),
        empty.target,
      );

      for (final issue in validation.issues) {
        expect(issue.message, issue.code);
        expect(issue.code, startsWith('p9.'));
      }
    });

    test('P9.9-AT-011 width transitions preserve selection identity', () {
      final controller = _selectedController(requestA, generatedA);
      final selected = controller.parameters.selection!;

      for (final width in <double>[390, 900, 1440]) {
        ApartmentPreviewLayoutPolicy.resolve(
          logicalWidth: width,
          textScaleFactor: 1,
          animationsDisabled: false,
        );
        expect(
          controller.parameters.selection!.candidateFingerprint,
          selected.candidateFingerprint,
        );
        expect(
          controller.parameters.selection!.candidateSetFingerprint,
          selected.candidateSetFingerprint,
        );
      }
    });

    test(
        'P9.9-AT-012 orientation-equivalent relayout preserves set fingerprint',
        () {
      final controller = _selectedController(requestA, generatedA);
      final fingerprint = controller.candidateSet!.candidateSetFingerprint;
      for (final width in <double>[390, 844, 1024, 1440]) {
        responsiveWidthClassFor(width);
        expect(controller.candidateSet!.candidateSetFingerprint, fingerprint);
      }
    });

    test('P9.9-AT-013 responsive transition does not replace candidate set',
        () {
      final controller = _selectedController(requestA, generatedA);
      final set = controller.candidateSet;
      for (final width in <double>[390, 900, 1440]) {
        responsiveWidthClassFor(width);
      }
      expect(controller.candidateSet, same(set));
    });

    test('P9.9-AT-014 keyboard flow reaches exact reserved handoff', () {
      final controller = _generatedController(requestA, generatedA);
      expect(
        semanticOperationFor(ApartmentPreviewInputSignal.keyboardActivate),
        ApartmentPreviewSemanticOperation.selectCandidate,
      );
      controller.selectCandidate(
        generatedA.candidateSet!.candidates.first.candidateFingerprint,
      );

      final command = const ApartmentWizardProvider().generateTyped(
        controller.parameters,
        WizardGenerationContext(target: empty.target, project: empty.project),
      );
      expect(
        controller.status,
        ApartmentWizardExplorationStatus.candidateSelected,
      );
      expect(command, isA<ApartmentReservedProjectCommand>());
    });

    test('P9.9-AT-015 touch flow reaches exact reserved handoff', () {
      final controller = _generatedController(requestA, generatedA);
      expect(
        semanticOperationFor(ApartmentPreviewInputSignal.touchTap),
        ApartmentPreviewSemanticOperation.selectCandidate,
      );
      controller.selectCandidate(
        generatedA.candidateSet!.candidates.first.candidateFingerprint,
      );

      final command = const ApartmentWizardProvider().generateTyped(
        controller.parameters,
        WizardGenerationContext(target: empty.target, project: empty.project),
      );
      expect(
        controller.status,
        ApartmentWizardExplorationStatus.candidateSelected,
      );
      expect(command, isA<ApartmentReservedProjectCommand>());
    });

    test('P9.9-AT-016 exploration Back preserves request/set/selection', () {
      final controller = _selectedController(requestA, generatedA);
      final set = controller.candidateSet;
      final intent = set!.request.intentFingerprint;
      final selection = controller.parameters.selection;

      controller.back();

      expect(
        controller.status,
        ApartmentWizardExplorationStatus.candidatesReady,
      );
      expect(controller.candidateSet, same(set));
      expect(controller.candidateSet!.request.intentFingerprint, intent);
      expect(controller.parameters.selection, same(selection));
    });

    test('P9.9-AT-017 obsolete late result cannot overwrite newer revision',
        () {
      final controller = ApartmentWizardExplorationController(
        initialParameters: ApartmentWizardParameters(request: requestA),
      );
      final oldTicket = controller.beginGeneration();
      controller.updateRequest(requestB);
      final newTicket = controller.beginGeneration();

      expect(controller.publishGeneration(oldTicket, generatedA), isFalse);
      expect(controller.candidateSet, isNull);
      expect(controller.publishGeneration(newTicket, generatedB), isTrue);
      expect(
        controller.candidateSet!.request.intentFingerprint,
        generatedB.candidateSet!.request.intentFingerprint,
      );
    });

    test('P9.9-AT-018 duplicate Generate has one authoritative ticket', () {
      final controller = ApartmentWizardExplorationController(
        initialParameters: ApartmentWizardParameters(request: requestA),
      );
      final first = controller.beginGeneration();
      final duplicate = controller.beginGeneration();

      expect(duplicate, same(first));
      expect(controller.inFlight, same(first));
      expect(controller.requestRevision, 0);
    });

    test('selection from another candidate set fails candidate-set stale', () {
      const provider = ApartmentWizardProvider();
      final set = generatedA.candidateSet!;
      final card = set.candidates.first;
      final staleSetSelection = ApartmentCandidateSelection(
        candidateFingerprint: card.candidateFingerprint,
        templateIdValue: card.identity.templateIdValue,
        templateVersion: card.identity.templateVersion,
        variantSeedId: card.identity.variantSeedId,
        candidateSetFingerprint: '${set.candidateSetFingerprint}-stale',
      );

      expect(
        () => provider.generateTyped(
          ApartmentWizardParameters(
            request: requestA,
            selection: staleSetSelection,
          ),
          WizardGenerationContext(target: empty.target, project: empty.project),
        ),
        throwsA(
          isA<ApartmentWizardProviderException>().having(
            (error) => error.code,
            'code',
            'p9.provider.candidate-set-stale',
          ),
        ),
      );
    });

    test('provider rejects legacy selection without candidate-set identity', () {
      const provider = ApartmentWizardProvider();
      final card = generatedA.candidateSet!.candidates.first;
      final unbound = card.identity.toSelection();

      final validation = provider.validateTypedParameters(
        ApartmentWizardParameters(request: requestA, selection: unbound),
        empty.target,
      );
      expect(
        validation.issues.map((issue) => issue.code),
        contains('p9.provider.candidate-set-stale'),
      );
    });

    test('provider descriptor uses candidate-set service generator version', () {
      const version = 'p9.generator.contract-test';
      const provider = ApartmentWizardProvider(
        candidateSetService: ApartmentCandidateSetService(
          generatorVersion: version,
        ),
      );

      expect(provider.descriptor.generatorVersion, version);
    });

    test('exploration status cannot duplicate P8 preview/apply lifecycle', () {
      expect(
        ApartmentWizardExplorationStatus.values.map((value) => value.name),
        [
          'editingParameters',
          'generating',
          'candidatesReady',
          'candidateSelected',
          'failed',
        ],
      );
    });

    test('authoritative mismatched result exits generating fail closed', () {
      final controller = ApartmentWizardExplorationController(
        initialParameters: ApartmentWizardParameters(request: requestA),
      );
      final ticket = controller.beginGeneration();

      expect(controller.publishGeneration(ticket, generatedB), isFalse);
      expect(controller.generationInProgress, isFalse);
      expect(controller.candidateSet, isNull);
      expect(controller.parameters.selection, isNull);
      expect(controller.status, ApartmentWizardExplorationStatus.failed);
    });

    test('reserved handoff builds canonical candidate without mutating current',
        () {
      const provider = ApartmentWizardProvider();
      final set = generatedA.candidateSet!;
      final card = set.candidates.first;
      final command = provider.generateTyped(
        ApartmentWizardParameters(
          request: requestA,
          selection: set.selectionFor(card),
        ),
        WizardGenerationContext(target: empty.target, project: empty.project),
      ) as ApartmentReservedProjectCommand;
      final originalVersion = empty.project.version;
      final originalStores = empty.project.stores;
      final reservation =
          command.reserveIdentities(SecureRandomEntityIdFactory());
      final candidate = command.buildCandidate(
        current: empty.project,
        reservation: reservation,
      );

      expect(reservation.slots, isNotEmpty);
      expect(candidate.stores.zones, hasLength(1));
      expect(
        candidate.stores.spaces,
        hasLength(
          card.rankedCandidate.candidate.interiorSpaces.length +
              card.rankedCandidate.candidate.exteriorAppendages.length,
        ),
      );
      expect(candidate.affectedEntityIds, isNotEmpty);
      expect(empty.project.version, same(originalVersion));
      expect(empty.project.stores, same(originalStores));
      expect(empty.project.stores.zones, isEmpty);
      expect(empty.project.stores.spaces, isEmpty);
    });
  });
}

ApartmentWizardExplorationController _generatedController(
  ApartmentRequestInput request,
  ApartmentCandidateSetGenerationResult generated,
) {
  final controller = ApartmentWizardExplorationController(
    initialParameters: ApartmentWizardParameters(request: request),
  );
  final ticket = controller.beginGeneration();
  expect(controller.publishGeneration(ticket, generated), isTrue);
  return controller;
}

ApartmentWizardExplorationController _selectedController(
  ApartmentRequestInput request,
  ApartmentCandidateSetGenerationResult generated,
) {
  final controller = _generatedController(request, generated);
  controller.selectCandidate(
    generated.candidateSet!.candidates.first.candidateFingerprint,
  );
  return controller;
}

ApartmentRequestInput _request({required int areaDm2}) => ApartmentRequestInput(
      habitableRoomCount: 3,
      approximateAreaDm2: areaDm2,
      bathroomCount: 1,
      separateWcCount: 0,
      balconyCount: 0,
      balconyKind: ApartmentBalconyKind.none,
      kitchenMode: ApartmentKitchenMode.separate,
      corridorMode: ApartmentCorridorMode.auto,
      exteriorExposurePreference: ApartmentExteriorExposurePreference.any,
    );

final class _ProjectFixture {
  const _ProjectFixture({
    required this.project,
    required this.target,
    required this.buildingId,
  });

  final ProjectAggregateRoot project;
  final LevelWizardTarget target;
  final BuildingId buildingId;
}

_ProjectFixture _projectFixture({bool withSpace = false}) {
  final projectId =
      ProjectId(withSpace ? 'project-non-empty' : 'project-empty');
  final siteId = SiteId(withSpace ? 'site-non-empty' : 'site-empty');
  final buildingId =
      BuildingId(withSpace ? 'building-non-empty' : 'building-empty');
  final levelId = LevelId(withSpace ? 'level-non-empty' : 'level-empty');
  final spaceId = SpaceId('existing-space');
  final level = ProjectLevelEntity(
    id: levelId,
    buildingId: buildingId,
    name: 'Level 1',
    levelNumber: 1,
    elevationMm: 3000,
    kind: ProjectLevelKind.residential,
    spaceIds: withSpace ? {spaceId} : const <SpaceId>{},
  );
  final stores = ProjectEntityStores(
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
    levels: {levelId: level},
    spaces: withSpace
        ? {
            spaceId: ProjectSpaceEntity(
              id: spaceId,
              levelId: levelId,
              name: 'Existing Bedroom',
              type: ProjectSpaceType.room,
              usage: SpaceUsage.bedroom,
            ),
          }
        : const {},
  );
  final version = LocalProjectVersion(7);
  final project = ProjectAggregateRoot(
    id: projectId,
    siteId: siteId,
    version: version,
    stores: stores,
  );
  return _ProjectFixture(
    project: project,
    buildingId: buildingId,
    target: LevelWizardTarget(
      projectId: projectId,
      siteId: siteId,
      baseVersion: version,
      buildingId: buildingId,
      levelId: levelId,
    ),
  );
}
