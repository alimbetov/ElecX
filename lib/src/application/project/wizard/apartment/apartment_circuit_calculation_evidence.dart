import '../../../../domain/electrical_circuit_calculation.dart';
import '../../../../domain/electrical_phase_assignment.dart';
import '../../../../engine/electrical_circuit_calculation_engine.dart';
import '../../../../engine/phase_assignment_engine.dart';
import 'apartment_engineering_requirements.dart';
import 'p9_canonical_serialization.dart';

/// Replaces early circuit-synthesis evidence with calculated P/Q/S/Ib and
/// assigned-phase evidence while keeping conductor/install-method gates closed.
abstract final class ApartmentCircuitCalculationEvidenceService {
  static ApartmentEngineeringDesignRequirements apply({
    required ApartmentEngineeringDesignRequirements requirements,
    required ElectricalCircuitCalculationRequest calculationRequest,
    required ElectricalCircuitCalculationResult calculation,
    required ElectricalPhaseAssignmentRequest assignmentRequest,
    required ElectricalPhaseAssignmentResult assignment,
  }) {
    final circuitRequirements = requirements.requirements
        .where(
          (item) => item.domain == ApartmentEngineeringRequirementDomain.circuit,
        )
        .toList(growable: false);
    if (circuitRequirements.length != 1) {
      throw StateError(
        'P9.5-A must contain exactly one circuit requirement; found '
        '${circuitRequirements.length}.',
      );
    }

    _validateCalculationBinding(calculationRequest, calculation);
    _validateAssignmentBinding(
      calculation: calculation,
      assignmentRequest: assignmentRequest,
      assignment: assignment,
    );

    final current = circuitRequirements.single;
    final calculatedCircuit = ApartmentEngineeringRequirement(
      requirementId: current.requirementId,
      domain: current.domain,
      subjectKind: current.subjectKind,
      subjectStableId: current.subjectStableId,
      evidenceState: ApartmentEngineeringRequirementEvidenceState.indeterminate,
      criticality: current.criticality,
      rationaleCode: 'p9.requirements.circuit-calculated-assigned-partial',
      requiredFactKeys: current.requiredFactKeys,
      factEvidence: [
        ApartmentEngineeringFactEvidence(
          factKey: 'circuit.definition',
          valueKind: ApartmentEngineeringFactValueKind.text,
          value: _definitionEvidence(assignment),
          unit: ApartmentEngineeringFactUnit.code,
          sourceId: electricalCircuitCalculationVersion,
          sourceRevision: electricalPhaseAssignmentVersion,
        ),
        ApartmentEngineeringFactEvidence(
          factKey: 'circuit.loadAssignments',
          valueKind: ApartmentEngineeringFactValueKind.text,
          value: _assignmentEvidence(calculation),
          unit: ApartmentEngineeringFactUnit.code,
          sourceId: electricalCircuitCalculationVersion,
          sourceRevision: electricalPhaseAssignmentVersion,
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
          if (item.domain == ApartmentEngineeringRequirementDomain.circuit)
            calculatedCircuit
          else
            item,
      ],
    );
  }

  static String _definitionEvidence(ElectricalPhaseAssignmentResult result) =>
      p9CanonicalSerializeFields([
        for (final assigned in result.circuits)
          MapEntry(
            assigned.id,
            p9CanonicalSerializeFields([
              MapEntry('phaseSystem', assigned.circuit.phaseSystem.name),
              MapEntry('phase', assigned.phase?.name ?? 'threePhaseBalanced'),
              MapEntry(
                'connectedPowerW',
                assigned.circuit.calculation.connectedPowerW.toString(),
              ),
              MapEntry(
                'designPowerW',
                assigned.circuit.calculation.designPowerW.toString(),
              ),
              MapEntry(
                'designReactivePowerVar',
                assigned.circuit.calculation.designReactivePowerVar.toString(),
              ),
              MapEntry(
                'designApparentPowerVa',
                assigned.circuit.calculation.designApparentPowerVa.toString(),
              ),
              MapEntry(
                'designCurrentA',
                assigned.circuit.calculation.designCurrentA.toString(),
              ),
              MapEntry(
                'policySourceId',
                assigned.circuit.policySourceId,
              ),
              MapEntry(
                'policySourceRevision',
                assigned.circuit.policySourceRevision,
              ),
            ]),
          ),
      ]);

  static String _assignmentEvidence(ElectricalCircuitCalculationResult result) =>
      p9CanonicalSerializeFields([
        for (final calculated in result.circuits)
          MapEntry(calculated.id, calculated.circuit.loadIds.join(',')),
      ]);

  static void _validateCalculationBinding(
    ElectricalCircuitCalculationRequest request,
    ElectricalCircuitCalculationResult result,
  ) {
    final expected = ElectricalCircuitCalculationEngine.calculate(request);
    if (!_sameCalculation(expected, result)) {
      throw ArgumentError(
        'Circuit calculation result does not match the supplied request.',
      );
    }
  }

  static void _validateAssignmentBinding({
    required ElectricalCircuitCalculationResult calculation,
    required ElectricalPhaseAssignmentRequest assignmentRequest,
    required ElectricalPhaseAssignmentResult assignment,
  }) {
    if (!_sameCalculation(assignmentRequest.calculation, calculation)) {
      throw ArgumentError(
        'Phase-assignment request is not bound to the supplied calculation.',
      );
    }
    final expected = PhaseAssignmentEngine.assign(assignmentRequest);
    if (expected.circuits.length != assignment.circuits.length ||
        expected.phaseLoads.length != assignment.phaseLoads.length ||
        expected.maxPhaseCurrentA != assignment.maxPhaseCurrentA ||
        expected.phaseCurrentImbalanceRatio !=
            assignment.phaseCurrentImbalanceRatio) {
      throw ArgumentError(
        'Phase-assignment result does not match the supplied request.',
      );
    }
    for (var index = 0; index < expected.circuits.length; index++) {
      final left = expected.circuits[index];
      final right = assignment.circuits[index];
      if (left.id != right.id || left.phase != right.phase) {
        throw ArgumentError(
          'Phase-assignment result does not match the supplied request.',
        );
      }
    }
  }

  static bool _sameCalculation(
    ElectricalCircuitCalculationResult left,
    ElectricalCircuitCalculationResult right,
  ) {
    if (left.circuits.length != right.circuits.length) return false;
    for (var index = 0; index < left.circuits.length; index++) {
      final a = left.circuits[index];
      final b = right.circuits[index];
      final x = a.calculation;
      final y = b.calculation;
      if (a.id != b.id ||
          a.phaseSystem != b.phaseSystem ||
          a.policySourceId != b.policySourceId ||
          a.policySourceRevision != b.policySourceRevision ||
          x.connectedPowerW != y.connectedPowerW ||
          x.designPowerW != y.designPowerW ||
          x.designReactivePowerVar != y.designReactivePowerVar ||
          x.designApparentPowerVa != y.designApparentPowerVa ||
          x.designCurrentA != y.designCurrentA ||
          x.equivalentPowerFactor != y.equivalentPowerFactor ||
          x.diversityPolicyId != y.diversityPolicyId ||
          x.diversityFactor != y.diversityFactor ||
          x.reservePolicyId != y.reservePolicyId ||
          x.reserveRatio != y.reserveRatio ||
          x.nominalVoltageV != y.nominalVoltageV) {
        return false;
      }
    }
    return true;
  }
}
