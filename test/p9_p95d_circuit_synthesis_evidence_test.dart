import 'package:elecx/src/application/project/wizard/apartment/apartment_circuit_synthesis_evidence.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_engineering_requirements.dart';
import 'package:elecx/src/domain/electrical_circuit_synthesis.dart';
import 'package:elecx/src/domain/electrical_load_calculation.dart';
import 'package:elecx/src/engine/circuit_grouping_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P9.5-D circuit synthesis evidence', () {
    test('Q01 synthesis proves assignments but keeps circuit domain blocking',
        () {
      final request = _request();
      final synthesis = CircuitGroupingEngine.synthesize(request);
      final updated = ApartmentCircuitSynthesisEvidenceService.apply(
        requirements: _requirements(),
        request: request,
        synthesis: synthesis,
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
      expect(circuit.blocksEquipmentConfiguration, isTrue);
      expect(circuit.factEvidence,
          isNot(contains('circuit.conductorConstraints')));
      expect(
          circuit.factEvidence, isNot(contains('circuit.installationMethod')));
      expect(updated.readyForEquipmentConfiguration, isFalse);
    });

    test('Q02 evidence binding rejects a tampered synthesis result', () {
      final request = _request();
      final synthesis = CircuitGroupingEngine.synthesize(request);
      final original = synthesis.circuits.first;
      final tampered = ElectricalCircuitSynthesisResult(
        circuits: [
          SynthesizedElectricalCircuit(
            id: 'tampered-circuit',
            requiredPhaseSystem: original.requiredPhaseSystem,
            dedicated: original.dedicated,
            loads: original.loads,
            groupingPolicyId: original.groupingPolicyId,
            groupingPolicyRevision: original.groupingPolicyRevision,
            dedicatedPolicyId: original.dedicatedPolicyId,
            dedicatedPolicyRevision: original.dedicatedPolicyRevision,
            dedicatedRuleId: original.dedicatedRuleId,
          ),
          ...synthesis.circuits.skip(1),
        ],
      );

      expect(
        () => ApartmentCircuitSynthesisEvidenceService.apply(
          requirements: _requirements(),
          request: request,
          synthesis: tampered,
        ),
        throwsArgumentError,
      );
    });
  });
}

ElectricalCircuitSynthesisRequest _request() =>
    ElectricalCircuitSynthesisRequest(
      loads: [
        _load('light', 500, ElectricalCircuitLoadKind.lighting),
        _load('socket', 1500, ElectricalCircuitLoadKind.generalSocket),
      ],
      groupingPolicy: CircuitGroupingPolicy(
        id: 'grouping-policy',
        maxGroupedLoadsPerCircuit: 8,
        maxGroupedConnectedPowerW: 5000,
        separateByLocation: false,
        separateByLoadKind: true,
        sourceId: 'project-circuit-policy',
        sourceRevision: 'r1',
      ),
      dedicatedCircuitPolicy: DedicatedCircuitPolicy(
        id: 'dedicated-policy',
        rules: const [],
        sourceId: 'project-circuit-policy',
        sourceRevision: 'r1',
      ),
    );

CircuitSynthesisLoad _load(
  String id,
  int powerW,
  ElectricalCircuitLoadKind kind,
) =>
    CircuitSynthesisLoad(
      load: ElectricalLoadInput(
        id: id,
        ratedPowerW: powerW,
        quantity: 1,
        utilizationFactor: 1,
        powerFactor: 1,
        reactivePowerKind: ElectricalReactivePowerKind.lagging,
        sourceId: 'qualification-load',
        sourceRevision: 'r1',
      ),
      kind: kind,
      locationId: 'apartment',
      requiredPhaseSystem: ElectricalLoadPhaseSystem.singlePhaseAc,
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
