import 'package:elecx/src/application/project/wizard/apartment/apartment_circuit_closure_evidence.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_engineering_requirements.dart';
import 'package:elecx/src/domain/cable_spec.dart';
import 'package:elecx/src/domain/electrical_circuit_calculation.dart';
import 'package:elecx/src/domain/electrical_circuit_synthesis.dart';
import 'package:elecx/src/domain/electrical_load_calculation.dart';
import 'package:elecx/src/domain/overcurrent_protection.dart';
import 'package:elecx/src/domain/route_medium.dart';
import 'package:elecx/src/engine/cable_sizing_engine.dart';
import 'package:elecx/src/engine/electrical_circuit_calculation_engine.dart';
import 'package:elecx/src/engine/electrical_circuit_closure_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P9.5-D3 closure evidence', () {
    test('Q22 proves conductor constraints and overload only', () {
      final fixture = _fixture();
      final updated = ApartmentCircuitClosureEvidenceService.apply(
        requirements: _requirements(),
        request: fixture.request,
        closure: fixture.closure,
      );

      final circuit = updated.requirements.singleWhere(
        (item) => item.domain == ApartmentEngineeringRequirementDomain.circuit,
      );
      final protection = updated.requirements.singleWhere(
        (item) =>
            item.domain == ApartmentEngineeringRequirementDomain.protection,
      );

      expect(
        circuit.factEvidence.keys,
        containsAll([
          'circuit.definition',
          'circuit.loadAssignments',
          'circuit.conductorConstraints',
        ]),
      );
      expect(
          circuit.factEvidence, isNot(contains('circuit.installationMethod')));
      expect(
        protection.factEvidence.keys,
        contains('protection.overload'),
      );
      expect(
          protection.factEvidence, isNot(contains('protection.shortCircuit')));
      expect(
        protection.factEvidence,
        isNot(contains('protection.residualCurrent')),
      );
      expect(
          protection.factEvidence, isNot(contains('protection.disconnection')));
      expect(circuit.blocksEquipmentConfiguration, isTrue);
      expect(protection.blocksEquipmentConfiguration, isTrue);
      expect(updated.readyForEquipmentConfiguration, isFalse);
    });

    test('Q23 tampered selected breaker is rejected by binding', () {
      final fixture = _fixture();
      final original = fixture.closure.outcomes.single;
      final tampered = ElectricalCircuitClosureResult(
        outcomes: [
          ElectricalCircuitClosureOutcome(
            circuit: original.circuit,
            policy: original.policy,
            cableEvaluations: original.cableEvaluations,
            selectedCable: original.selectedCable,
            selectedCableSizing: original.selectedCableSizing,
            protectionSelection: const OvercurrentProtectionSelectionResult(
              status: OvercurrentSelectionStatus.selected,
              selected: _c20,
              rejections: {},
            ),
            protectionPolicyRejections: const {},
            status: ElectricalCircuitClosureStatus.closed,
          ),
        ],
      );

      expect(
        () => ApartmentCircuitClosureEvidenceService.apply(
          requirements: _requirements(),
          request: fixture.request,
          closure: tampered,
        ),
        throwsArgumentError,
      );
    });

    test('Q24 incomplete circuit closure cannot publish projection evidence',
        () {
      final calculation = _calculation();
      final request = ElectricalCircuitClosureRequest(
        calculation: calculation,
        policies: [
          _policy(
            circuitId: 'circuit-001',
            prospectiveShortCircuitCurrentA: 7000,
          ),
        ],
      );
      final closure = ElectricalCircuitClosureEngine.close(request);
      expect(closure.isFullyClosed, isFalse);

      expect(
        () => ApartmentCircuitClosureEvidenceService.apply(
          requirements: _requirements(),
          request: request,
          closure: closure,
        ),
        throwsArgumentError,
      );
    });
  });
}

const _c16 = OvercurrentProtectiveDeviceSpec(
  id: 'mcb-c16-6ka',
  kind: OvercurrentDeviceKind.mcb,
  ratedCurrentA: 16,
  breakingCapacityKa: 6,
  poleCount: 1,
  tripCurve: OvercurrentTripCurve.c,
  sourceId: 'device-catalog',
  sourceRevision: 'r1',
);

const _c20 = OvercurrentProtectiveDeviceSpec(
  id: 'mcb-c20-6ka',
  kind: OvercurrentDeviceKind.mcb,
  ratedCurrentA: 20,
  breakingCapacityKa: 6,
  poleCount: 1,
  tripCurve: OvercurrentTripCurve.c,
  sourceId: 'device-catalog',
  sourceRevision: 'r1',
);

_D3Fixture _fixture() {
  final calculation = _calculation();
  final request = ElectricalCircuitClosureRequest(
    calculation: calculation,
    policies: [_policy(circuitId: 'circuit-001')],
  );
  return _D3Fixture(
    request: request,
    closure: ElectricalCircuitClosureEngine.close(request),
  );
}

ElectricalCircuitClosurePolicy _policy({
  required String circuitId,
  double prospectiveShortCircuitCurrentA = 3500,
}) =>
    ElectricalCircuitClosurePolicy(
      circuitId: circuitId,
      cableCandidates: [
        ElectricalCircuitCableCandidate(
          cable: CableSpec(
            id: 'cable-2.5',
            name: 'Cu 3x2.5',
            medium: RouteMediumProfile.acPower,
            outerDiameterMm: 10,
            segregationClass: CableSegregationClass.power,
            conductorMaterial: ConductorMaterial.copper,
            conductorCount: 3,
            conductorCrossSectionMm2: 2.5,
            ratedVoltageV: 450,
          ),
          routeLengthMm: 15000,
          maxVoltageDropRatio: 0.03,
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
      prospectiveShortCircuitCurrentA: prospectiveShortCircuitCurrentA,
      protectionCandidates: const [_c16, _c20],
      allowedProtectionKinds: const {OvercurrentDeviceKind.mcb},
      minimumProtectionPoleCount: 1,
      sourceId: 'closure-policy',
      sourceRevision: 'r1',
    );

ElectricalCircuitCalculationResult _calculation() {
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
    id: 'circuit-001',
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
  return ElectricalCircuitCalculationEngine.calculate(
    ElectricalCircuitCalculationRequest(
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
          sourceId: 'qualification-circuit-policy',
          sourceRevision: 'r1',
        ),
      ],
    ),
  );
}

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
        ApartmentEngineeringRequirement(
          requirementId: 'req-circuit',
          domain: ApartmentEngineeringRequirementDomain.circuit,
          subjectKind: ApartmentEngineeringRequirementSubjectKind.projection,
          subjectStableId: 'projection-fp',
          evidenceState:
              ApartmentEngineeringRequirementEvidenceState.indeterminate,
          criticality:
              ApartmentEngineeringRequirementCriticality.engineeringCritical,
          rationaleCode: 'qualification.circuit-d2',
          requiredFactKeys: const [
            'circuit.conductorConstraints',
            'circuit.definition',
            'circuit.installationMethod',
            'circuit.loadAssignments',
          ],
          factEvidence: [
            ApartmentEngineeringFactEvidence(
              factKey: 'circuit.definition',
              valueKind: ApartmentEngineeringFactValueKind.text,
              value: 'd2-definition',
              unit: ApartmentEngineeringFactUnit.code,
              sourceId: 'electrical.circuit-calculation.v1',
              sourceRevision: 'electrical.phase-assignment.v1',
            ),
            ApartmentEngineeringFactEvidence(
              factKey: 'circuit.loadAssignments',
              valueKind: ApartmentEngineeringFactValueKind.text,
              value: 'd2-load-assignments',
              unit: ApartmentEngineeringFactUnit.code,
              sourceId: 'electrical.circuit-calculation.v1',
              sourceRevision: 'electrical.phase-assignment.v1',
            ),
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

final class _D3Fixture {
  const _D3Fixture({required this.request, required this.closure});

  final ElectricalCircuitClosureRequest request;
  final ElectricalCircuitClosureResult closure;
}
