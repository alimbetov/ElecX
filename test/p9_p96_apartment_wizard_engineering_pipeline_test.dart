import 'dart:convert';

import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_candidate_set_service.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_engineering_output_projection.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_engineering_pipeline.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_engineering_requirements_adapter.dart';
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
    test('Q91 Generate runs engineering pipeline once and freezes proposal',
        () {
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
      final command =
          session.generatedCommand as ApartmentReservedProjectCommand;
      expect(command.hasEngineeringProposal, isTrue);
      expect(
        command.engineeringProposal!.candidateFingerprint,
        card.candidateFingerprint,
      );
      expect(
        command.engineeringProposal!.candidateSetFingerprint,
        candidateSet.candidateSetFingerprint,
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

      final command =
          session.generatedCommand as ApartmentReservedProjectCommand;
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
      const provider = ApartmentWizardProvider.geometryOnly();
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
      expect(
        firstIntent['engineeringProposalFingerprint'],
        first.engineeringProposal!.proposalFingerprint,
      );
      expect(
        firstIntent['engineeringOutputFingerprint'],
        first.engineeringProposal!.output.outputFingerprint,
      );
      expect(first.normalizedIntentKey, isNot(second.normalizedIntentKey));
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

    test('Q102 stale canonical version blocks frozen preview commit', () {
      final pipeline = _CountingPipeline(outputFingerprint: _sha('1'));
      final mutations = ProjectMutationSession(fixture.project);
      final session = WizardSession(
        target: fixture.target,
        registry: WizardProviderRegistry([
          ApartmentWizardProvider.production(engineeringPipeline: pipeline),
        ]),
        mutations: SharedProjectWizardMutationPort(
          mutations: mutations,
          idFactory: SecureRandomEntityIdFactory(),
        ),
      );
      _prepareSelection(
        session: session,
        request: request,
        selection: candidateSet.selectionFor(candidateSet.candidates.first),
      );
      expect(session.generatePreview(), isTrue);
      expect(pipeline.callCount, 1);

      final externalMutation = mutations.commit(
        ProjectMutationRequest(
          expectedVersion: mutations.current.version,
          command: const _RenameSiteCommand('Site changed elsewhere'),
        ),
      );
      expect(externalMutation, isNotNull);

      expect(session.confirm(), isFalse);
      expect(session.status, WizardSessionStatus.previewBlocked);
      expect(session.blockReason, WizardPreviewBlockReason.staleBaseVersion);
      expect(session.commitResult, isNull);
      expect(pipeline.callCount, 1);
      expect(
        mutations.current.engineeringMetadata.appliedEngineeringProposalRegistry
            .forLevel(fixture.target.levelId),
        isNull,
      );
    });

    test('Q103 tampered candidate-set lineage is rejected before Preview', () {
      final session = _session(
        fixture: fixture,
        provider: ApartmentWizardProvider.production(
          engineeringPipeline: _WrongLineagePipeline(),
        ),
      );
      _prepareSelection(
        session: session,
        request: request,
        selection: candidateSet.selectionFor(candidateSet.candidates.first),
      );

      expect(session.generatePreview(), isFalse);
      expect(session.status, WizardSessionStatus.failed);
      expect(session.generatedCommand, isNull);
      expect(session.preview, isNull);
      expect(session.failure, isNotNull);
      expect(session.failure.toString(), contains('engineering-pipeline-invalid'));
    });
  });
}

final class _CountingPipeline implements ApartmentEngineeringPipeline {
  _CountingPipeline({required this.outputFingerprint});

  final String outputFingerprint;
  int callCount = 0;

  @override
  ApartmentEngineeringProposal generate({
    required String candidateSetFingerprint,
    required ApartmentCandidateCard selected,
    required WizardGenerationContext context,
  }) {
    callCount++;
    return _proposal(
      candidateSetFingerprint: candidateSetFingerprint,
      selected: selected,
      outputFingerprint: outputFingerprint,
    );
  }
}

final class _WrongLineagePipeline implements ApartmentEngineeringPipeline {
  @override
  ApartmentEngineeringProposal generate({
    required String candidateSetFingerprint,
    required ApartmentCandidateCard selected,
    required WizardGenerationContext context,
  }) =>
      _proposal(
        candidateSetFingerprint: _sha('0'),
        selected: selected,
        outputFingerprint: _sha('2'),
      );
}

ApartmentEngineeringProposal _proposal({
  required String candidateSetFingerprint,
  required ApartmentCandidateCard selected,
  required String outputFingerprint,
}) {
  final requirements = selected.engineeringRequirements;
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
    candidateSetFingerprint: candidateSetFingerprint,
    selected: selected,
    output: output,
  );
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

final class _RenameSiteCommand implements ProjectCommand {
  const _RenameSiteCommand(this.name);

  final String name;

  @override
  String get commandType => 'test.rename-site';

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) {
    final site = current.stores.sites[current.siteId]!;
    return ProjectCommandCandidate(
      stores: ProjectEntityStores(
        sites: {
          ...current.stores.sites,
          current.siteId: ProjectSiteEntity(
            id: site.id,
            name: name,
            buildingIds: site.buildingIds,
          ),
        },
        buildings: current.stores.buildings,
        levels: current.stores.levels,
        slabs: current.stores.slabs,
        verticalCores: current.stores.verticalCores,
        zones: current.stores.zones,
        spaces: current.stores.spaces,
        openings: current.stores.openings,
        adjacencies: current.stores.adjacencies,
        overlays: current.stores.overlays,
        boundaries: current.stores.boundaries,
      ),
      affectedEntityIds: {site.id},
    );
  }
}
