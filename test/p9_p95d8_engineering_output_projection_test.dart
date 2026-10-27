import 'package:elecx/src/application/project/wizard/apartment/apartment_circuit_calculation_evidence.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_circuit_closure_evidence.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_circuit_installation_method_evidence.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_engineering_final_gate.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_engineering_output_projection.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_engineering_requirements.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_protection_coordination_evidence.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_residual_current_closure_evidence.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_short_circuit_closure_evidence.dart';
import 'package:elecx/src/domain/cable_spec.dart';
import 'package:elecx/src/domain/circuit_installation_method.dart';
import 'package:elecx/src/domain/distribution_board_load.dart';
import 'package:elecx/src/domain/electrical_circuit_calculation.dart';
import 'package:elecx/src/domain/electrical_circuit_synthesis.dart';
import 'package:elecx/src/domain/electrical_load_calculation.dart';
import 'package:elecx/src/domain/electrical_phase_assignment.dart';
import 'package:elecx/src/domain/overcurrent_protection.dart';
import 'package:elecx/src/domain/protective_device_coordination.dart';
import 'package:elecx/src/domain/residual_current_protection.dart';
import 'package:elecx/src/domain/route_medium.dart';
import 'package:elecx/src/engine/cable_sizing_engine.dart';
import 'package:elecx/src/engine/circuit_installation_method_closure_engine.dart';
import 'package:elecx/src/engine/electrical_circuit_calculation_engine.dart';
import 'package:elecx/src/engine/electrical_circuit_closure_engine.dart';
import 'package:elecx/src/engine/electrical_short_circuit_closure_engine.dart';
import 'package:elecx/src/engine/phase_assignment_engine.dart';
import 'package:elecx/src/engine/protective_device_coordination_engine.dart';
import 'package:elecx/src/engine/residual_current_protection_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P9.5-D8 engineering output projection', () {
    test('Q82 projects deterministic load circuit panel SLD and explanation', () {
      final fixture = _fixture();
      final first = fixture.project();
      final second = fixture.project();

      expect(
        ApartmentEngineeringFinalGateService.evaluate(fixture.requirements)
            .accepted,
        isTrue,
      );
      expect(first.outputFingerprint, second.outputFingerprint);
      expect(first.outputFingerprint, hasLength(64));
      expect(first.requirementsFingerprint,
          fixture.requirements.requirementsFingerprint);

      expect(first.loadSchedule, hasLength(1));
      final load = first.loadSchedule.single;
      expect(load.circuitId, 'circuit-001');
      expect(load.loadId, 'load-a');
      expect(load.assignedPhase, 'l1');
      expect(load.kind, ElectricalCircuitLoadKind.other.name);
      expect(load.locationId, 'qualification');
      expect(load.connectedPowerW, 3000);

      expect(first.circuitSchedule, hasLength(1));
      final circuit = first.circuitSchedule.single;
      expect(circuit.circuitId, 'circuit-001');
      expect(circuit.assignedPhase, 'l1');
      expect(circuit.cableId, 'cable-2.5');
      expect(circuit.conductorCrossSectionMm2, 2.5);
      expect(circuit.governingAmpacityA, 21);
      expect(circuit.overcurrentDeviceId, _mcb16.id);
      expect(circuit.overcurrentRatedCurrentA, 16);
      expect(circuit.prospectiveShortCircuitCurrentA, 3500);
      expect(circuit.residualApplicability,
          ResidualCurrentApplicability.notRequired.name);
      expect(circuit.residualDeviceId, isNull);
      expect(circuit.overcurrentCoordinationEvidenceId, 'sel-total');
      expect(circuit.installationSections.single.installationMethodId,
          'reference-method-B2');

      expect(first.panelSummary.branchCircuitCount, 1);
      expect(first.panelSummary.boardPhaseSystem,
          DistributionBoardPhaseSystem.singlePhase.name);
      expect(first.panelSummary.phaseLoads.single.phase, 'l1');

      final explanationCodes = first.explanations
          .map((item) => item.code)
          .toSet();
      expect(
        explanationCodes,
        containsAll({
          'phase.assignment',
          'cable.governingAmpacity',
          'cable.voltageDrop',
          'protection.ibInIz',
          'shortCircuit.disconnection',
          'shortCircuit.thermal',
          'residual.policy',
          'coordination.overcurrent',
          'coordination.residualCurrent',
          'installation.method',
        }),
      );
    });

    test('Q83 panel summary uses calculated phase current not breaker sum', () {
      final fixture = _fixture();
      final projection = fixture.project();
      final row = projection.circuitSchedule.single;

      expect(row.overcurrentRatedCurrentA, 16);
      expect(
        projection.panelSummary.maxPhaseCurrentA,
        closeTo(row.designCurrentA, 1e-9),
      );
      expect(projection.panelSummary.maxPhaseCurrentA, isNot(16));
      expect(projection.panelSummary.maxPhaseCurrentA, lessThan(16));
    });

    test('Q84 SLD does not invent residual device when D5 says not required', () {
      final fixture = _fixture();
      final projection = fixture.project();
      final kinds = projection.sldNodes.map((item) => item.kind).toList();

      expect(projection.sldNodes, hasLength(4));
      expect(projection.sldEdges, hasLength(3));
      expect(
        kinds,
        isNot(contains(
          ApartmentEngineeringSldNodeKind.residualCurrentProtection,
        )),
      );
      expect(
        kinds,
        isNot(contains(ApartmentEngineeringSldNodeKind.combinedProtection)),
      );
      expect(
        kinds,
        containsAll({
          ApartmentEngineeringSldNodeKind.board,
          ApartmentEngineeringSldNodeKind.overcurrentProtection,
          ApartmentEngineeringSldNodeKind.cable,
          ApartmentEngineeringSldNodeKind.loadGroup,
        }),
      );
    });

    test('Q85 standalone RCD is projected as a distinct SLD device', () {
      final fixture = _fixture(requireResidual: true);
      final projection = fixture.project();
      final row = projection.circuitSchedule.single;

      expect(row.residualApplicability,
          ResidualCurrentApplicability.required.name);
      expect(row.residualDeviceId, _rcd25TypeA30.id);
      expect(row.residualDeviceKind, ResidualCurrentDeviceKind.rcd.name);
      expect(row.residualType, ResidualCurrentType.a.name);
      expect(row.residualOperatingCurrentMa, 30);
      expect(
        projection.sldNodes.where(
          (node) =>
              node.kind ==
              ApartmentEngineeringSldNodeKind.residualCurrentProtection,
        ),
        hasLength(1),
      );
      expect(projection.sldNodes, hasLength(5));
      expect(projection.sldEdges, hasLength(4));
    });

    test('Q86 final-ready requirements from another lineage fail closed', () {
      final fixture = _fixture();
      final stale = _replaceFactRevision(
        fixture.requirements,
        ApartmentEngineeringRequirementDomain.circuit,
        'circuit.installationMethod',
        'stale-d7-revision',
      );

      expect(
        ApartmentEngineeringFinalGateService.evaluate(stale).accepted,
        isTrue,
        reason: 'The generic final gate only checks readiness/schema presence.',
      );
      expect(
        () => ApartmentEngineeringOutputProjectionService.project(
          d7Closure: fixture.d7Closure,
          phaseAssignment: fixture.phaseAssignment,
          requirements: stale,
        ),
        throwsArgumentError,
      );
    });

    test('Q87 foreign phase-assignment circuit set fails closed', () {
      final fixture = _fixture();
      final foreign = _phaseAssignmentFor(circuitId: 'circuit-999').assignment;

      expect(
        () => ApartmentEngineeringOutputProjectionService.project(
          d7Closure: fixture.d7Closure,
          phaseAssignment: foreign,
          requirements: fixture.requirements,
        ),
        throwsArgumentError,
      );
    });

    test('Q88 same circuit id with altered calculation provenance fails closed',
        () {
      final fixture = _fixture();
      final original = fixture.phaseAssignment.circuits.single;
      final driftedCalculated = CalculatedElectricalCircuit(
        circuit: original.circuit.circuit,
        calculation: original.circuit.calculation,
        policySourceId: original.circuit.policySourceId,
        policySourceRevision: 'different-calculation-policy-revision',
      );
      final drifted = ElectricalPhaseAssignmentResult(
        circuits: [
          PhaseAssignedElectricalCircuit(
            circuit: driftedCalculated,
            phase: original.phase,
          ),
        ],
        phaseLoads: fixture.phaseAssignment.phaseLoads,
        boardPhaseSystem: fixture.phaseAssignment.boardPhaseSystem,
        lineNeutralVoltageV: fixture.phaseAssignment.lineNeutralVoltageV,
        lineLineVoltageV: fixture.phaseAssignment.lineLineVoltageV,
        maxPhaseCurrentA: fixture.phaseAssignment.maxPhaseCurrentA,
        phaseCurrentImbalanceRatio:
            fixture.phaseAssignment.phaseCurrentImbalanceRatio,
      );

      expect(
        () => ApartmentEngineeringOutputProjectionService.project(
          d7Closure: fixture.d7Closure,
          phaseAssignment: drifted,
          requirements: fixture.requirements,
        ),
        throwsArgumentError,
      );
    });

    test('Q89 D8 output collections are immutable', () {
      final projection = _fixture().project();

      expect(
        () => projection.loadSchedule.add(projection.loadSchedule.single),
        throwsUnsupportedError,
      );
      expect(
        () => projection.circuitSchedule
            .add(projection.circuitSchedule.single),
        throwsUnsupportedError,
      );
      expect(
        () => projection.sldNodes.add(projection.sldNodes.single),
        throwsUnsupportedError,
      );
      expect(
        () => projection.explanations.add(projection.explanations.single),
        throwsUnsupportedError,
      );
      expect(
        () => projection.circuitSchedule.single.loadIds.add('tamper'),
        throwsUnsupportedError,
      );
    });

    test('Q90 output fingerprint changes when source-pinned D7 provenance changes',
        () {
      final first = _fixture(installationSourceRevision: '2026.1').project();
      final second = _fixture(installationSourceRevision: '2026.2').project();

      expect(first.outputFingerprint, isNot(second.outputFingerprint));
      expect(first.requirementsFingerprint,
          isNot(second.requirementsFingerprint));
    });
  });
}

const _mcb16 = OvercurrentProtectiveDeviceSpec(
  id: 'mcb-c16-6ka',
  kind: OvercurrentDeviceKind.mcb,
  ratedCurrentA: 16,
  breakingCapacityKa: 6,
  poleCount: 1,
  tripCurve: OvercurrentTripCurve.c,
  sourceId: 'device-catalog',
  sourceRevision: 'r1',
);

const _upstream = OvercurrentProtectiveDeviceSpec(
  id: 'mcb-c40-10ka',
  kind: OvercurrentDeviceKind.mcb,
  ratedCurrentA: 40,
  breakingCapacityKa: 10,
  poleCount: 2,
  tripCurve: OvercurrentTripCurve.c,
  sourceId: 'device-catalog',
  sourceRevision: 'r1',
);

final _rcd25TypeA30 = ResidualCurrentProtectiveDeviceSpec(
  id: 'rcd-25a-type-a-30ma',
  kind: ResidualCurrentDeviceKind.rcd,
  ratedCurrentA: 25,
  residualOperatingCurrentMa: 30,
  residualType: ResidualCurrentType.a,
  poleCount: 2,
  overcurrentDeviceId: null,
  conditionalShortCircuitCurrentA: 6000,
  compatibleBackupOvercurrentDeviceIds: const [_mcb16.id],
  sourceId: 'residual-device-catalog',
  sourceRevision: 'r1',
);

_D8Fixture _fixture({
  bool requireResidual = false,
  String installationSourceRevision = '2026.1',
}) {
  final calculationBundle = _calculationBundle(circuitId: 'circuit-001');
  final phaseBundle = _phaseAssignmentFor(
    circuitId: 'circuit-001',
    calculationBundle: calculationBundle,
  );
  final afterD2 = ApartmentCircuitCalculationEvidenceService.apply(
    requirements: _baseRequirements(),
    calculationRequest: calculationBundle.request,
    calculation: calculationBundle.calculation,
    assignmentRequest: phaseBundle.request,
    assignment: phaseBundle.assignment,
  );

  final d3Request = _d3Request(calculationBundle.calculation);
  final d3Closure = ElectricalCircuitClosureEngine.close(d3Request);
  final afterD3 = ApartmentCircuitClosureEvidenceService.apply(
    requirements: afterD2,
    request: d3Request,
    closure: d3Closure,
  );

  final d4Request = _d4Request(d3Closure);
  final d4Closure = ElectricalShortCircuitClosureEngine.close(d4Request);
  final afterD4 = ApartmentShortCircuitClosureEvidenceService.apply(
    requirements: afterD3,
    request: d4Request,
    closure: d4Closure,
  );

  final d5Request = ElectricalResidualCurrentClosureRequest(
    d4Closure: d4Closure,
    policies: [_residualPolicy(required: requireResidual)],
  );
  final d5Closure = ResidualCurrentProtectionEngine.close(d5Request);
  final afterD5 = ApartmentResidualCurrentClosureEvidenceService.apply(
    requirements: afterD4,
    request: d5Request,
    closure: d5Closure,
  );

  final d6Request = ElectricalProtectionCoordinationClosureRequest(
    d5Closure: d5Closure,
    policies: [
      ProtectiveDeviceCoordinationPolicy(
        circuitId: 'circuit-001',
        applicability: ProtectiveDeviceCoordinationApplicability.required,
        rationaleCode: 'qualification.coordination-required',
        evaluatedDownstreamDeviceId: _mcb16.id,
        applicabilityEvidenceIds: const ['coordination-rule'],
        upstreamDevice: _upstream,
        selectivityEvidence: [
          ProtectiveDeviceSelectivityEvidence(
            id: 'sel-total',
            downstreamDeviceId: _mcb16.id,
            upstreamDeviceId: _upstream.id,
            kind: ProtectiveDeviceSelectivityKind.total,
            selectivityLimitA: null,
            sourceId: 'manufacturer-selectivity-table',
            sourceRevision: '2026.1',
          ),
        ],
        sourceId: 'coordination-policy',
        sourceRevision: '2026.1',
      ),
    ],
    residualCurrentPolicies: [
      ResidualCurrentDeviceCoordinationPolicy(
        circuitId: 'circuit-001',
        applicability: ResidualCurrentCoordinationApplicability.notRequired,
        rationaleCode: requireResidual
            ? 'qualification.no-upstream-residual-coordination-required'
            : 'qualification.no-local-residual-device',
        evaluatedDownstreamDeviceId:
            requireResidual ? _rcd25TypeA30.id : null,
        applicabilityEvidenceIds: const [
          'residual-coordination-not-applicable',
        ],
        upstreamDevice: null,
        selectivityEvidence: const [],
        sourceId: 'residual-coordination-policy',
        sourceRevision: '2026.1',
      ),
    ],
  );
  final d6Closure = ProtectiveDeviceCoordinationEngine.close(d6Request);
  final afterD6 = ApartmentProtectionCoordinationEvidenceService.apply(
    requirements: afterD5,
    request: d6Request,
    closure: d6Closure,
  );

  final d7Request = ElectricalCircuitInstallationMethodClosureRequest(
    d6Closure: d6Closure,
    policies: [
      CircuitInstallationMethodPolicy(
        circuitId: 'circuit-001',
        cableId: 'cable-2.5',
        sections: [
          CircuitInstallationSectionMethodEvidence(
            sectionId: 'wall',
            installationMethodId: 'reference-method-B2',
            ampacitySourceKey: 'ampacity-table',
            sourceId: 'installation-method-registry',
            sourceRevision: installationSourceRevision,
          ),
        ],
        sourceId: 'installation-policy',
        sourceRevision: installationSourceRevision,
      ),
    ],
  );
  final d7Closure = CircuitInstallationMethodClosureEngine.close(d7Request);
  final afterD7 = ApartmentCircuitInstallationMethodEvidenceService.apply(
    requirements: afterD6,
    request: d7Request,
    closure: d7Closure,
  );

  return _D8Fixture(
    d7Closure: d7Closure,
    phaseAssignment: phaseBundle.assignment,
    requirements: afterD7,
  );
}

ResidualCurrentProtectionPolicy _residualPolicy({required bool required}) {
  if (!required) {
    return ResidualCurrentProtectionPolicy(
      circuitId: 'circuit-001',
      applicability: ResidualCurrentApplicability.notRequired,
      rationaleCode: 'qualification.rcd-not-required',
      evaluatedLoadIds: const ['load-a'],
      applicabilityEvidenceIds: const ['norm-not-applicable-rule'],
      loadCharacteristicEvidenceIds: const [],
      maximumResidualOperatingCurrentMa: null,
      allowedTypes: const {},
      preferredTypes: const [],
      allowedDeviceKinds: const {},
      preferredDeviceKinds: const [],
      minimumPoleCount: null,
      sensitivityPreference: null,
      candidates: const [],
      sourceId: 'residual-policy',
      sourceRevision: '2026.1',
    );
  }
  return ResidualCurrentProtectionPolicy(
    circuitId: 'circuit-001',
    applicability: ResidualCurrentApplicability.required,
    rationaleCode: 'qualification.rcd-required',
    evaluatedLoadIds: const ['load-a'],
    applicabilityEvidenceIds: const ['norm-rcd-required'],
    loadCharacteristicEvidenceIds: const ['load-characteristic-a'],
    maximumResidualOperatingCurrentMa: 30,
    allowedTypes: const {ResidualCurrentType.a},
    preferredTypes: const [ResidualCurrentType.a],
    allowedDeviceKinds: const {ResidualCurrentDeviceKind.rcd},
    preferredDeviceKinds: const [ResidualCurrentDeviceKind.rcd],
    minimumPoleCount: 2,
    sensitivityPreference: ResidualCurrentSensitivityPreference.lowestAvailable,
    candidates: [_rcd25TypeA30],
    sourceId: 'residual-policy',
    sourceRevision: '2026.1',
  );
}

ElectricalCircuitClosureRequest _d3Request(
  ElectricalCircuitCalculationResult calculation,
) =>
    ElectricalCircuitClosureRequest(
      calculation: calculation,
      policies: [
        ElectricalCircuitClosurePolicy(
          circuitId: 'circuit-001',
          cableCandidates: [
            ElectricalCircuitCableCandidate(
              cable: _cable(),
              routeLengthMm: 15000,
              maxVoltageDropRatio: 0.05,
              impedanceEvidence: const CableImpedanceEvidence(
                resistanceOhmPerKm: 7.41,
                sourceKey: 'impedance-table',
              ),
              ampacitySections: [
                SectionAmpacityEvidence(
                  sectionId: 'wall',
                  baseAmpacityA: 21,
                  factors: const [],
                  sourceKey: 'ampacity-table',
                ),
              ],
              sourceId: 'cable-evidence',
              sourceRevision: 'r1',
            ),
          ],
          minimumConductorCount: 3,
          allowedConductorMaterials: const {ConductorMaterial.copper},
          minimumCableRatedVoltageV: 450,
          prospectiveShortCircuitCurrentA: 3500,
          protectionCandidates: const [_mcb16],
          allowedProtectionKinds: const {OvercurrentDeviceKind.mcb},
          minimumProtectionPoleCount: 1,
          sourceId: 'closure-policy',
          sourceRevision: 'r1',
        ),
      ],
    );

ElectricalShortCircuitClosureRequest _d4Request(
  ElectricalCircuitClosureResult d3Closure,
) =>
    ElectricalShortCircuitClosureRequest(
      d3Closure: d3Closure,
      policies: [
        ElectricalShortCircuitClosurePolicy(
          circuitId: 'circuit-001',
          disconnectionFaultCase: _faultCase('minimum-disconnection', 0.04),
          thermalFaultCase: _faultCase('maximum-thermal', 0.02),
          requiredMaxDisconnectionTimeS: 0.4,
          timeCurrentEvidence: ProtectiveDeviceTimeCurrentEvidence(
            deviceId: _mcb16.id,
            points: const [
              TimeCurrentUpperBoundPoint(
                minimumFaultCurrentA: 80,
                maximumOperatingTimeS: 0.4,
              ),
              TimeCurrentUpperBoundPoint(
                minimumFaultCurrentA: 800,
                maximumOperatingTimeS: 0.1,
              ),
            ],
            sourceId: 'manufacturer-time-current',
            sourceRevision: '2026.1',
          ),
          thermalEvidence: ProtectiveConductorThermalEvidence(
            cableId: 'cable-2.5',
            crossSectionMm2: 2.5,
            kCoefficientArootSPerMm2: 143,
            sourceId: 'thermal-registry',
            sourceRevision: '2026.1',
          ),
          sourceId: 'd4-policy',
          sourceRevision: '2026.1',
        ),
      ],
    );

FaultLoopCaseEvidence _faultCase(String id, double sourceResistanceOhm) =>
    FaultLoopCaseEvidence(
      id: id,
      cableId: 'cable-2.5',
      faultVoltageV: 230,
      sourceResistanceOhm: sourceResistanceOhm,
      sourceReactanceOhm: 0,
      phaseResistanceOhmPerKm: 7.41,
      phaseReactanceOhmPerKm: 0,
      protectiveResistanceOhmPerKm: 7.41,
      protectiveReactanceOhmPerKm: 0,
      sourceId: 'fault-loop-registry',
      sourceRevision: '2026.1',
    );

CableSpec _cable() => const CableSpec(
      id: 'cable-2.5',
      name: 'Cu 3x2.5',
      medium: RouteMediumProfile.acPower,
      outerDiameterMm: 10,
      segregationClass: CableSegregationClass.power,
      conductorMaterial: ConductorMaterial.copper,
      conductorCount: 3,
      conductorCrossSectionMm2: 2.5,
      ratedVoltageV: 450,
    );

_CalculationBundle _calculationBundle({required String circuitId}) {
  final load = ElectricalLoadInput(
    id: 'load-a',
    ratedPowerW: 3000,
    quantity: 1,
    utilizationFactor: 1,
    powerFactor: 1,
    reactivePowerKind: ElectricalReactivePowerKind.lagging,
    sourceId: 'qualification-load',
    sourceRevision: 'r1',
  );
  final circuit = SynthesizedElectricalCircuit(
    id: circuitId,
    requiredPhaseSystem: ElectricalLoadPhaseSystem.singlePhaseAc,
    dedicated: false,
    loads: [
      CircuitSynthesisLoad(
        load: load,
        kind: ElectricalCircuitLoadKind.other,
        locationId: 'qualification',
        requiredPhaseSystem: ElectricalLoadPhaseSystem.singlePhaseAc,
      ),
    ],
    groupingPolicyId: 'grouping-policy',
    groupingPolicyRevision: 'r1',
    dedicatedPolicyId: 'dedicated-policy',
    dedicatedPolicyRevision: 'r1',
  );
  final request = ElectricalCircuitCalculationRequest(
    synthesis: ElectricalCircuitSynthesisResult(circuits: [circuit]),
    policies: [
      ElectricalCircuitCalculationPolicy(
        circuitId: circuit.id,
        nominalVoltageV: 230,
        diversityPolicy: const ElectricalDiversityPolicy(
          id: 'diversity',
          factor: 1,
          sourceId: 'qualification-policy',
          sourceRevision: 'r1',
        ),
        reservePolicy: const ElectricalReservePolicy(
          id: 'reserve',
          reserveRatio: 0,
          sourceId: 'qualification-policy',
          sourceRevision: 'r1',
        ),
        sourceId: 'calculation-policy',
        sourceRevision: 'r1',
      ),
    ],
  );
  return _CalculationBundle(
    request: request,
    calculation: ElectricalCircuitCalculationEngine.calculate(request),
  );
}

_PhaseBundle _phaseAssignmentFor({
  required String circuitId,
  _CalculationBundle? calculationBundle,
}) {
  final bundle =
      calculationBundle ?? _calculationBundle(circuitId: circuitId);
  final request = ElectricalPhaseAssignmentRequest(
    calculation: bundle.calculation,
    boardPhaseSystem: DistributionBoardPhaseSystem.singlePhase,
    lineNeutralVoltageV: 230,
  );
  return _PhaseBundle(
    request: request,
    assignment: PhaseAssignmentEngine.assign(request),
  );
}

ApartmentEngineeringDesignRequirements _baseRequirements() =>
    ApartmentEngineeringDesignRequirements(
      requirementsVersion: apartmentEngineeringRequirementsVersion,
      selectedCandidateFingerprint: 'candidate-fp',
      projectionFingerprint: 'projection-fp',
      graphFingerprint: 'graph-fp',
      placementFingerprint: 'placement-fp',
      normativeEvidenceFingerprint: 'normative-fp',
      normativeProfileId: 'kz.residential.lv',
      normativeProfileVersion: '2026.1',
      requirements: [
        _provenRequirement(
          id: 'supply',
          domain: ApartmentEngineeringRequirementDomain.supply,
          criticality:
              ApartmentEngineeringRequirementCriticality.safetyCritical,
          facts: const [
            'supply.availablePowerW',
            'supply.frequencyHz',
            'supply.phaseCount',
            'supply.prospectiveShortCircuitCurrentA',
            'supply.voltageV',
          ],
        ),
        _provenRequirement(
          id: 'load',
          domain: ApartmentEngineeringRequirementDomain.load,
          criticality:
              ApartmentEngineeringRequirementCriticality.engineeringCritical,
          facts: const [
            'load.connectedPowerW',
            'load.designCurrentA',
            'load.designPowerW',
            'load.diversityPolicy',
            'load.reservePolicy',
          ],
        ),
        ApartmentEngineeringRequirement(
          requirementId: 'req-circuit',
          domain: ApartmentEngineeringRequirementDomain.circuit,
          subjectKind: ApartmentEngineeringRequirementSubjectKind.projection,
          subjectStableId: 'projection-fp',
          evidenceState:
              ApartmentEngineeringRequirementEvidenceState.indeterminate,
          criticality:
              ApartmentEngineeringRequirementCriticality.engineeringCritical,
          rationaleCode: 'qualification.circuit-pending',
          requiredFactKeys: const [
            'circuit.conductorConstraints',
            'circuit.definition',
            'circuit.installationMethod',
            'circuit.loadAssignments',
          ],
        ),
        ApartmentEngineeringRequirement(
          requirementId: 'req-protection',
          domain: ApartmentEngineeringRequirementDomain.protection,
          subjectKind: ApartmentEngineeringRequirementSubjectKind.projection,
          subjectStableId: 'projection-fp',
          evidenceState:
              ApartmentEngineeringRequirementEvidenceState.notEvaluated,
          criticality:
              ApartmentEngineeringRequirementCriticality.safetyCritical,
          rationaleCode: 'qualification.protection-pending',
          requiredFactKeys: const [
            'protection.disconnection',
            'protection.overload',
            'protection.residualCurrent',
            'protection.shortCircuit',
          ],
        ),
      ],
    );

ApartmentEngineeringRequirement _provenRequirement({
  required String id,
  required ApartmentEngineeringRequirementDomain domain,
  required ApartmentEngineeringRequirementCriticality criticality,
  required List<String> facts,
}) =>
    ApartmentEngineeringRequirement(
      requirementId: 'req-$id',
      domain: domain,
      subjectKind: ApartmentEngineeringRequirementSubjectKind.projection,
      subjectStableId: 'projection-fp',
      evidenceState: ApartmentEngineeringRequirementEvidenceState.proven,
      criticality: criticality,
      rationaleCode: 'qualification.$id-proven',
      requiredFactKeys: facts,
      factEvidence: [
        for (final key in facts) _fact(key, 'qualification-value')
      ],
    );

ApartmentEngineeringFactEvidence _fact(String key, String value) =>
    ApartmentEngineeringFactEvidence(
      factKey: key,
      valueKind: ApartmentEngineeringFactValueKind.text,
      value: value,
      unit: ApartmentEngineeringFactUnit.code,
      sourceId: 'qualification',
      sourceRevision: 'r1',
    );

ApartmentEngineeringDesignRequirements _replaceFactRevision(
  ApartmentEngineeringDesignRequirements requirements,
  ApartmentEngineeringRequirementDomain domain,
  String factKey,
  String revision,
) {
  final currentRequirement = requirements.requirements.singleWhere(
    (item) => item.domain == domain,
  );
  final currentFact = currentRequirement.factEvidence[factKey]!;
  final updatedRequirement = ApartmentEngineeringRequirement(
    requirementId: currentRequirement.requirementId,
    domain: currentRequirement.domain,
    subjectKind: currentRequirement.subjectKind,
    subjectStableId: currentRequirement.subjectStableId,
    evidenceState: currentRequirement.evidenceState,
    criticality: currentRequirement.criticality,
    rationaleCode: currentRequirement.rationaleCode,
    requiredFactKeys: currentRequirement.requiredFactKeys,
    factEvidence: [
      for (final fact in currentRequirement.factEvidence.values)
        if (fact.factKey != factKey) fact,
      ApartmentEngineeringFactEvidence(
        factKey: currentFact.factKey,
        valueKind: currentFact.valueKind,
        value: currentFact.value,
        unit: currentFact.unit,
        sourceId: currentFact.sourceId,
        sourceRevision: revision,
      ),
    ],
  );

  return ApartmentEngineeringDesignRequirements(
    requirementsVersion: requirements.requirementsVersion,
    selectedCandidateFingerprint: requirements.selectedCandidateFingerprint,
    projectionFingerprint: requirements.projectionFingerprint,
    graphFingerprint: requirements.graphFingerprint,
    placementFingerprint: requirements.placementFingerprint,
    normativeEvidenceFingerprint: requirements.normativeEvidenceFingerprint,
    normativeProfileId: requirements.normativeProfileId,
    normativeProfileVersion: requirements.normativeProfileVersion,
    requirements: [
      for (final item in requirements.requirements)
        if (item.requirementId == currentRequirement.requirementId)
          updatedRequirement
        else
          item,
    ],
  );
}

final class _D8Fixture {
  const _D8Fixture({
    required this.d7Closure,
    required this.phaseAssignment,
    required this.requirements,
  });

  final ElectricalCircuitInstallationMethodClosureResult d7Closure;
  final ElectricalPhaseAssignmentResult phaseAssignment;
  final ApartmentEngineeringDesignRequirements requirements;

  ApartmentEngineeringOutputProjection project() =>
      ApartmentEngineeringOutputProjectionService.project(
        d7Closure: d7Closure,
        phaseAssignment: phaseAssignment,
        requirements: requirements,
      );
}

final class _CalculationBundle {
  const _CalculationBundle({
    required this.request,
    required this.calculation,
  });

  final ElectricalCircuitCalculationRequest request;
  final ElectricalCircuitCalculationResult calculation;
}

final class _PhaseBundle {
  const _PhaseBundle({
    required this.request,
    required this.assignment,
  });

  final ElectricalPhaseAssignmentRequest request;
  final ElectricalPhaseAssignmentResult assignment;
}
