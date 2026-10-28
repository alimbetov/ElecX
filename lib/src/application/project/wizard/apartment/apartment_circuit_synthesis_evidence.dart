import '../../../../domain/electrical_circuit_synthesis.dart';
import '../../../../engine/circuit_grouping_engine.dart';
import 'apartment_engineering_requirements.dart';
import 'p9_canonical_serialization.dart';

/// Adds deterministic circuit-definition and load-assignment evidence without
/// falsely proving conductor constraints or installation method.
abstract final class ApartmentCircuitSynthesisEvidenceService {
  static ApartmentEngineeringDesignRequirements apply({
    required ApartmentEngineeringDesignRequirements requirements,
    required ElectricalCircuitSynthesisRequest request,
    required ElectricalCircuitSynthesisResult synthesis,
  }) {
    final circuitRequirements = requirements.requirements
        .where(
          (item) =>
              item.domain == ApartmentEngineeringRequirementDomain.circuit,
        )
        .toList(growable: false);
    if (circuitRequirements.length != 1) {
      throw StateError(
        'P9.5-A must contain exactly one circuit requirement; found '
        '${circuitRequirements.length}.',
      );
    }

    _validateSynthesisBinding(request: request, synthesis: synthesis);
    final current = circuitRequirements.single;
    final policyRevision = p9CanonicalSerializeFields([
      MapEntry('groupingPolicy', request.groupingPolicy.id),
      MapEntry('groupingRevision', request.groupingPolicy.sourceRevision),
      MapEntry('dedicatedPolicy', request.dedicatedCircuitPolicy.id),
      MapEntry(
        'dedicatedRevision',
        request.dedicatedCircuitPolicy.sourceRevision,
      ),
    ]);
    final partialCircuit = ApartmentEngineeringRequirement(
      requirementId: current.requirementId,
      domain: current.domain,
      subjectKind: current.subjectKind,
      subjectStableId: current.subjectStableId,
      evidenceState: ApartmentEngineeringRequirementEvidenceState.indeterminate,
      criticality: current.criticality,
      rationaleCode: 'p9.requirements.circuit-synthesis-proven-partial',
      requiredFactKeys: current.requiredFactKeys,
      factEvidence: [
        ApartmentEngineeringFactEvidence(
          factKey: 'circuit.definition',
          valueKind: ApartmentEngineeringFactValueKind.text,
          value: _definitionEvidence(synthesis),
          unit: ApartmentEngineeringFactUnit.code,
          sourceId: electricalCircuitSynthesisVersion,
          sourceRevision: policyRevision,
        ),
        ApartmentEngineeringFactEvidence(
          factKey: 'circuit.loadAssignments',
          valueKind: ApartmentEngineeringFactValueKind.text,
          value: _assignmentEvidence(synthesis),
          unit: ApartmentEngineeringFactUnit.code,
          sourceId: electricalCircuitSynthesisVersion,
          sourceRevision: policyRevision,
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
            partialCircuit
          else
            item,
      ],
    );
  }

  static String _definitionEvidence(
          ElectricalCircuitSynthesisResult synthesis) =>
      p9CanonicalSerializeFields([
        for (final circuit in synthesis.circuits)
          MapEntry(
            circuit.id,
            p9CanonicalSerializeFields([
              MapEntry('phaseSystem', circuit.requiredPhaseSystem.name),
              MapEntry('dedicated', circuit.dedicated.toString()),
              MapEntry('dedicatedRule', circuit.dedicatedRuleId ?? 'none'),
            ]),
          ),
      ]);

  static String _assignmentEvidence(
          ElectricalCircuitSynthesisResult synthesis) =>
      p9CanonicalSerializeFields([
        for (final circuit in synthesis.circuits)
          MapEntry(circuit.id, circuit.loadIds.join(',')),
      ]);

  static void _validateSynthesisBinding({
    required ElectricalCircuitSynthesisRequest request,
    required ElectricalCircuitSynthesisResult synthesis,
  }) {
    final expected = CircuitGroupingEngine.synthesize(request);
    if (expected.circuits.length != synthesis.circuits.length) {
      throw ArgumentError(
        'Circuit synthesis result does not match the supplied request.',
      );
    }
    for (var index = 0; index < expected.circuits.length; index++) {
      final left = expected.circuits[index];
      final right = synthesis.circuits[index];
      if (left.id != right.id ||
          left.requiredPhaseSystem != right.requiredPhaseSystem ||
          left.dedicated != right.dedicated ||
          left.dedicatedRuleId != right.dedicatedRuleId ||
          left.groupingPolicyId != right.groupingPolicyId ||
          left.groupingPolicyRevision != right.groupingPolicyRevision ||
          left.dedicatedPolicyId != right.dedicatedPolicyId ||
          left.dedicatedPolicyRevision != right.dedicatedPolicyRevision ||
          !_sameStringList(left.loadIds, right.loadIds)) {
        throw ArgumentError(
          'Circuit synthesis result does not match the supplied request.',
        );
      }
    }
  }

  static bool _sameStringList(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }
}
