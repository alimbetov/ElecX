import 'dart:convert';
import 'dart:io';

import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_mutation_reservation.dart';
import 'package:elecx/src/application/project/engineering/canonical_power_evidence_preflight.dart';
import 'package:elecx/src/application/project/engineering/engineering_evidence_review_gate.dart';
import 'package:elecx/src/application/project/engineering/engineering_proposal_diff.dart';
import 'package:elecx/src/application/project/engineering/engineering_reserved_project_command.dart';
import 'package:elecx/src/application/project/engineering/power_electrical_safety_gate.dart';
import 'package:elecx/src/application/project/engineering/power_fault_envelope_gate.dart';
import 'package:elecx/src/domain/canonical_engineering_graph.dart';
import 'package:elecx/src/domain/canonical_power_selection.dart';
import 'package:elecx/src/domain/engineering_circuit_topology.dart';
import 'package:elecx/src/domain/engineering_graph.dart';
import 'package:elecx/src/domain/engineering_project_state.dart';
import 'package:elecx/src/domain/engineering_supply_topology.dart';
import 'package:elecx/src/infrastructure/project/json_project_repository.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/semantic_sha256.dart';
import 'package:elecx/src/serialization/project/engineering_state_aware_canonical_project_document_codec.dart';
import 'package:elecx/src/serialization/project/power_selection_aware_canonical_project_document_codec.dart';
import 'package:elecx/src/serialization/project/project_document_codec.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/p1010_service_anchor_fixture.dart';
import 'support/p109_site_fixture.dart';

const digest =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

CanonicalEngineeringSourceReference source(String id) =>
    CanonicalEngineeringSourceReference(
      sourceId: id,
      revision: 'rev-1',
      sha256: digest,
      approvalId: 'approval-1',
    );

CanonicalPowerCircuitSelection selection(String id, {
  double boardFaultWithstandKa = 6,
  double cableRatedVoltageV = 450,
}) => CanonicalPowerCircuitSelection(
      circuitId: CircuitId(id),
      generationKey: 'generation-$id',
      boardComponentId: ComponentId('board-1'),
      boardCatalogTypeId: 'board-type-v2',
      catalogSnapshotId: 'catalog-snapshot-v2',
      boardRatings: CanonicalBoardElectricalRatings(
        ratedBusbarCurrentA: 63,
        shortCircuitWithstandKa: boardFaultWithstandKa,
        ratedVoltageV: 230,
        ipRating: 'IP40',
        manufacturerSourceId: 'board-doc',
      ),
      cableCatalogId: 'cable-3x2.5',
      cableRatings: CanonicalCableElectricalRatings(
        conductorCrossSectionMm2: 2.5,
        conductorCount: 3,
        ratedVoltageV: cableRatedVoltageV,
        governingAmpacityA: 25,
        calculatedVoltageDropRatio: 0.012,
      ),
      cableSourceId: 'cable-doc',
      protectionCatalogId: 'mcb-b16',
      protectionRatings: CanonicalProtectionElectricalRatings(
        ratedCurrentA: 16,
        breakingCapacityKa: 6,
        poleCount: 1,
        deviceKind: 'mcb',
        tripCharacteristic: 'B',
      ),
      protectionSourceId: 'breaker-doc',
      normativeSourceId: 'normative-doc',
      routeEvidenceSourceId: 'route-survey',
      faultCurrentEvidenceSourceId: 'fault-study',
      routeLengthMm: 12000,
      evidenceFingerprint: digest,
      sources: [
        source('breaker-doc'),
        source('board-doc'),
        source('cable-doc'),
        source('normative-doc'),
        source('route-survey'),
        source('fault-study'),
        source('rcd-test-report'),
        source('selectivity-study'),
      ],
    );

EngineeringProjectState validEngineeringState() {
  final circuitId = CircuitId('c1');
  final board = EngineeringGraphComponent(
    id: ComponentId('board-1'),
    componentTypeId: 'board-type-v2',
    discipline: EngineeringDiscipline.power,
    systemClass: EngineeringSystemClass.powerAc,
    ports: [
      EngineeringPortSpec.identified(
        portId: PortId('out'),
        direction: EngineeringPortDirection.output,
        allowedConnections: {EngineeringConnectionType.acSinglePhase},
        media: {EngineeringMedia.acPower},
      ),
    ],
  );
  final load = EngineeringGraphComponent(
    id: ComponentId('load-1'),
    componentTypeId: 'load-type',
    discipline: EngineeringDiscipline.power,
    systemClass: EngineeringSystemClass.powerAc,
    ports: [
      EngineeringPortSpec.identified(
        portId: PortId('in'),
        direction: EngineeringPortDirection.input,
        allowedConnections: {EngineeringConnectionType.acSinglePhase},
        media: {EngineeringMedia.acPower},
      ),
    ],
  );
  final connection = EngineeringGraphConnection(
    id: EngineeringConnectionId('feed-1'),
    fromComponentId: board.id,
    fromPortId: PortId('out'),
    toComponentId: load.id,
    toPortId: PortId('in'),
    connectionType: EngineeringConnectionType.acSinglePhase,
    systemClass: EngineeringSystemClass.powerAc,
    media: EngineeringMedia.acPower,
    circuitId: circuitId,
  );
  final source = EngineeringSupplySource(
    id: EngineeringSupplySourceId('power-source-1'),
    endpoint: EngineeringPortRef(
      componentId: board.id,
      portId: PortId('out'),
    ),
    systemClass: EngineeringSystemClass.powerAc,
    media: EngineeringMedia.acPower,
  );
  return EngineeringProjectState(
    graph: CanonicalEngineeringGraph(
      components: [board, load],
      connections: [connection],
    ),
    circuits: [
      EngineeringCircuit(
        id: circuitId,
        systemClass: EngineeringSystemClass.powerAc,
        media: EngineeringMedia.acPower,
        connectionIds: [connection.id],
      ),
    ],
    sources: [source],
    circuitSupplies: [
      EngineeringCircuitSupply(
        circuitId: circuitId,
        sourceIds: [source.id],
      ),
    ],
  );
}

ProjectAggregateRoot projectWithPowerSelection() {
  final project = P1010ServiceAnchorFixture().project;
  return ProjectAggregateRoot(
    id: project.id,
    siteId: project.siteId,
    version: project.version,
    stores: project.stores,
    engineeringMetadata: project.engineeringMetadata
        .withEngineeringState(validEngineeringState())
        .withPowerSelections(
          CanonicalPowerSelectionRegistry(selections: [selection('c1')]),
        ),
  );
}

/// Simulates a structurally valid but referentially destructive update.
final class _DropEngineeringStateCommand implements ProjectCommand {
  @override
  String get commandType => 'test.drop-engineering-state';

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) =>
      ProjectCommandCandidate.fromState(
        state: ProjectMutableState(
          engineeringMetadata: current.engineeringMetadata.withEngineeringState(
            EngineeringProjectState.empty(),
          ),
          stores: current.stores,
        ),
      );
}

final class _PowerEvidenceRegistry
    implements TrustedEngineeringEvidenceRegistry {
  _PowerEvidenceRegistry(
      {this.revokedId,
      this.missingId,
      this.wrongProofPurpose = false,
      this.withoutVerifiedFinding = false,
      this.withoutVerifiedRuleProfile = false,
      this.approvedCalculation,
      this.faultEnvelope});

  final String? revokedId;
  final String? missingId;
  final bool wrongProofPurpose;
  final bool withoutVerifiedFinding;
  final bool withoutVerifiedRuleProfile;
  final PowerCircuitSafetyEvidence? approvedCalculation;
  final PowerCircuitFaultEnvelope? faultEnvelope;

  @override
  String get revision => 'registry-rev-1';

  @override
  EngineeringEvidenceReviewRecord? lookup(String sourceId) {
    if (sourceId == missingId) return null;
    return EngineeringEvidenceReviewRecord(
      sourceId: sourceId,
      revision: 'rev-1',
      contentSha256: digest,
      approvalId: 'approval-1',
      jurisdiction: 'KZ',
      applicationScope: 'POWER-AC',
      isApproved: true,
      isRevoked: sourceId == revokedId,
      evidencePurpose: sourceId == 'fault-study' && faultEnvelope != null
          ? 'fault-envelope'
          : sourceId == 'rcd-test-report'
          ? (wrongProofPurpose ? 'unrelated' : 'rcd-protection')
          : sourceId == 'selectivity-study'
              ? 'selectivity-coordination'
              : null,
      subjectCircuitId: (sourceId == 'fault-study' && faultEnvelope != null) ||
              sourceId == 'rcd-test-report' || sourceId == 'selectivity-study'
              ? 'c1'
              : null,
      verifiedSafetyFinding: !withoutVerifiedFinding &&
              (sourceId == 'rcd-test-report' ||
                  sourceId == 'selectivity-study')
          ? EngineeringVerifiedSafetyFinding.supported
          : null,
      verifiedRuleProfileFingerprint:
          sourceId == 'normative-doc' && !withoutVerifiedRuleProfile
              ? testPowerSafetyProfile().fingerprint
              : null,
      verifiedCalculationFingerprint: sourceId == 'fault-study'
          ? (faultEnvelope?.fingerprint ??
              (approvedCalculation ?? testPowerSafetyEvidence())
                  .calculationFingerprint)
          : null,
    );
  }
}

PowerSafetyRuleProfile testPowerSafetyProfile({
  String sourceId = 'normative-doc',
}) =>
    PowerSafetyRuleProfile(
      normativeSourceId: sourceId,
      jurisdiction: 'KZ',
      applicationScope: 'POWER-AC',
      maxConventionalTripToAmpacityRatio: 1.45,
      maxFaultDisconnectionTimeMs: 300,
    );

PowerCircuitSafetyEvidence testPowerSafetyEvidence({
  String id = 'c1',
  CanonicalPowerCircuitSelection? selected,
  bool complete = true,
  double designCurrent = 12,
  double faultCurrent = 3,
  double conventionalTrip = 24,
  double letThroughEnergy = 400,
  double cableWithstandEnergy = 800,
  double disconnectionTimeMs = 120,
  PowerSafetyClaimStatus rcdStatus = PowerSafetyClaimStatus.supported,
  PowerSafetyClaimStatus selectivityStatus = PowerSafetyClaimStatus.supported,
  String? overrideFingerprint,
}) {
  final reference = selected ?? selection(id);
  return PowerCircuitSafetyEvidence(
    circuitId: reference.circuitId,
    selectionFingerprint: overrideFingerprint ??
        semanticSha256Hex(jsonEncode(reference.toCanonicalJson())),
    calculationSourceId: 'fault-study',
    designCurrentA: complete ? designCurrent : null,
    prospectiveFaultCurrentKa: complete ? faultCurrent : null,
    conventionalTripCurrentA: complete ? conventionalTrip : null,
    protectiveDeviceLetThroughA2s: complete ? letThroughEnergy : null,
    cableShortCircuitWithstandA2s: complete ? cableWithstandEnergy : null,
    faultDisconnectionTimeMs: complete ? disconnectionTimeMs : null,
    residualCurrentProof: complete
        ? PowerSafetyClaim(
            sourceId: 'rcd-test-report',
            status: rcdStatus,
          )
        : null,
    selectivityProof: complete
        ? PowerSafetyClaim(
            sourceId: 'selectivity-study',
            status: selectivityStatus,
          )
        : null,
  );
}


PowerCircuitFaultEnvelope testFaultEnvelope({
  CanonicalPowerCircuitSelection? selected,
  double maxGridKa = 3,
  double minGridKa = 0.5,
  double maxBackupKa = 4,
  double minBackupKa = 0.3,
  double backupClearingMs = 120,
  double backupEnergy = 400,
}) {
  final reference = selected ?? selection('c1');
  return PowerCircuitFaultEnvelope(
    circuitId: reference.circuitId,
    selectionFingerprint:
        semanticSha256Hex(jsonEncode(reference.toCanonicalJson())),
    sourceId: 'fault-study',
    scenarios: [
      PowerSupplyFaultScenario(
        supplyId: 'grid',
        maximumProspectiveFaultKa: maxGridKa,
        minimumProspectiveFaultKa: minGridKa,
        maximumLetThroughA2s: 400,
        cableWithstandA2s: 800,
        minimumFaultClearingTimeMs: 130,
      ),
      PowerSupplyFaultScenario(
        supplyId: 'backup',
        maximumProspectiveFaultKa: maxBackupKa,
        minimumProspectiveFaultKa: minBackupKa,
        maximumLetThroughA2s: backupEnergy,
        cableWithstandA2s: 800,
        minimumFaultClearingTimeMs: backupClearingMs,
      ),
    ],
  );
}

void main() {
  group('P12A.8 multi-supply fault envelope', () {
    PowerFaultEnvelopeAssessment evaluate({
      PowerCircuitFaultEnvelope? envelope,
      PowerCircuitFaultEnvelope? approved,
      Iterable<String> supplies = const ['grid', 'backup'],
    }) {
      final requested = envelope ?? testFaultEnvelope();
      return PowerFaultEnvelopeGate.evaluate(
        selection: selection('c1'),
        envelope: requested,
        expectedSupplyIds: supplies,
        profile: testPowerSafetyProfile(),
        registry: _PowerEvidenceRegistry(
          faultEnvelope: approved ?? requested,
        ),
      );
    }

    test('full reviewed grid and backup max/min scenarios pass preflight only',
        () {
      final result = evaluate();
      expect(result.verdict, PowerSafetyVerdict.pass);
      expect(result.readyToApply, isFalse);
      expect(result.checks, hasLength(PowerFaultEnvelopeCheck.values.length));
    });

    test('missing supply from independent topology fails closed', () {
      final result = evaluate(supplies: const ['grid', 'backup', 'generator']);
      expect(result.verdict, PowerSafetyVerdict.indeterminate);
      expect(
        result.checks[PowerFaultEnvelopeCheck.completeSupplyCoverage],
        PowerSafetyVerdict.indeterminate,
      );
    });

    test('worst maximum fault scenario exceeds breaker and board capacity',
        () {
      final result = evaluate(envelope: testFaultEnvelope(maxBackupKa: 10));
      expect(
        result.checks[PowerFaultEnvelopeCheck.maximumBreakingCapacity],
        PowerSafetyVerdict.fail,
      );
      expect(
        result.checks[PowerFaultEnvelopeCheck.maximumBoardWithstand],
        PowerSafetyVerdict.fail,
      );
      expect(result.verdict, PowerSafetyVerdict.fail);
    });

    test('minimum fault current clearing time and max thermal energy checked',
        () {
      final delayed = evaluate(
        envelope: testFaultEnvelope(backupClearingMs: 450),
      );
      expect(
        delayed.checks[PowerFaultEnvelopeCheck.minimumFaultDisconnection],
        PowerSafetyVerdict.fail,
      );
      final thermal = evaluate(
        envelope: testFaultEnvelope(backupEnergy: 1200),
      );
      expect(
        thermal.checks[PowerFaultEnvelopeCheck.maximumThermalEnergy],
        PowerSafetyVerdict.fail,
      );
    });

    test('changed fault scenario cannot reuse approved envelope fingerprint',
        () {
      final result = evaluate(
        envelope: testFaultEnvelope(maxBackupKa: 0.9),
        approved: testFaultEnvelope(),
      );
      expect(result.verdict, PowerSafetyVerdict.indeterminate);
      expect(
        result.checks[PowerFaultEnvelopeCheck.trustedEnvelope],
        PowerSafetyVerdict.indeterminate,
      );
    });

    test('unattested profile or revoked calculation is never accepted', () {
      final envelope = testFaultEnvelope();
      PowerFaultEnvelopeAssessment assess(_PowerEvidenceRegistry registry) =>
          PowerFaultEnvelopeGate.evaluate(
            selection: selection('c1'),
            envelope: envelope,
            expectedSupplyIds: const ['grid', 'backup'],
            profile: testPowerSafetyProfile(),
            registry: registry,
          );
      expect(
        assess(_PowerEvidenceRegistry(
          faultEnvelope: envelope,
          withoutVerifiedRuleProfile: true,
        )).verdict,
        PowerSafetyVerdict.indeterminate,
      );
      expect(
        assess(_PowerEvidenceRegistry(
          faultEnvelope: envelope,
          revokedId: 'fault-study',
        )).verdict,
        PowerSafetyVerdict.indeterminate,
      );
    });

    test('unordered min/max fault currents and duplicate supply fail', () {
      expect(
        () => PowerSupplyFaultScenario(
          supplyId: 'grid',
          maximumProspectiveFaultKa: 1,
          minimumProspectiveFaultKa: 2,
          maximumLetThroughA2s: 400,
          cableWithstandA2s: 800,
          minimumFaultClearingTimeMs: 120,
        ),
        throwsArgumentError,
      );
      final one = testFaultEnvelope().scenarios.first;
      expect(
        () => PowerCircuitFaultEnvelope(
          circuitId: CircuitId('c1'),
          selectionFingerprint: 'snapshot',
          sourceId: 'fault-study',
          scenarios: [one, one],
        ),
        throwsArgumentError,
      );
    });
  });


  group('P12A.8 provisional electrical safety gate', () {
    PowerElectricalSafetyReport evaluate({
      PowerCircuitSafetyEvidence? evidence,
      CanonicalPowerCircuitSelection? selected,
      PowerSafetyRuleProfile? profile,
      _PowerEvidenceRegistry? registry,
    }) =>
        PowerElectricalSafetyGate.evaluate(
          selections: CanonicalPowerSelectionRegistry(
            selections: [selected ?? selection('c1')],
          ),
          evidence: [evidence ?? testPowerSafetyEvidence(selected: selected)],
          profile: profile ?? testPowerSafetyProfile(),
          registry: registry ??
              _PowerEvidenceRegistry(
                  approvedCalculation: evidence ??
                      testPowerSafetyEvidence(selected: selected)),
          targetJurisdiction: 'KZ',
          targetApplicationScope: 'POWER-AC',
        );

    test('complete provisional measurements can pass, but never grant Apply',
        () {
      final report = evaluate();
      expect(report.verdict, PowerSafetyVerdict.pass);
      expect(report.circuits[CircuitId('c1')]!.checks.length,
          PowerSafetyCheck.values.length);
      expect(report.readyToApply, isFalse);
    });

    test('unattested or modified numeric safety rule profile cannot pass', () {
      final missingAttestation = evaluate(
        registry: _PowerEvidenceRegistry(withoutVerifiedRuleProfile: true),
      );
      expect(
        missingAttestation.circuits[CircuitId('c1')]!
            .checks[PowerSafetyCheck.normativeApplicability],
        PowerSafetyVerdict.indeterminate,
      );
      expect(missingAttestation.verdict, PowerSafetyVerdict.indeterminate);
      final changedRule = evaluate(
        profile: PowerSafetyRuleProfile(
          normativeSourceId: 'normative-doc',
          jurisdiction: 'KZ',
          applicationScope: 'POWER-AC',
          maxConventionalTripToAmpacityRatio: 100,
          maxFaultDisconnectionTimeMs: 30000,
        ),
      );
      expect(changedRule.verdict, PowerSafetyVerdict.indeterminate);
      expect(changedRule.readyToApply, isFalse);
    });

    test('tampered measurement cannot reuse a reviewed source ID', () {
      final tampered = testPowerSafetyEvidence(faultCurrent: 0.1);
      final report = evaluate(
        evidence: tampered,
        registry: _PowerEvidenceRegistry(),
      );
      expect(
        report.circuits[CircuitId('c1')]!
            .checks[PowerSafetyCheck.breakingCapacity],
        PowerSafetyVerdict.indeterminate,
      );
      expect(report.verdict, PowerSafetyVerdict.indeterminate);
      expect(report.readyToApply, isFalse);
    });

    test('overload and breaking-capacity failures cannot be bypassed', () {
      final overloaded = evaluate(
        evidence: testPowerSafetyEvidence(designCurrent: 30),
      );
      expect(
        overloaded
            .circuits[CircuitId('c1')]!.checks[PowerSafetyCheck.overloadRating],
        PowerSafetyVerdict.fail,
      );
      final insufficientBreaker = evaluate(
        evidence: testPowerSafetyEvidence(faultCurrent: 10),
      );
      expect(
        insufficientBreaker.circuits[CircuitId('c1')]!
            .checks[PowerSafetyCheck.breakingCapacity],
        PowerSafetyVerdict.fail,
      );
      expect(insufficientBreaker.verdict, PowerSafetyVerdict.fail);
      expect(insufficientBreaker.readyToApply, isFalse);
    });

    test('board fault withstand and cable voltage can fail independently', () {
      final weakBoard = selection('c1', boardFaultWithstandKa: 2);
      final boardReport = evaluate(
        selected: weakBoard,
        evidence: testPowerSafetyEvidence(selected: weakBoard),
      );
      expect(
        boardReport.circuits[CircuitId('c1')]!
            .checks[PowerSafetyCheck.boardShortCircuitWithstand],
        PowerSafetyVerdict.fail,
      );
      expect(
        boardReport.circuits[CircuitId('c1')]!
            .checks[PowerSafetyCheck.breakingCapacity],
        PowerSafetyVerdict.pass,
      );
      final underratedCable = selection('c1', cableRatedVoltageV: 200);
      final cableReport = evaluate(
        selected: underratedCable,
        evidence: testPowerSafetyEvidence(selected: underratedCable),
      );
      expect(
        cableReport.circuits[CircuitId('c1')]!
            .checks[PowerSafetyCheck.cableVoltageRating],
        PowerSafetyVerdict.fail,
      );
      expect(cableReport.verdict, PowerSafetyVerdict.fail);
    });

    test('conventional trip and thermal fault energy are independently gated',
        () {
      final trip = evaluate(
        evidence: testPowerSafetyEvidence(conventionalTrip: 60),
      );
      expect(
        trip.circuits[CircuitId('c1')]!
            .checks[PowerSafetyCheck.conventionalTrip],
        PowerSafetyVerdict.fail,
      );
      final thermal = evaluate(
        evidence: testPowerSafetyEvidence(
          letThroughEnergy: 1200,
          cableWithstandEnergy: 800,
        ),
      );
      expect(
        thermal.circuits[CircuitId('c1')]!
            .checks[PowerSafetyCheck.shortCircuitThermal],
        PowerSafetyVerdict.fail,
      );
      final delayed = evaluate(
        evidence: testPowerSafetyEvidence(disconnectionTimeMs: 900),
      );
      expect(
        delayed.circuits[CircuitId('c1')]!
            .checks[PowerSafetyCheck.shortCircuitDisconnection],
        PowerSafetyVerdict.fail,
      );
    });

    test('caller-supported RCD and selectivity without trusted findings stay indeterminate',
        () {
      final report = evaluate(
        registry: _PowerEvidenceRegistry(withoutVerifiedFinding: true),
      );
      expect(
        report.circuits[CircuitId('c1')]!
            .checks[PowerSafetyCheck.residualCurrentProtection],
        PowerSafetyVerdict.indeterminate,
      );
      expect(
        report.circuits[CircuitId('c1')]!
            .checks[PowerSafetyCheck.selectivity],
        PowerSafetyVerdict.indeterminate,
      );
      expect(report.verdict, PowerSafetyVerdict.indeterminate);
      expect(report.readyToApply, isFalse);
    });

    test('RCD proof with unrelated reviewed purpose is indeterminate', () {
      final report = evaluate(
        registry: _PowerEvidenceRegistry(wrongProofPurpose: true),
      );
      expect(
        report.circuits[CircuitId('c1')]!
            .checks[PowerSafetyCheck.residualCurrentProtection],
        PowerSafetyVerdict.indeterminate,
      );
      expect(report.verdict, PowerSafetyVerdict.indeterminate);
    });

    test('negative and missing RCD/selectivity evidence cannot pass', () {
      final rcd = evaluate(
        evidence: testPowerSafetyEvidence(
          rcdStatus: PowerSafetyClaimStatus.contradicted,
        ),
      );
      expect(
        rcd.circuits[CircuitId('c1')]!
            .checks[PowerSafetyCheck.residualCurrentProtection],
        PowerSafetyVerdict.fail,
      );
      final selectivity = evaluate(
        evidence: testPowerSafetyEvidence(
          selectivityStatus: PowerSafetyClaimStatus.unknown,
        ),
      );
      expect(
        selectivity
            .circuits[CircuitId('c1')]!.checks[PowerSafetyCheck.selectivity],
        PowerSafetyVerdict.indeterminate,
      );
      expect(selectivity.readyToApply, isFalse);
    });

    test('missing evidence, stale snapshot and wrong profile are indeterminate',
        () {
      expect(
        evaluate(evidence: testPowerSafetyEvidence(complete: false)).verdict,
        PowerSafetyVerdict.indeterminate,
      );
      expect(
        evaluate(
          evidence: testPowerSafetyEvidence(overrideFingerprint: 'stale'),
        ).verdict,
        PowerSafetyVerdict.indeterminate,
      );
      final wrongProfile = evaluate(
        profile: testPowerSafetyProfile(sourceId: 'another-standard'),
      );
      expect(
        wrongProfile.circuits[CircuitId('c1')]!
            .checks[PowerSafetyCheck.normativeApplicability],
        PowerSafetyVerdict.indeterminate,
      );
      expect(wrongProfile.readyToApply, isFalse);
    });

    test('profile jurisdiction must match independent project target', () {
      final report = PowerElectricalSafetyGate.evaluate(
        selections: CanonicalPowerSelectionRegistry(
          selections: [selection('c1')],
        ),
        evidence: [testPowerSafetyEvidence()],
        profile: testPowerSafetyProfile(),
        registry: _PowerEvidenceRegistry(),
        targetJurisdiction: 'OTHER',
        targetApplicationScope: 'POWER-AC',
      );
      expect(
        report.circuits[CircuitId('c1')]!
            .checks[PowerSafetyCheck.normativeApplicability],
        PowerSafetyVerdict.indeterminate,
      );
      expect(report.verdict, PowerSafetyVerdict.indeterminate);
    });

    test('revocation of normative source is not a compliance PASS', () {
      final result = evaluate(
        registry: _PowerEvidenceRegistry(revokedId: 'normative-doc'),
      );
      expect(
        result.sourceIssues,
        contains(EngineeringEvidenceReviewIssue.revokedSource),
      );
      expect(result.verdict, PowerSafetyVerdict.indeterminate);
    });

    test('unknown and duplicate circuit measurements are rejected', () {
      final registry = CanonicalPowerSelectionRegistry(
        selections: [selection('c1')],
      );
      void run(List<PowerCircuitSafetyEvidence> evidence) {
        PowerElectricalSafetyGate.evaluate(
          selections: registry,
          evidence: evidence,
          profile: testPowerSafetyProfile(),
          registry: _PowerEvidenceRegistry(),
          targetJurisdiction: 'KZ',
          targetApplicationScope: 'POWER-AC',
        );
      }

      expect(
        () => run([testPowerSafetyEvidence(id: 'unknown')]),
        throwsArgumentError,
      );
      expect(
        () => run([
          testPowerSafetyEvidence(),
          testPowerSafetyEvidence(),
        ]),
        throwsArgumentError,
      );
    });
  });

  group('P12A.8 trusted v21 evidence preflight', () {
    test('reviews every durable source without authorizing Apply', () {
      final selections =
          CanonicalPowerSelectionRegistry(selections: [selection('c1')]);
      final result = CanonicalPowerEvidencePreflight.evaluate(
        selections: selections,
        registry: _PowerEvidenceRegistry(),
        jurisdiction: 'KZ',
        applicationScope: 'POWER-AC',
      );
      expect(result.isQualified, isTrue);
      expect(result.registryRevision, 'registry-rev-1');
    });

    test('missing and revoked source block preflight', () {
      final selections =
          CanonicalPowerSelectionRegistry(selections: [selection('c1')]);
      EngineeringEvidenceReviewResult review(_PowerEvidenceRegistry registry) =>
          CanonicalPowerEvidencePreflight.evaluate(
            selections: selections,
            registry: registry,
            jurisdiction: 'KZ',
            applicationScope: 'POWER-AC',
          );
      expect(
        review(_PowerEvidenceRegistry(missingId: 'route-survey')).issues,
        contains(EngineeringEvidenceReviewIssue.missingSource),
      );
      expect(
        review(_PowerEvidenceRegistry(revokedId: 'normative-doc')).issues,
        contains(EngineeringEvidenceReviewIssue.revokedSource),
      );
    });

    test('conflicting revisions for same source across circuits fail closed',
        () {
      final changed = selection('c2').toCanonicalJson();
      final pins = changed['sources'] as List;
      (pins.first as Map<String, Object?>)['revision'] = 'rev-2';
      final selections = CanonicalPowerSelectionRegistry(selections: [
        selection('c1'),
        CanonicalPowerCircuitSelection.fromCanonicalJson(changed),
      ]);
      final result = CanonicalPowerEvidencePreflight.evaluate(
        selections: selections,
        registry: _PowerEvidenceRegistry(),
        jurisdiction: 'KZ',
        applicationScope: 'POWER-AC',
      );
      expect(result.issues,
          contains(EngineeringEvidenceReviewIssue.mismatchedIdentity));
    });
  });

  group('P12A.8 canonical POWER persistence model', () {
    test('registry JSON round-trip preserves all fields and stable fingerprint',
        () {
      final first = CanonicalPowerSelectionRegistry(
        selections: [selection('c2'), selection('c1')],
      );
      final encoded = jsonEncode(first.toCanonicalJson());
      final decoded = CanonicalPowerSelectionRegistry.fromCanonicalJson(
        jsonDecode(encoded),
      );
      expect(decoded.fingerprint, first.fingerprint);
      expect(jsonEncode(decoded.toCanonicalJson()), encoded);
      expect(decoded.byCircuit[CircuitId('c1')]!.cableCatalogId, 'cable-3x2.5');
      expect(
        decoded.byCircuit[CircuitId('c1')]!.boardRatings.ratedBusbarCurrentA,
        63,
      );
      expect(decoded.byCircuit[CircuitId('c1')]!.sources, hasLength(8));
      expect(
          decoded.byCircuit[CircuitId('c1')]!.cableRatings.conductorCount, 3);
      expect(
          decoded.byCircuit[CircuitId('c1')]!.protectionRatings.ratedCurrentA,
          16);
      expect(() => decoded.byCircuit.clear(), throwsUnsupportedError);
    });

    test('duplicate IDs and generation keys are rejected', () {
      expect(
        () => CanonicalPowerSelectionRegistry(
          selections: [selection('c1'), selection('c1')],
        ),
        throwsArgumentError,
      );
    });

    test('unsupported versions and unknown persisted fields fail closed', () {
      final original = CanonicalPowerSelectionRegistry(
        selections: [selection('c1')],
      ).toCanonicalJson();
      expect(
        () => CanonicalPowerSelectionRegistry.fromCanonicalJson({
          ...original,
          'schemaVersion': 999,
        }),
        throwsFormatException,
      );
      final modified = jsonDecode(jsonEncode(original)) as Map<String, dynamic>;
      (modified['selections'] as List).first['inventedKey'] = true;
      expect(
        () => CanonicalPowerSelectionRegistry.fromCanonicalJson(modified),
        throwsFormatException,
      );
    });

    test('nonfinite ratings and missing source references are rejected', () {
      expect(
        () => CanonicalBoardElectricalRatings(
          ratedBusbarCurrentA: double.nan,
          shortCircuitWithstandKa: 6,
          ratedVoltageV: 230,
          ipRating: 'IP40',
          manufacturerSourceId: 'board-doc',
        ),
        throwsArgumentError,
      );
      final encoded = selection('c1').toCanonicalJson();
      (encoded['sources'] as List)
          .removeWhere((value) => value['sourceId'] == 'route-survey');
      expect(
        () => CanonicalPowerCircuitSelection.fromCanonicalJson(encoded),
        throwsArgumentError,
      );
    });
  });

  group('P12A.8 reserved engineering preview', () {
    test(
        'frozen canonical preview uses existing P11 circuit IDs and cannot Apply',
        () {
      final base = P1010ServiceAnchorFixture().project;
      final current = ProjectAggregateRoot(
        id: base.id,
        siteId: base.siteId,
        version: base.version,
        stores: base.stores,
        engineeringMetadata: base.engineeringMetadata
            .withEngineeringState(validEngineeringState()),
      );
      final proposed = EngineeringProposalDiff(
        sourceFingerprint: 'test-source',
        boardGenerationKey: 'board-key',
        catalogSnapshotId: 'catalog-snapshot-v2',
        entries: [
          EngineeringProposalDiffEntry(
            generationKey: 'generation-c1',
            calculationCircuitId: 'calculated-c1',
            status: EngineeringProposalStatus.selected,
            cableCatalogId: 'cable-3x2.5',
            protectionCatalogId: 'mcb-b16',
          ),
        ],
        issues: const [],
      );
      final command = EngineeringReservedProjectCommand(
        proposal: proposed,
        requestedSelections:
            CanonicalPowerSelectionRegistry(selections: [selection('c1')]),
        canonicalCircuitIdsByCalculationId: {'calculated-c1': CircuitId('c1')},
        expectedEngineeringStateFingerprint:
            current.engineeringMetadata.engineeringState.fingerprint,
        expectedPowerSelectionFingerprint:
            current.engineeringMetadata.powerSelections.fingerprint,
      );
      final session = ProjectMutationSession(current);
      final coordinator = ReservedProjectMutationCoordinator(session);
      final preview = coordinator.preview(command);
      expect(preview.hasChanges, isTrue);
      expect(preview.candidate.engineeringMetadata.powerSelections.byCircuit,
          contains(CircuitId('c1')));
      expect(preview.preview.engineeringMetadataDiff.powerSelectionsChanged,
          isTrue);
      expect(preview.semanticChangeSet.operations.single.semanticKey,
          contains('c1'));
      expect(
          session.current.engineeringMetadata.powerSelections.isEmpty, isTrue);
      expect(() => coordinator.commitPreview(preview), throwsStateError);
      expect(session.current.version, current.version);
      expect(session.undoDepth, 0);
    });

    test('incorrect or incomplete calculator-to-canonical lineage fails closed',
        () {
      final proposal = EngineeringProposalDiff(
        sourceFingerprint: 'source',
        boardGenerationKey: 'board-key',
        catalogSnapshotId: 'catalog-snapshot-v2',
        entries: [
          EngineeringProposalDiffEntry(
            generationKey: 'generation-c1',
            calculationCircuitId: 'calculated-c1',
            status: EngineeringProposalStatus.selected,
            cableCatalogId: 'cable-3x2.5',
            protectionCatalogId: 'mcb-b16',
          ),
        ],
        issues: const [],
      );
      EngineeringReservedProjectCommand create(Map<String, CircuitId> ids) =>
          EngineeringReservedProjectCommand(
            proposal: proposal,
            requestedSelections: CanonicalPowerSelectionRegistry(
              selections: [selection('c1')],
            ),
            canonicalCircuitIdsByCalculationId: ids,
            expectedEngineeringStateFingerprint: 'state',
            expectedPowerSelectionFingerprint: 'registry',
          );

      expect(() => create({}), throwsArgumentError);
      expect(
        () => create({'calculated-c1': CircuitId('wrong-circuit')}),
        throwsArgumentError,
      );
      expect(
        () => create({
          'calculated-c1': CircuitId('c1'),
          'undeclared-calculation': CircuitId('extra'),
        }),
        throwsArgumentError,
      );
      final mutable = {'calculated-c1': CircuitId('c1')};
      final command = create(mutable);
      final intent = command.normalizedIntentKey;
      mutable['calculated-c1'] = CircuitId('tampered');
      expect(command.normalizedIntentKey, intent);
      expect(
        command.canonicalCircuitIdsByCalculationId['calculated-c1'],
        CircuitId('c1'),
      );
    });

    test('proposal/selection catalog mismatch fails closed before preview', () {
      final proposal = EngineeringProposalDiff(
        sourceFingerprint: 'source',
        boardGenerationKey: 'board-key',
        catalogSnapshotId: 'catalog-snapshot-v2',
        entries: [
          EngineeringProposalDiffEntry(
            generationKey: 'generation-c1',
            calculationCircuitId: 'calculated-c1',
            status: EngineeringProposalStatus.selected,
            cableCatalogId: 'different-cable',
            protectionCatalogId: 'mcb-b16',
          ),
        ],
        issues: const [],
      );
      expect(
        () => EngineeringReservedProjectCommand(
          proposal: proposal,
          requestedSelections: CanonicalPowerSelectionRegistry(
            selections: [selection('c1')],
          ),
          canonicalCircuitIdsByCalculationId: {
            'calculated-c1': CircuitId('c1')
          },
          expectedEngineeringStateFingerprint: 'state',
          expectedPowerSelectionFingerprint: 'registry',
        ),
        throwsArgumentError,
      );
    });
  });

  group('P12A.8 v21 project persistence envelope', () {
    const codec = PowerSelectionAwareCanonicalProjectDocumentCodec();
    const legacy = EngineeringStateAwareCanonicalProjectDocumentCodec();

    test('v20 project upgrades to v21 with empty canonical POWER registry', () {
      final aggregate = P1010ServiceAnchorFixture().project;
      final snapshot = p109Snapshot(aggregate);
      final old = legacy.encode(snapshot);
      final migrated = codec.decode(old);
      expect(migrated.aggregate.engineeringMetadata.powerSelections.isEmpty,
          isTrue);
      final document = codec.encode(migrated);
      expect(document.schemaVersion, 21);
      final reopened = codec.decode(document);
      expect(reopened.aggregate.engineeringMetadata.powerSelections.isEmpty,
          isTrue);
      expect(jsonEncode(codec.encode(reopened).payload),
          jsonEncode(document.payload));
    });

    test('aggregate rejects orphan selections before persistence or commit',
        () {
      final project = P1010ServiceAnchorFixture().project;
      expect(
        () => ProjectAggregateRoot(
          id: project.id,
          siteId: project.siteId,
          version: project.version,
          stores: project.stores,
          engineeringMetadata: project.engineeringMetadata.withPowerSelections(
            CanonicalPowerSelectionRegistry(selections: [selection('orphan')]),
          ),
        ),
        throwsArgumentError,
      );
    });

    test('P11 engineering-state-only edits produce a canonical metadata diff',
        () {
      final base = P1010ServiceAnchorFixture().project;
      final project = ProjectAggregateRoot(
        id: base.id,
        siteId: base.siteId,
        version: base.version,
        stores: base.stores,
        engineeringMetadata: base.engineeringMetadata
            .withEngineeringState(validEngineeringState()),
      );
      final session = ProjectMutationSession(project);
      final preview = session.preview(ProjectMutationRequest(
        expectedVersion: project.version,
        command: _DropEngineeringStateCommand(),
      ));
      expect(preview.hasChanges, isTrue);
      expect(preview.engineeringMetadataDiff.engineeringStateChanged, isTrue);
      expect(session.current.engineeringMetadata.engineeringState.isEmpty,
          isFalse);
    });

    test(
        'P11 engineering-only commit advances version and Undo/Redo restores it',
        () {
      final base = P1010ServiceAnchorFixture().project;
      final original = ProjectAggregateRoot(
        id: base.id,
        siteId: base.siteId,
        version: base.version,
        stores: base.stores,
        engineeringMetadata: base.engineeringMetadata
            .withEngineeringState(validEngineeringState()),
      );
      final session = ProjectMutationSession(original);
      final committed = session.commit(ProjectMutationRequest(
        expectedVersion: original.version,
        command: _DropEngineeringStateCommand(),
      ))!;
      expect(
          committed.changeSet.engineeringMetadataDiff.engineeringStateChanged,
          isTrue);
      expect(
          session.current.engineeringMetadata.engineeringState.isEmpty, isTrue);
      expect(session.undoDepth, 1);
      final undo = session.undo(session.current.version)!;
      expect(undo.changeSet.engineeringMetadataDiff.engineeringStateChanged,
          isTrue);
      expect(session.current.engineeringMetadata.engineeringState.fingerprint,
          original.engineeringMetadata.engineeringState.fingerprint);
      final redo = session.redo(session.current.version)!;
      expect(redo.changeSet.engineeringMetadataDiff.engineeringStateChanged,
          isTrue);
      expect(
          session.current.engineeringMetadata.engineeringState.isEmpty, isTrue);
    });

    test('mutation preview refuses to drop a selected P11 circuit and board',
        () {
      final valid = projectWithPowerSelection();
      final session = ProjectMutationSession(valid);
      expect(
        () => session.preview(ProjectMutationRequest(
          expectedVersion: valid.version,
          command: _DropEngineeringStateCommand(),
        )),
        throwsArgumentError,
      );
      expect(session.current.engineeringMetadata.powerSelections.byCircuit,
          contains(CircuitId('c1')));
    });

    test('non-empty v21 JSON repository Save/Reopen preserves all evidence',
        () async {
      final project = projectWithPowerSelection();
      final directory = await Directory.systemTemp.createTemp('p12a8-v21-');
      addTearDown(() => directory.delete(recursive: true));
      final repository = JsonProjectRepository(
        rootDirectory: directory,
        codec: codec,
      );
      await repository.save(p109Snapshot(project));
      final loaded = (await repository.load(project.id))!;
      final original = project.engineeringMetadata.powerSelections;
      final reopened = loaded.aggregate.engineeringMetadata.powerSelections;
      expect(reopened.sameAs(original), isTrue);
      expect(reopened.fingerprint, original.fingerprint);
      expect(loaded.aggregate.engineeringMetadata.engineeringState.fingerprint,
          project.engineeringMetadata.engineeringState.fingerprint);
      expect(
        reopened.byCircuit[CircuitId('c1')]!.boardComponentId,
        ComponentId('board-1'),
      );
      expect(
        reopened.byCircuit[CircuitId('c1')]!.sources.map((s) => s.sourceId),
        containsAll(['fault-study', 'normative-doc', 'route-survey']),
      );
      final old = legacy;
      expect(() => old.encode(p109Snapshot(project)), throwsFormatException);
    });

    test('v21 decoder rejects tampered orphan selection references', () {
      final document = codec.encode(p109Snapshot(projectWithPowerSelection()));
      final payload =
          jsonDecode(jsonEncode(document.payload)) as Map<String, dynamic>;
      final selection =
          (payload['powerSelections']['selections'] as List).first;
      selection['circuitId'] = 'missing-circuit';
      expect(
        () => codec.decode(ProjectDocument(
          schemaVersion: 21,
          payload: payload,
        )),
        throwsFormatException,
      );
    });

    test('older schema cannot disguise a v21 POWER selection payload', () {
      final aggregate = P1010ServiceAnchorFixture().project;
      final v21 = codec.encode(p109Snapshot(aggregate));
      expect(
        () => codec.decode(ProjectDocument(
          schemaVersion: 20,
          payload: v21.payload,
        )),
        throwsFormatException,
      );
    });
  });
}
