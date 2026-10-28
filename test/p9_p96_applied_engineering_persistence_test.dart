import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_snapshot.dart';
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
import 'package:elecx/src/serialization/project/applied_engineering_proposal_aware_canonical_project_document_codec.dart';
import 'package:elecx/src/serialization/project/generation_provenance_aware_canonical_project_document_codec.dart';
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
  });

  test('Q97 Apply persists the exact frozen engineering proposal', () {
    final pipeline = _Pipeline(outputFingerprint: _sha('7'));
    final session = _session(
      fixture: fixture,
      provider: ApartmentWizardProvider(engineeringPipeline: pipeline),
    );
    _prepare(
      session: session,
      request: request,
      selection: candidateSet.selectionFor(candidateSet.candidates.first),
    );

    expect(session.generatePreview(), isTrue);
    final command = session.generatedCommand as ApartmentReservedProjectCommand;
    final proposal = command.engineeringProposal!;
    expect(session.confirm(), isTrue);

    final applied = session.commitResult!.mutation.project.engineeringMetadata
        .appliedEngineeringProposalRegistry
        .forLevel(fixture.target.levelId);
    expect(applied, isNotNull);
    expect(applied!.proposalFingerprint, proposal.proposalFingerprint);
    expect(applied.outputFingerprint, proposal.output.outputFingerprint);
    expect(
      applied.requirementsFingerprint,
      proposal.output.requirementsFingerprint,
    );
    expect(
      applied.panelSummary,
      proposal.output.panelSummary.stableSerialization,
    );
    expect(pipeline.callCount, 1);
  });

  test('Q98 geometry-only Apply does not invent engineering persistence', () {
    final session = _session(
      fixture: fixture,
      provider: const ApartmentWizardProvider.geometryOnly(),
    );
    _prepare(
      session: session,
      request: request,
      selection: candidateSet.selectionFor(candidateSet.candidates.first),
    );

    expect(session.generatePreview(), isTrue);
    expect(session.confirm(), isTrue);

    expect(
      session.commitResult!.mutation.project.engineeringMetadata
          .appliedEngineeringProposalRegistry
          .forLevel(fixture.target.levelId),
      isNull,
    );
  });

  test('Q99 schema v13 save/load preserves the applied proposal snapshot', () {
    final pipeline = _Pipeline(outputFingerprint: _sha('8'));
    final session = _session(
      fixture: fixture,
      provider: ApartmentWizardProvider(engineeringPipeline: pipeline),
    );
    _prepare(
      session: session,
      request: request,
      selection: candidateSet.selectionFor(candidateSet.candidates.first),
    );
    expect(session.generatePreview(), isTrue);
    expect(session.confirm(), isTrue);
    final aggregate = session.commitResult!.mutation.project;
    final before = aggregate
        .engineeringMetadata.appliedEngineeringProposalRegistry
        .forLevel(fixture.target.levelId)!;
    final now = DateTime.utc(2026, 10, 27);
    final projectSnapshot = ProjectSnapshot(
      aggregate: aggregate,
      name: 'P9.6 persistence',
      createdAt: now,
      updatedAt: now,
    );

    const codec =
        AppliedEngineeringProposalAwareCanonicalProjectDocumentCodec();
    final document = codec.encode(projectSnapshot);
    final decoded = codec.decode(document);
    final after = decoded
        .aggregate.engineeringMetadata.appliedEngineeringProposalRegistry
        .forLevel(fixture.target.levelId);

    expect(document.schemaVersion, 13);
    expect(after, isNotNull);
    expect(after!.sameAs(before), isTrue);
  });

  test('Q100 v12 documents migrate with an explicit empty proposal registry',
      () {
    final now = DateTime.utc(2026, 10, 27);
    final snapshot = ProjectSnapshot(
      aggregate: fixture.project,
      name: 'P9.6 v12 compatibility',
      createdAt: now,
      updatedAt: now,
    );
    const oldCodec = GenerationProvenanceAwareCanonicalProjectDocumentCodec();
    final oldDocument = oldCodec.encode(snapshot);

    const newCodec =
        AppliedEngineeringProposalAwareCanonicalProjectDocumentCodec();
    final decoded = newCodec.decode(oldDocument);

    expect(oldDocument.schemaVersion, 12);
    expect(
      decoded.aggregate.engineeringMetadata.appliedEngineeringProposalRegistry
          .byLevel,
      isEmpty,
    );
  });

  test('Q101 Undo and Redo restore the exact frozen engineering snapshot', () {
    final pipeline = _Pipeline(outputFingerprint: _sha('9'));
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
    _prepare(
      session: session,
      request: request,
      selection: candidateSet.selectionFor(candidateSet.candidates.first),
    );

    expect(session.generatePreview(), isTrue);
    final command = session.generatedCommand as ApartmentReservedProjectCommand;
    final proposal = command.engineeringProposal!;
    expect(session.confirm(), isTrue);
    final applied = mutations.current.engineeringMetadata
        .appliedEngineeringProposalRegistry
        .forLevel(fixture.target.levelId);
    expect(applied, isNotNull);
    expect(applied!.proposalFingerprint, proposal.proposalFingerprint);
    expect(applied.outputFingerprint, proposal.output.outputFingerprint);

    final undo = mutations.undo(mutations.current.version);
    expect(undo, isNotNull);
    expect(
      mutations.current.engineeringMetadata.appliedEngineeringProposalRegistry
          .forLevel(fixture.target.levelId),
      isNull,
    );

    final redo = mutations.redo(mutations.current.version);
    expect(redo, isNotNull);
    final restored = mutations.current.engineeringMetadata
        .appliedEngineeringProposalRegistry
        .forLevel(fixture.target.levelId);
    expect(restored, isNotNull);
    expect(restored!.sameAs(applied), isTrue);
    expect(restored.proposalFingerprint, proposal.proposalFingerprint);
    expect(restored.outputFingerprint, proposal.output.outputFingerprint);
    expect(pipeline.callCount, 1);
  });
}

final class _Pipeline implements ApartmentEngineeringPipeline {
  _Pipeline({required this.outputFingerprint});

  final String outputFingerprint;
  int callCount = 0;

  @override
  ApartmentEngineeringProposal generate({
    required String candidateSetFingerprint,
    required ApartmentCandidateCard selected,
    required WizardGenerationContext context,
  }) {
    callCount++;
    final requirements = selected.engineeringRequirements;
    return ApartmentEngineeringProposal.bind(
      candidateSetFingerprint: candidateSetFingerprint,
      selected: selected,
      output: ApartmentEngineeringOutputProjection(
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
      ),
    );
  }
}

WizardSession _session({
  required _ProjectFixture fixture,
  required ApartmentWizardProvider provider,
}) {
  final mutations = ProjectMutationSession(fixture.project);
  return WizardSession(
    target: fixture.target,
    registry: WizardProviderRegistry([provider]),
    mutations: SharedProjectWizardMutationPort(
      mutations: mutations,
      idFactory: SecureRandomEntityIdFactory(),
    ),
  );
}

void _prepare({
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
  const _ProjectFixture({required this.project, required this.target});

  final ProjectAggregateRoot project;
  final LevelWizardTarget target;
}

_ProjectFixture _projectFixture() {
  final projectId = ProjectId('p96-persist-project');
  final siteId = SiteId('p96-persist-site');
  final buildingId = BuildingId('p96-persist-building');
  final levelId = LevelId('p96-persist-level');
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
  final version = LocalProjectVersion(11);
  return _ProjectFixture(
    project: ProjectAggregateRoot(
      id: projectId,
      siteId: siteId,
      version: version,
      stores: stores,
    ),
    target: LevelWizardTarget(
      projectId: projectId,
      siteId: siteId,
      baseVersion: version,
      buildingId: buildingId,
      levelId: levelId,
    ),
  );
}
