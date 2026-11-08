import 'package:elecx/src/domain/cable_spec.dart';
import 'package:elecx/src/domain/component_catalog_engineering_metadata.dart';
import 'package:elecx/src/domain/component_catalog_v2.dart';
import 'package:elecx/src/domain/component_placement.dart';
import 'package:elecx/src/domain/electrical_circuit_synthesis.dart';
import 'package:elecx/src/domain/electrical_load_calculation.dart';
import 'package:elecx/src/domain/engineering_graph.dart';
import 'package:elecx/src/domain/overcurrent_protection.dart';
import 'package:elecx/src/domain/power_board_catalog_qualification.dart';
import 'package:elecx/src/domain/power_starter_generation.dart';
import 'package:elecx/src/domain/route_medium.dart';
import 'package:elecx/src/engine/cable_sizing_engine.dart';
import 'package:elecx/src/engine/electrical_circuit_closure_engine.dart';
import 'package:elecx/src/engine/power_evidence_selection_engine.dart';
import 'package:elecx/src/engine/power_starter_board_catalog_engine.dart';
import 'package:elecx/src/engine/power_starter_generation_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P12A.7 source-pinned POWER cable/protection acceptance', () {
    test('selects a compatible cable and breaker while keeping Apply blocked',
        () {
      final preview = PowerEvidenceSelectionEngine.evaluate(_request());
      expect(preview.closure, isNotNull);
      expect(preview.closure!.isFullyClosed, isTrue);
      final selected = preview.closure!.outcomes.single;
      expect(selected.selectedCable!.cable.id, 'large');
      expect(selected.selectedProtection!.id, 'mcb-16');
      expect(selected.selectedCableSizing!.governingAmpacityA, 25);
      expect(preview.readyForEngineeringReview, isTrue);
      expect(preview.readyToApply, isFalse);
      expect(preview.issues, [
        PowerEvidenceSelectionIssue.boardElectricalRatingsUnverified,
      ]);
    });

    test('input permutations preserve selected pair and semantic fingerprint',
        () {
      final first = PowerEvidenceSelectionEngine.evaluate(_request());
      final second = PowerEvidenceSelectionEngine.evaluate(
        _request(reverseCandidates: true, reversePins: true),
      );
      expect(second.fingerprint, first.fingerprint);
      expect(second.closure!.outcomes.single.selectedCable!.cable.id, 'large');
      expect(second.closure!.outcomes.single.selectedProtection!.id, 'mcb-16');
    });

    test('an unapproved or wrong-revision catalog evidence blocks selection',
        () {
      final missing = PowerEvidenceSelectionEngine.evaluate(
        _request(omitImpedancePin: true),
      );
      expect(missing.closure, isNull);
      expect(
        missing.issues,
        contains(PowerEvidenceSelectionIssue.evidenceSourceUnapproved),
      );
      final stale = PowerEvidenceSelectionEngine.evaluate(
        _request(wrongCableRevision: true),
      );
      expect(stale.closure, isNull);
      expect(
        stale.issues,
        contains(PowerEvidenceSelectionIssue.evidenceSourceRevisionMismatch),
      );
    });

    test('normative, route and voltage-drop policy mismatch fail closed', () {
      final mismatchedPolicy = PowerEvidenceSelectionEngine.evaluate(
        _request(wrongNormativeRevision: true),
      );
      expect(mismatchedPolicy.closure, isNull);
      expect(
        mismatchedPolicy.issues,
        contains(PowerEvidenceSelectionIssue.normativeRevisionMismatch),
      );
      final wrongRoute = PowerEvidenceSelectionEngine.evaluate(
        _request(wrongRouteLength: true),
      );
      expect(wrongRoute.closure, isNull);
      expect(
        wrongRoute.issues,
        contains(PowerEvidenceSelectionIssue.routeLengthMismatch),
      );
      final wrongVoltageDrop = PowerEvidenceSelectionEngine.evaluate(
        _request(wrongVoltageDrop: true),
      );
      expect(wrongVoltageDrop.closure, isNull);
      expect(
        wrongVoltageDrop.issues,
        contains(PowerEvidenceSelectionIssue.voltageDropPolicyMismatch),
      );
    });

    test('no compatible breaker produces an unresolved engineering preview',
        () {
      final preview = PowerEvidenceSelectionEngine.evaluate(
        _request(protectionRatedCurrentA: 32),
      );
      expect(preview.closure, isNotNull);
      expect(preview.closure!.isFullyClosed, isFalse);
      expect(
        preview.issues,
        contains(PowerEvidenceSelectionIssue.noCompliantProtection),
      );
      expect(preview.readyForEngineeringReview, isFalse);
      expect(preview.readyToApply, isFalse);
    });

    test('source document digest changes invalidate the preview fingerprint',
        () {
      final before = PowerEvidenceSelectionEngine.evaluate(_request());
      final after = PowerEvidenceSelectionEngine.evaluate(
        _request(revisedCableSourceDigest: true),
      );
      expect(after.closure!.isFullyClosed, isTrue);
      expect(after.fingerprint, isNot(before.fingerprint));
      expect(after.board.candidate.fingerprint,
          before.board.candidate.fingerprint);
    });

    test(
        'unapproved correction factor blocks selection; approved factor is reviewed',
        () {
      final unapproved = PowerEvidenceSelectionEngine.evaluate(
        _request(useCorrectionFactor: true),
      );
      expect(unapproved.closure, isNull);
      expect(
        unapproved.issues,
        contains(PowerEvidenceSelectionIssue.correctionFactorNotApproved),
      );
      final approved = PowerEvidenceSelectionEngine.evaluate(
        _request(useCorrectionFactor: true, approveCorrectionFactor: true),
      );
      expect(approved.closure!.isFullyClosed, isTrue);
      expect(approved.readyToApply, isFalse);
    });

    test('an unqualified board blocks all circuit selection', () {
      final preview = PowerEvidenceSelectionEngine.evaluate(
        _request(boardQualified: false),
      );
      expect(preview.closure, isNull);
      expect(
        preview.issues,
        contains(PowerEvidenceSelectionIssue.boardTypeNotQualified),
      );
    });
  });
}

PowerEvidenceSelectionRequest _request({
  bool reverseCandidates = false,
  bool reversePins = false,
  bool omitImpedancePin = false,
  bool wrongCableRevision = false,
  bool wrongNormativeRevision = false,
  bool wrongRouteLength = false,
  bool wrongVoltageDrop = false,
  bool boardQualified = true,
  bool revisedCableSourceDigest = false,
  bool useCorrectionFactor = false,
  bool approveCorrectionFactor = false,
  double protectionRatedCurrentA = 16,
}) {
  final starter = PowerStarterGenerationEngine.generate(
    PowerStarterGenerationRequest(
      projectId: 'project-101',
      boardGenerationKey: 'board:101',
      catalogSnapshotId: 'catalog-v1',
      voltageEvidenceId: 'supply-review',
      voltageEvidenceRevision: 'r1',
      nominalVoltageV: 230,
      loads: const [
        CircuitSynthesisLoad(
          load: ElectricalLoadInput(
            id: 'load-1',
            ratedPowerW: 3000,
            quantity: 1,
            utilizationFactor: 1,
            powerFactor: 1,
            reactivePowerKind: ElectricalReactivePowerKind.lagging,
            sourceId: 'fixture-load',
            sourceRevision: 'r1',
          ),
          kind: ElectricalCircuitLoadKind.generalSocket,
          locationId: 'room-101',
          requiredPhaseSystem: ElectricalLoadPhaseSystem.singlePhaseAc,
        ),
      ],
      groupingPolicy: CircuitGroupingPolicy(
        id: 'grouping',
        maxGroupedLoadsPerCircuit: 3,
        maxGroupedConnectedPowerW: 5000,
        separateByLocation: false,
        separateByLoadKind: true,
        sourceId: 'profile',
        sourceRevision: 'r1',
      ),
      dedicatedCircuitPolicy: DedicatedCircuitPolicy(
        id: 'dedicated',
        rules: const [],
        sourceId: 'profile',
        sourceRevision: 'r1',
      ),
      diversityPolicy: const ElectricalDiversityPolicy(
        id: 'diversity',
        factor: 1,
        sourceId: 'profile',
        sourceRevision: 'r1',
      ),
      reservePolicy: ElectricalReservePolicy.none,
    ),
  );
  final board = _board(starter, qualified: boardQualified);
  final cables = <ElectricalCircuitCableCandidate>[
    _cable('small', 2.5,
        ampacityA: 15,
        sourceRevision: wrongCableRevision ? 'r2' : 'r1',
        lengthMm: wrongRouteLength ? 12000 : 10000,
        maxDrop: wrongVoltageDrop ? 0.06 : 0.05,
        useCorrectionFactor: useCorrectionFactor),
    _cable('large', 4, ampacityA: 25),
  ];
  if (reverseCandidates) {
    cables.replaceRange(0, cables.length, cables.reversed.toList());
  }
  final pins = [
    _pin('manual-route'),
    _pin('fault-survey'),
    _pin('cable-source', fill: revisedCableSourceDigest ? 'b' : 'a'),
    _pin('protection-source'),
    _pin('ampacity-source'),
    if (!omitImpedancePin) _pin('impedance-source'),
  ];
  if (reversePins) {
    pins.replaceRange(0, pins.length, pins.reversed.toList());
  }

  return PowerEvidenceSelectionRequest(
    board: board,
    normativeSource: _pin('normative-profile'),
    approvedSources: pins,
    bindings: [
      PowerCircuitEvidenceBinding(
        generationKey: starter.circuits.single.generationKey,
        routeLengthMm: 10000,
        routeEvidenceSourceId: 'manual-route',
        faultCurrentEvidenceSourceId: 'fault-survey',
        normativeMaxVoltageDropRatio: 0.05,
        approvedCorrectionFactorIds:
            approveCorrectionFactor ? const ['grouping'] : const [],
        policy: ElectricalCircuitClosurePolicy(
          circuitId: starter.circuits.single.calculated.id,
          cableCandidates: cables,
          minimumConductorCount: 3,
          allowedConductorMaterials: const {ConductorMaterial.copper},
          minimumCableRatedVoltageV: 450,
          prospectiveShortCircuitCurrentA: 3500,
          protectionCandidates: [
            OvercurrentProtectiveDeviceSpec(
              id: 'mcb-16',
              kind: OvercurrentDeviceKind.mcb,
              ratedCurrentA: protectionRatedCurrentA,
              breakingCapacityKa: 6,
              poleCount: 1,
              sourceId: 'protection-source',
              sourceRevision: 'r1',
            ),
          ],
          allowedProtectionKinds: const {OvercurrentDeviceKind.mcb},
          minimumProtectionPoleCount: 1,
          sourceId: 'normative-profile',
          sourceRevision: wrongNormativeRevision ? 'r2' : 'r1',
        ),
      ),
    ],
  );
}

PowerBoardCatalogQualification _board(
  PowerStarterCandidate starter, {
  required bool qualified,
}) {
  if (!qualified) {
    return PowerBoardCatalogQualification(
      candidate: starter,
      status: PowerBoardCatalogStatus.componentMissing,
      fingerprint: 'unqualified-board',
      requestedComponentTypeId: 'power.distribution-board.general',
    );
  }
  final entry = ComponentCatalogV2.require('power.distribution-board.general');
  final registry = ComponentCatalogEngineeringRegistry([
    ComponentCatalogEngineeringRecord(
      entry: entry,
      metadata: ComponentCatalogEngineeringMetadata(
        componentTypeId: entry.id,
        compatibility: ComponentCompatibilityProfile(
          systems: const {EngineeringSystemClass.powerAc},
          connections: const {
            EngineeringConnectionType.acSinglePhase,
            EngineeringConnectionType.acThreePhase,
          },
          hostKinds: const {ComponentHostKind.roomSurface},
        ),
        physicalEnvelope: ComponentPhysicalEnvelopeMm(
          widthMm: 400,
          heightMm: 300,
          depthMm: 150,
        ),
        source: ComponentCatalogSourceMetadata(
          manufacturer: 'TEST ONLY',
          model: 'fixture-board',
          revision: 'r1',
        ),
      ),
    ),
  ]);
  return PowerStarterBoardCatalogEngine.qualify(
    candidate: starter,
    catalogSnapshotId: 'catalog-v1',
    registry: registry,
    componentTypeId: entry.id,
    connectionType: EngineeringConnectionType.acSinglePhase,
    hostKind: ComponentHostKind.roomSurface,
  );
}

PowerEvidenceSourcePin _pin(String id, {String fill = 'a'}) =>
    PowerEvidenceSourcePin(
      sourceId: id,
      revision: 'r1',
      contentSha256: ''.padLeft(64, fill),
      approvalId: 'review:fixture',
    );

ElectricalCircuitCableCandidate _cable(
  String id,
  double area, {
  required double ampacityA,
  String sourceRevision = 'r1',
  double lengthMm = 10000,
  double maxDrop = 0.05,
  bool useCorrectionFactor = false,
}) =>
    ElectricalCircuitCableCandidate(
      cable: CableSpec(
        id: id,
        name: id,
        medium: RouteMediumProfile.acPower,
        outerDiameterMm: area + 8,
        segregationClass: CableSegregationClass.power,
        conductorMaterial: ConductorMaterial.copper,
        conductorCount: 3,
        conductorCrossSectionMm2: area,
        ratedVoltageV: 450,
      ),
      routeLengthMm: lengthMm,
      maxVoltageDropRatio: maxDrop,
      impedanceEvidence: const CableImpedanceEvidence(
        resistanceOhmPerKm: 4,
        sourceKey: 'impedance-source',
      ),
      ampacitySections: [
        SectionAmpacityEvidence(
          sectionId: 'wall',
          baseAmpacityA: ampacityA,
          factors: useCorrectionFactor
              ? const [ThermalCorrectionFactor(id: 'grouping', factor: 0.9)]
              : const [],
          sourceKey: 'ampacity-source',
        ),
      ],
      sourceId: 'cable-source',
      sourceRevision: sourceRevision,
    );
