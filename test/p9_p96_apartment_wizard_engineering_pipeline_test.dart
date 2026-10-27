import 'dart:convert';

import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_candidate_set_service.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_engineering_output_projection.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_engineering_pipeline.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_wizard_parameters.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_wizard_provider.dart';
import 'package:elecx/src/application/project/wizard/project_wizard_mutation_port.dart';
import 'package:elecx/src/application/project/wizard/wizard_contracts.dart';
import 'package:elecx/src/application/project/wizard/wizard_session.dart';
import 'package:elecx/src/domain/apartment_topology.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _ProjectFixture fixture;
  late ApartmentRequestInput request;
  late ApartmentCandidateSet candidateSet;

  setUpAll(() {
    fixture = _projectFixture();
    request = _request();
    final generated = const ApartmentCandidateSetService().generate(
      input: request,
      target: fixture.target,
      project: fixture.project,
    );
    expect(generated.accepted, isTrue);
    candidateSet = generated.candidateSet!;
    expect(candidateSet.candidates, isNotEmpty);
  });

  group('P9.6 Generate -> Preview/Diff -> Apply engineering lifecycle', () {
    test('Q91 Generate runs engineering pipeline once and freezes proposal', () {
      final pipeline = _CountingPipeline(outputFingerprint: _sha('b'));
      final session = _session(
        fixture: fixture,
        provider: ApartmentWizardProvider(engineeringPipeline: pipeline),
      );
      final card = candidateSet.candidates.first;

      _prepareSelection(
        session: session,
        request: request,
        selection: candidateSet.selectionFor(card),
      );
      expect(session.generatePreview(), isTrue);

      expect(pipeline.callCount, 1);
      final command = session.generatedCommand as ApartmentReservedProjectCommand;
      expect(command.hasEngineeringProposal, isTrue);
      expect(
        command.engineeringProposal!.candidateFingerprint,
        card.candidateFingerprint,
      );
      expect(
        command.engineeringProposal!.output.outputFingerprint,
        _sha('b'),
      );
    });

    test('Q92 Preview exposes exact frozen D8 projection', () {
      final pipeline = _CountingPipeline(outputFingerprint: _sha('c'));
      final session = _session(
        fixture: fixture,
        provider: ApartmentWizardProvider(engineeringPipeline: pipeline),
      );
      final card = candidateSet.candidates.first;

      _prepareSelection(
        session: session,
        request: request,
        selection: candidateSet.selectionFor(card),
      );
      expect(session.generatePreview(), isTrue);

      final command = session.generatedCommand as ApartmentReservedProjectCommand;
      final proposal = command.engineeringProposal!;
      expect(session.preview, isNotNull);
      expect(session.preview!.normalizedIntentKey, command.normalizedIntentKey);
      expect(proposal.output.outputFingerprint, _sha('c'));
      expect(proposal.output.requirementsFingerprint, isNotEmpty);
      expect(proposal.proposalFingerprint, hasLength(64));
    });

    test('Q93 Apply commits frozen preview without rerunning engineering', () {
      final pipeline = _CountingPipeline(outputFingerprint: _sha('d'));
      final session = _session(
        fixture: fixture,
        provider: ApartmentWizardProvider(engineeringPipeline: pipeline),
      );

      _prepareSelection(
        session: session,
        request: request,
        selection: candidateSet.selectionFor(candidateSet.candidates.first),
      );
      expect(session.generatePreview(), isTrue);
      expect(pipeline.callCount, 1);

      expect(session.confirm(), isTrue);

      expect(pipeline.callCount, 1);
      expect(session.status, WizardSessionStatus.completed);
      expect(session.commitResult, isNotNull);
      expect(
        session.commitResult!.mutation.project.version.value,
        fixture.project.version.value + 1,
      );
    });

    test('Q94 geometry-only provider remains source-compatible', () {
      const provider = ApartmentWizardProvider();
      final card = candidateSet.candidates.first;
      final command = provider.generateTyped(
        ApartmentWizardParameters(
          request: request,
          selection: candidateSet.selectionFor(card),
        ),
        WizardGenerationContext(
          target: fixture.target,
          project: fixture.project,
        ),
      ) as ApartmentReservedProjectCommand;

      expect(command.hasEngineeringProposal, isFalse);
      expect(command.engineeringProposal, isNull);
    });

    test('Q95 engineering output fingerprint participates in reserved intent',
        () {
      final card = candidateSet.candidates.first;
      final parameters = ApartmentWizardParameters(
        request: request,
        selection: candidateSet.selectionFor(card),
      );
      final context = WizardGenerationContext(
        target: fixture.target,
        project: fixture.project,
      );
      final first = ApartmentWizardProvider(
        engineeringPipeline: _CountingPipeline(outputFingerprint: _sha('e')),
      ).generateTyped(parameters, context) as ApartmentReservedProjectCommand;
      final second = ApartmentWizardProvider(
        engineeringPipeline: _CountingPipeline(outputFingerprint: _sha('f')),
      ).generateTyped(parameters, context) as ApartmentReservedProjectCommand;

      final firstIntent = jsonDecode(first.normalizedIntentKey) as Map;
      final secondIntent = jsonDecode(second.normalizedIntentKey) as Map;
      expect(
        firstIntent['engineeringProposalFingerprint'],
        first.engineeringProposal!.proposalFingerprint,
      );
      expect(
        firstIntent['engineeringOutputFingerprint'],
        first.engineeringProposal!.output.outputFingerprint,
      );
      expect(
        first.normalizedIntentKey,
        isNot(second.normalizedIntentKey),
      );
    });

    test('Q96 Back discards the frozen engineering preview command', () {
      final session = _session(
        fixture: fixture,
        provider: ApartmentWizardProvider(
          engineeringPipeline: _CountingPipeline(outputFingerprint: _sha('a')),
        ),
      );

      _prepareSelection(
        session: session,
        request: request,
        selection: candidateSet.selectionFor(candidateSet.candidates.first),
      );
      expect(session.generatePreview(), isTrue);
      expect(session.generatedCommand, isNotNull);

      expect(session.back(), isTrue);

      expect(session.generatedCommand, isNull);
      expect(session.preview, isNull);
      expect(session.status, WizardSessionStatus.editingParameters);
    });
  });
}

final class _CountingPipeline implements ApartmentEngineeringPipeline {
  _CountingPipeline({required this.outputFingerprint});

  final String outputFingerprint;
  int callCount = 0;

  @override
  ApartmentEngineeringProposal generate({
    required ApartmentCandidateCard selected,
    required WizardGenerationContext context,
  }) {
    callCount++;
    final requirements = selected.engineeringRequirements.requirements!;
    final output = ApartmentEngineeringOutputProjection(
      loadSchedule: const [],
      circuitSchedule: const [],
      panelSummary: ApartmentEngineeringPanelSummary(
        boardPhaseSystem: 'singlePhase',
        lineNeutralVoltageV: 230,
        lineLineVoltageV: null,
        maxPhaseCurrentA: 0,
        phaseCurrentImbalanceRatio: 0,
        branchCircuitCount: 0,
        phaseLoads: const [],
      ),
      sldNodes: const [],
      sldEdges: const [],
      explanations: const [],
      requirementsFingerprint: requirements.requirementsFingerprint,
      outputFingerprint: outputFingerprint,
    );
    return ApartmentEngineeringProposal.bind(
      selected: selected,
      output: output,
    );
  }
}

WizardSession _session({
  required _ProjectFixture fixture,
  required ApartmentWizardProvider provider,
}) {
  final mutations = ProjectMutationSession(fixture.project);
  final port = SharedProjectWizardMutationPort(
    mutations: mutations,
    idFactory: SecureRandomEntityIdFactory(),
  );
  return WizardSession(
    target: fixture.target,
    registry: WizardProviderRegistry([provider]),
    mutations: port,
  );
}

void _prepareSelection({
  required WizardSession session,
  required ApartmentRequestInput request,
  required ApartmentCandidateSelection selection,
}) {
  expect(session.begin(), isTrue);
  expect(session.selectFamily(ApartmentWizardProvider.familyId), isTrue);
  expect(
    session.updateParameters(
      ApartmentWizardParameters(request: request, selection: selection),
    ),
    isTrue,
  );
}

String _sha(String character) => List.filled(64, character).join();

ApartmentRequestInput _request() => ApartmentRequestInput(
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

final class _ProjectFixture {
  const _ProjectFixture({
    required this.project,
    required this.target,
  });

  final ProjectAggregateRoot project;
  final LevelWizardTarget target;
}

_ProjectFixture _projectFixture() {
  final projectId = ProjectId('p96-project');
  final siteId = SiteId('p96-site');
  final buildingId = BuildingId('p96-building');
  final levelId = LevelId('p96-level');
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
    target: LevelWizardTarget(
      projectId: projectId,
      siteId: siteId,
      baseVersion: version,
      buildingId: buildingId,
      levelId: levelId,
    ),
  );
}
