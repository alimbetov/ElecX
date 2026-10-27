import 'package:elecx/src/application/project/wizard/apartment/apartment_circuit_calculation_evidence.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_engineering_requirements.dart';
import 'package:elecx/src/domain/distribution_board_load.dart';
import 'package:elecx/src/domain/electrical_circuit_calculation.dart';
import 'package:elecx/src/domain/electrical_circuit_synthesis.dart';
import 'package:elecx/src/domain/electrical_load_calculation.dart';
import 'package:elecx/src/domain/electrical_phase_assignment.dart';
import 'package:elecx/src/engine/electrical_circuit_calculation_engine.dart';
import 'package:elecx/src/engine/phase_assignment_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P9.5-D2 circuit calculation evidence', () {
    test('Q10 binds calculated P/Q/S/Ib and phase while gate stays closed', () {
      final fixture = _calculatedFixture();
      final updated = ApartmentCircuitCalculationEvidenceService.apply(
        requirements: _requirements(),
        calculationRequest: fixture.calculationRequest,
        calculation: fixture.calculation,
        assignmentRequest: fixture.assignmentRequest,
        assignment: fixture.assignment,
      );

      final circuit = updated.requirements.singleWhere(
        (item) => item.domain == ApartmentEngineeringRequirementDomain.circuit,
      );
      expect(
        circuit.evidenceState,
        ApartmentEngineeringRequirementEvidenceState.indeterminate,
      );
      expect(circuit.factEvidence.keys, [
        'circuit.definition',
        'circuit.loadAssignments',
      ]);
      final definition =
          circuit.factEvidence['circuit.definition']!.value as String;
      expect(definition, contains('designCurrentA'));
      expect(definition, contains('phase'));
      expect(definition, contains('l1'));
      expect(circuit.blocksEquipmentConfiguration, isTrue);
      expect(updated.readyForEquipmentConfiguration, isFalse);
    });

    test('Q11 tampered phase assignment is rejected', () {
      final fixture = _calculatedFixture();
      final original = fixture.assignment.circuits.first;
      final tampered = ElectricalPhaseAssignmentResult(
        circuits: [
          PhaseAssignedElectricalCircuit(
            circuit: original.circuit,
            phase: original.phase == DistributionBoardPhase.l1
                ? DistributionBoardPhase.l2
                : DistributionBoardPhase.l1,
          ),
          ...fixture.assignment.circuits.skip(1),
        ],
        phaseLoads: fixture.assignment.phaseLoads,
        maxPhaseCurrentA: fixture.assignment.maxPhaseCurrentA,
        phaseCurrentImbalanceRatio:
            fixture.assignment.phaseCurrentImbalanceRatio,
      );

      expect(
        () => ApartmentCircuitCalculationEvidenceService.apply(
          requirements: _requirements(),
          calculationRequest: fixture.calculationRequest,
          calculation: fixture.calculation,
          assignmentRequest: fixture.assignmentRequest,
          assignment: tampered,
        ),
        throwsArgumentError,
      );
    });

    test('Q12 same-power load identity substitution is rejected', () {
      final fixture = _calculatedFixture();
      final original = fixture.calculation.circuits.first;
      final originalLoad = original.circuit.loads.single;
      final substitutedLoad = ElectricalLoadInput(
        id: 'substituted-load',
        ratedPowerW: originalLoad.load.ratedPowerW,
        quantity: originalLoad.load.quantity,
        utilizationFactor: originalLoad.load.utilizationFactor,
        powerFactor: originalLoad.load.powerFactor,
        reactivePowerKind: originalLoad.load.reactivePowerKind,
        sourceId: originalLoad.load.sourceId,
        sourceRevision: originalLoad.load.sourceRevision,
      );
      final substitutedCircuit = SynthesizedElectricalCircuit(
        id: original.id,
        requiredPhaseSystem: original.phaseSystem,
        dedicated: false,
        loads: [
          CircuitSynthesisLoad(
            load: substitutedLoad,
            kind: originalLoad.kind,
            locationId: originalLoad.locationId,
            requiredPhaseSystem: originalLoad.requiredPhaseSystem,
          ),
        ],
        groupingPolicyId: original.circuit.groupingPolicyId,
        groupingPolicyRevision: original.circuit.groupingPolicyRevision,
        dedicatedPolicyId: original.circuit.dedicatedPolicyId,
        dedicatedPolicyRevision: original.circuit.dedicatedPolicyRevision,
      );
      final tamperedCalculation = ElectricalCircuitCalculationResult(
        circuits: [
          CalculatedElectricalCircuit(
            circuit: substitutedCircuit,
            calculation: original.calculation,
            policySourceId: original.policySourceId,
            policySourceRevision: original.policySourceRevision,
          ),
          ...fixture.calculation.circuits.skip(1),
        ],
      );

      expect(
        () => ApartmentCircuitCalculationEvidenceService.apply(
          requirements: _requirements(),
          calculationRequest: fixture.calculationRequest,
          calculation: tamperedCalculation,
          assignmentRequest: fixture.assignmentRequest,
          assignment: fixture.assignment,
        ),
        throwsArgumentError,
      );
    });
  });
}

_CalculatedFixture _calculatedFixture() {
  final synthesis = ElectricalCircuitSynthesisResult(
    circuits: [
      _circuit('circuit-001', _load('load-a', 2300)),
      _circuit('circuit-002', _load('load-b', 1840, powerFactor: 0.8)),
      _circuit('circuit-003', _load('load-c', 1150)),
    ],
  );
  final calculationRequest = ElectricalCircuitCalculationRequest(
    synthesis: synthesis,
    policies: [
      for (final circuit in synthesis.circuits) _policy(circuit.id),
    ],
  );
  final calculation =
      ElectricalCircuitCalculationEngine.calculate(calculationRequest);
  final assignmentRequest = ElectricalPhaseAssignmentRequest(
    calculation: calculation,
    boardPhaseSystem: DistributionBoardPhaseSystem.threePhase,
    lineNeutralVoltageV: 230,
    lineLineVoltageV: 400,
  );
  final assignment = PhaseAssignmentEngine.assign(assignmentRequest);
  return _CalculatedFixture(
    calculationRequest: calculationRequest,
    calculation: calculation,
    assignmentRequest: assignmentRequest,
    assignment: assignment,
  );
}

SynthesizedElectricalCircuit _circuit(
  String id,
  ElectricalLoadInput load,
) =>
    SynthesizedElectricalCircuit(
      id: id,
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

ElectricalCircuitCalculationPolicy _policy(String circuitId) =>
    ElectricalCircuitCalculationPolicy(
      circuitId: circuitId,
      nominalVoltageV: 230,
      diversityPolicy: ElectricalDiversityPolicy(
        id: 'diversity:$circuitId',
        factor: 1,
        sourceId: 'qualification-policy',
        sourceRevision: 'r1',
      ),
      reservePolicy: ElectricalReservePolicy(
        id: 'reserve:$circuitId',
        reserveRatio: 0,
        sourceId: 'qualification-policy',
        sourceRevision: 'r1',
      ),
      sourceId: 'qualification-circuit-policy',
      sourceRevision: 'r1',
    );

ElectricalLoadInput _load(
  String id,
  int powerW, {
  double powerFactor = 1,
}) =>
    ElectricalLoadInput(
      id: id,
      ratedPowerW: powerW,
      quantity: 1,
      utilizationFactor: 1,
      powerFactor: powerFactor,
      reactivePowerKind: ElectricalReactivePowerKind.lagging,
      sourceId: 'qualification-load',
      sourceRevision: 'r1',
    );

ApartmentEngineeringDesignRequirements _requirements() =>
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
        _requirement(
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
        _requirement(
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
        _requirement(
          id: 'circuit',
          domain: ApartmentEngineeringRequirementDomain.circuit,
          criticality:
              ApartmentEngineeringRequirementCriticality.engineeringCritical,
          facts: const [
            'circuit.conductorConstraints',
            'circuit.definition',
            'circuit.installationMethod',
            'circuit.loadAssignments',
          ],
        ),
        _requirement(
          id: 'protection',
          domain: ApartmentEngineeringRequirementDomain.protection,
          criticality:
              ApartmentEngineeringRequirementCriticality.safetyCritical,
          facts: const [
            'protection.disconnection',
            'protection.overload',
            'protection.residualCurrent',
            'protection.shortCircuit',
          ],
        ),
      ],
    );

ApartmentEngineeringRequirement _requirement({
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
      evidenceState: ApartmentEngineeringRequirementEvidenceState.notEvaluated,
      criticality: criticality,
      rationaleCode: 'qualification.$id',
      requiredFactKeys: facts,
    );

final class _CalculatedFixture {
  const _CalculatedFixture({
    required this.calculationRequest,
    required this.calculation,
    required this.assignmentRequest,
    required this.assignment,
  });

  final ElectricalCircuitCalculationRequest calculationRequest;
  final ElectricalCircuitCalculationResult calculation;
  final ElectricalPhaseAssignmentRequest assignmentRequest;
  final ElectricalPhaseAssignmentResult assignment;
}
