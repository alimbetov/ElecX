import 'package:elecx/src/application/project/wizard/apartment/apartment_candidate_set_service.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_engineering_output_projection.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_engineering_pipeline.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_engineering_requirements_adapter.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_wizard_parameters.dart';
import 'package:elecx/src/application/project/wizard/wizard_contracts.dart';
import 'package:elecx/src/domain/apartment_topology.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/features/projects/apartment_engineering_preview_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'Q105 topology-only preview states that electrical values are absent',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 900,
            height: 700,
            child: ApartmentEngineeringPreviewPanel(proposal: null),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('apartment-engineering-topology-only')),
      findsOneWidget,
    );
    expect(find.text('Topology-only preview'), findsOneWidget);
    expect(find.textContaining('No electrical values are assumed'),
        findsOneWidget);
  });

  testWidgets('Q106 frozen D8 preview exposes circuit protection SLD and Why',
      (tester) async {
    final fixture = _projectFixture();
    final request = _request();
    final generated = const ApartmentCandidateSetService().generate(
      input: request,
      target: fixture.target,
      project: fixture.project,
    );
    expect(generated.accepted, isTrue);
    final set = generated.candidateSet!;
    final selected = set.candidates.first;
    final requirements = selected.engineeringRequirements;
    final proposal = ApartmentEngineeringProposal.bind(
      candidateSetFingerprint: set.candidateSetFingerprint,
      selected: selected,
      output: ApartmentEngineeringOutputProjection(
        loadSchedule: const [
          ApartmentEngineeringLoadScheduleRow(
            circuitId: 'C1',
            loadId: 'load.lighting',
            assignedPhase: 'L1',
            kind: 'lighting',
            locationId: 'room.living',
            connectedPowerW: 1200,
            utilizedPowerW: 960,
            utilizedReactivePowerVar: 0,
            sourceId: 'authoritative-loads',
            sourceRevision: '2026.10',
          ),
        ],
        circuitSchedule: [
          ApartmentEngineeringCircuitScheduleRow(
            circuitId: 'C1',
            phaseSystem: 'singlePhase',
            assignedPhase: 'L1',
            loadIds: const ['load.lighting'],
            connectedPowerW: 1200,
            designPowerW: 960,
            designReactivePowerVar: 0,
            designApparentPowerVa: 960,
            designCurrentA: 4.17,
            nominalVoltageV: 230,
            cableId: 'cable.cu.3x1.5',
            cableName: 'Cu 3x1.5',
            conductorMaterial: 'copper',
            conductorCount: 3,
            conductorCrossSectionMm2: 1.5,
            routeLengthMm: 18000,
            governingAmpacityA: 18.5,
            governingSectionId: 'section.main',
            voltageDropV: 2.1,
            voltageDropRatio: 0.0091,
            overcurrentDeviceId: 'mcb.b10',
            overcurrentDeviceKind: 'MCB',
            overcurrentRatedCurrentA: 10,
            overcurrentBreakingCapacityKa: 6,
            overcurrentPoleCount: 1,
            prospectiveShortCircuitCurrentA: 2400,
            minimumFaultCurrentA: 180,
            maximumFaultCurrentA: 2400,
            disconnectionOperatingTimeS: 0.08,
            requiredMaxDisconnectionTimeS: 0.4,
            faultEnergyA2s: 8200,
            thermalCapacityA2s: 16875,
            residualApplicability: 'required',
            residualDeviceId: 'rcbo.b10.30ma',
            residualDeviceKind: 'RCBO',
            residualType: 'A',
            residualOperatingCurrentMa: 30,
            overcurrentCoordinationStatus: 'proven',
            overcurrentCoordinationEvidenceId: 'coord.ocpd.c1',
            residualCoordinationStatus: 'proven',
            residualCoordinationEvidenceId: 'coord.rcd.c1',
            installationSections: const [
              ApartmentEngineeringInstallationSectionOutput(
                sectionId: 'section.main',
                installationMethodId: 'B2',
                ampacitySourceKey: 'IEC60364-B2-Cu-PVC',
                sourceId: 'installation-policy',
                sourceRevision: '2026.10',
              ),
            ],
          ),
        ],
        panelSummary: ApartmentEngineeringPanelSummary(
          boardPhaseSystem: 'singlePhase',
          lineNeutralVoltageV: 230,
          lineLineVoltageV: null,
          maxPhaseCurrentA: 4.17,
          phaseCurrentImbalanceRatio: 0,
          branchCircuitCount: 1,
          phaseLoads: const [
            ApartmentEngineeringPhaseSummary(
              phase: 'L1',
              designPowerW: 960,
              designReactivePowerVar: 0,
              designCurrentA: 4.17,
            ),
          ],
        ),
        sldNodes: const [
          ApartmentEngineeringSldNode(
            id: 'node.board',
            kind: ApartmentEngineeringSldNodeKind.board,
            circuitId: null,
            referenceId: 'DB-1',
          ),
          ApartmentEngineeringSldNode(
            id: 'node.c1.protection',
            kind: ApartmentEngineeringSldNodeKind.combinedProtection,
            circuitId: 'C1',
            referenceId: 'rcbo.b10.30ma',
          ),
          ApartmentEngineeringSldNode(
            id: 'node.c1.load',
            kind: ApartmentEngineeringSldNodeKind.loadGroup,
            circuitId: 'C1',
            referenceId: 'load.lighting',
          ),
        ],
        sldEdges: const [
          ApartmentEngineeringSldEdge(
            id: 'edge.c1.1',
            fromNodeId: 'node.board',
            toNodeId: 'node.c1.protection',
            circuitId: 'C1',
          ),
          ApartmentEngineeringSldEdge(
            id: 'edge.c1.2',
            fromNodeId: 'node.c1.protection',
            toNodeId: 'node.c1.load',
            circuitId: 'C1',
          ),
        ],
        explanations: const [
          ApartmentEngineeringExplanation(
            code: 'P9.WHY.CABLE_AMPACITY',
            circuitId: 'C1',
            value:
                'Cable satisfies governing ampacity and voltage-drop limits.',
            sourceId: 'cable-policy',
            sourceRevision: '2026.10',
          ),
        ],
        requirementsFingerprint: requirements.requirementsFingerprint,
        outputFingerprint: _sha('6'),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1100,
            height: 1400,
            child: ApartmentEngineeringPreviewPanel(proposal: proposal),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('apartment-engineering-preview')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('apartment-engineering-circuit-C1')),
      findsOneWidget,
    );
    expect(find.text('Cable'), findsOneWidget);
    expect(find.text('Overcurrent protection'), findsOneWidget);
    expect(find.text('RCD / residual protection'), findsOneWidget);

    // Collapse the expanded circuit after qualifying its detail rows. This
    // exposes the lower SLD/Why sections without coupling the test to
    // ListView's internal Scrollable implementation or viewport lazy-loading.
    await tester.tap(find.text('C1 · L1'));
    await tester.pumpAndSettle();

    expect(find.text('Single-line diagram'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('apartment-engineering-sld-node-node.board')),
      findsOneWidget,
    );
    expect(find.text('Why'), findsOneWidget);
    expect(find.text('P9.WHY.CABLE_AMPACITY'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('apartment-engineering-fingerprints')),
      findsOneWidget,
    );
  });
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
  final projectId = ProjectId('p96-preview-project');
  final siteId = SiteId('p96-preview-site');
  final buildingId = BuildingId('p96-preview-building');
  final levelId = LevelId('p96-preview-level');
  final version = LocalProjectVersion(2);
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
