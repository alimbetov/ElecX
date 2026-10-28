import 'dart:io';

import 'package:elecx/src/application/project/canonical_project_persistence_owner.dart';
import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_snapshot.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_candidate_set_service.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_engineering_output_integrity.dart';
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
import 'package:elecx/src/infrastructure/project/json_project_repository.dart';
import 'package:elecx/src/serialization/project/applied_engineering_proposal_aware_canonical_project_document_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Q104 production persistence owner reloads exact applied engineering snapshot',
    () async {
      final temp = await Directory.systemTemp.createTemp('elecx-p9-p96-');
      addTearDown(() async {
        if (await temp.exists()) await temp.delete(recursive: true);
      });

      final fixture = _projectFixture();
      final repository = JsonProjectRepository(
        rootDirectory: temp,
        codec:
            const AppliedEngineeringProposalAwareCanonicalProjectDocumentCodec(),
      );
      final now = DateTime.utc(2026, 10, 28, 2, 30);
      final owner = CanonicalProjectPersistenceOwner(
        snapshot: ProjectSnapshot(
          aggregate: fixture.project,
          name: 'P9.6 production reload',
          createdAt: now,
          updatedAt: now,
        ),
        repository: repository,
      );
      final mutations = ProjectMutationSession(fixture.project);
      final pipeline = _Pipeline();
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

      final request = _request();
      final generated = const ApartmentCandidateSetService().generate(
        input: request,
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
            request: request,
            selection: set.selectionFor(set.candidates.first),
          ),
        ),
        isTrue,
      );
      expect(session.generatePreview(), isTrue);
      final command =
          session.generatedCommand as ApartmentReservedProjectCommand;
      final frozen = command.engineeringProposal!;
      expect(session.confirm(), isTrue);
      final committed = session.commitResult!.mutation;

      owner.acceptMutation(
        sessionProject: committed.project,
        result: committed,
        now: now.add(const Duration(minutes: 1)),
      );
      final beforeSave = owner
          .project.engineeringMetadata.appliedEngineeringProposalRegistry
          .forLevel(fixture.target.levelId);
      expect(beforeSave, isNotNull);
      expect(beforeSave!.proposalFingerprint, frozen.proposalFingerprint);
      expect(beforeSave.outputFingerprint, frozen.output.outputFingerprint);
      expect(
        committed.changeSet.engineeringMetadataDiff
            .appliedEngineeringProposalRegistryChanged,
        isTrue,
      );

      await owner.save();
      final loaded = await CanonicalProjectPersistenceOwner.load(
        repository: repository,
        projectId: fixture.project.id,
      );
      expect(loaded, isNotNull);
      final afterReload = loaded!
          .project.engineeringMetadata.appliedEngineeringProposalRegistry
          .forLevel(fixture.target.levelId);
      expect(afterReload, isNotNull);
      expect(afterReload!.sameAs(beforeSave), isTrue);
      expect(afterReload.proposalFingerprint, frozen.proposalFingerprint);
      expect(afterReload.outputFingerprint, frozen.output.outputFingerprint);
      expect(loaded.version, committed.project.version);
      expect(pipeline.callCount, 1);
    },
  );
}

final class _Pipeline implements ApartmentEngineeringPipeline {
  int callCount = 0;

  @override
  ApartmentEngineeringProposal generate({
    required String candidateSetFingerprint,
    required ApartmentCandidateCard selected,
    required WizardGenerationContext context,
  }) {
    callCount++;
    final requirements = selected.engineeringRequirements;
    final panelSummary = ApartmentEngineeringPanelSummary(
      boardPhaseSystem: 'singlePhase',
      lineNeutralVoltageV: 230,
      lineLineVoltageV: null,
      maxPhaseCurrentA: 4,
      phaseCurrentImbalanceRatio: 0,
      branchCircuitCount: 0,
      phaseLoads: const [],
    );
    final outputFingerprint = computeApartmentEngineeringOutputFingerprint(
      outputProjectionVersion: apartmentEngineeringOutputProjectionVersion,
      requirementsFingerprint: requirements.requirementsFingerprint,
      loadScheduleRows: const [],
      circuitScheduleRows: const [],
      panelSummary: panelSummary.stableSerialization,
      sldNodes: const [],
      sldEdges: const [],
      explanations: const [],
    );
    return ApartmentEngineeringProposal.bind(
      candidateSetFingerprint: candidateSetFingerprint,
      selected: selected,
      output: ApartmentEngineeringOutputProjection(
        loadSchedule: const [],
        circuitSchedule: const [],
        panelSummary: panelSummary,
        sldNodes: const [],
        sldEdges: const [],
        explanations: const [],
        requirementsFingerprint: requirements.requirementsFingerprint,
        outputFingerprint: outputFingerprint,
      ),
    );
  }
}

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
  final projectId = ProjectId('p96-production-persistence-project');
  final siteId = SiteId('p96-production-persistence-site');
  final buildingId = BuildingId('p96-production-persistence-building');
  final levelId = LevelId('p96-production-persistence-level');
  final version = LocalProjectVersion(3);
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
          spaceIds: const {},
        ),
      },
    ),
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
