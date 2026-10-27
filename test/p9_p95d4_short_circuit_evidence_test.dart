import 'package:elecx/src/application/project/wizard/apartment/apartment_engineering_requirements.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_short_circuit_closure_evidence.dart';
import 'package:elecx/src/domain/cable_spec.dart';
import 'package:elecx/src/domain/electrical_circuit_calculation.dart';
import 'package:elecx/src/domain/electrical_circuit_synthesis.dart';
import 'package:elecx/src/domain/electrical_load_calculation.dart';
import 'package:elecx/src/domain/overcurrent_protection.dart';
import 'package:elecx/src/domain/route_medium.dart';
import 'package:elecx/src/engine/cable_sizing_engine.dart';
import 'package:elecx/src/engine/electrical_circuit_calculation_engine.dart';
import 'package:elecx/src/engine/electrical_circuit_closure_engine.dart';
import 'package:elecx/src/engine/electrical_short_circuit_closure_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P9.5-D4 short-circuit evidence', () {
    test('Q36 proves short-circuit and disconnection but keeps RCD blocking',
        () {
      final fixture = _fixture();
      final updated = ApartmentShortCircuitClosureEvidenceService.apply(
        requirements: _requirementsAfterD3(),
        request: fixture.request,
        closure: fixture.closure,
      );
      final protection = updated.requirements.singleWhere(
        (item) =>
            item.domain == ApartmentEngineeringRequirementDomain.protection,
      );

      expect(
        protection.factEvidence.keys,
        containsAll([
          'protection.overload',
          'protection.shortCircuit',
          'protection.disconnection',
        ]),
      );
      expect(
        protection.factEvidence,
        isNot(contains('protection.residualCurrent')),
      );
      expect(
        protection.evidenceState,
        ApartmentEngineeringRequirementEvidenceState.indeterminate,
      );
      expect(protection.blocksEquipmentConfiguration, isTrue);
      expect(updated.readyForEquipmentConfiguration, isFalse);
    });

    test('Q37 tampered D4 result is rejected by recomputation binding', () {
      final fixture = _fixture();
      final original = fixture.closure.outcomes.single;
      final tampered = ElectricalShortCircuitClosureResult(
        outcomes: [
          ElectricalShortCircuitClosureOutcome(
            d3Outcome: original.d3Outcome,
            policy: original.policy,
            disconnectionFault: original.disconnectionFault,
            thermalFault: original.thermalFault,
            disconnectionOperatingTimeS: 0.001,
            thermalOperatingTimeS: original.thermalOperatingTimeS,
            faultEnergyA2s: original.faultEnergyA2s,
            thermalCapacityA2s: original.thermalCapacityA2s,
            upstreamConsistencyStatus: original.upstreamConsistencyStatus,
            disconnectionStatus: original.disconnectionStatus,
            thermalStatus: original.thermalStatus,
            reasons: original.reasons,
          ),
        ],
      );
      expect(tampered.isFullyClosed, isTrue);

      expect(
        () => ApartmentShortCircuitClosureEvidenceService.apply(
          requirements: _requirementsAfterD3(),
          request: fixture.request,
          closure: tampered,
        ),
        throwsArgumentError,
      );
    });

    test('Q38 incomplete D4 closure cannot publish projection evidence', () {
      final fixture = _fixture(requiredMaxDisconnectionTimeS: 0.05);
      expect(fixture.closure.isFullyClosed, isFalse);

      expect(
        () => ApartmentShortCircuitClosureEvidenceService.apply(
          requirements: _requirementsAfterD3(),
          request: fixture.request,
          closure: fixture.closure,
        ),
        throwsArgumentError,
      );
    });

    test('Q39 D4 cannot bypass missing D3 overload evidence', () {
      final fixture = _fixture();
      final requirements = _requirementsAfterD3(includeOverload: false);

      expect(
        () => ApartmentShortCircuitClosureEvidenceService.apply(
          requirements: requirements,
          request: fixture.request,
          closure: fixture.closure,
        ),
        throwsArgumentError,
      );
    });

    test('Q40 D4 cannot bypass missing D3 conductor evidence', () {
      final fixture = _fixture();
      final requirements = _requirementsAfterD3(includeConductor: false);

      expect(
        () => ApartmentShortCircuitClosureEvidenceService.apply(
          requirements: requirements,
          request: fixture.request,
          closure: fixture.closure,
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

_D4EvidenceFixture _fixture({double requiredMaxDisconnectionTimeS = 0.4}) {
  final d3Closure = _d3Closure();
  final policy = ElectricalShortCircuitClosurePolicy(
    circuitId: 'circuit-001',
    disconnectionFaultCase: _faultCase('minimum-disconnection', 0.04),
    thermalFaultCase: _faultCase('maximum-thermal', 0.02),
    requiredMaxDisconnectionTimeS: requiredMaxDisconnectionTimeS,
    timeCurrentEvidence: ProtectiveDeviceTimeCurrentEvidence(
      deviceId: _c16.id,
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
      sourceId: 'thermal-coefficient-registry',
      sourceRevision: '2026.1',
    ),
    sourceId: 'd4-policy',
    sourceRevision: '2026.1',
  );
  final request = ElectricalShortCircuitClosureRequest(
    d3Closure: d3Closure,
    policies: [policy],
  );
  return _D4EvidenceFixture(
    request: request,
    closure: ElectricalShortCircuitClosureEngine.close(request),
  );
}

FaultLoopCaseEvidence _faultCase(String id, double sourceResistanceOhm) =>
    FaultLoopCaseEvidence(
      id: id,
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

ElectricalCircuitClosureResult _d3Closure() {
  final request = ElectricalCircuitClosureRequest(
    calculation: _calculation(),
    policies: [
      ElectricalCircuitClosurePolicy(
        circuitId: 'circuit-001',
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
        protectionCandidates: const [_c16],
        allowedProtectionKinds: const {OvercurrentDeviceKind.mcb},
        minimumProtectionPoleCount: 1,
        sourceId: 'closure-policy',
        sourceRevision: 'r1',
      ),
    ],
  );
  return ElectricalCircuitClosureEngine.close(request);
}

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

ApartmentEngineeringDesignRequirements _requirementsAfterD3({
  bool includeOverload = true,
  bool includeConductor = true,
}) =>
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
        _unresolved(
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
        _unresolved(
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
          rationaleCode: 'qualification.circuit-d3',
          requiredFactKeys: const [
            'circuit.conductorConstraints',
            'circuit.definition',
            'circuit.installationMethod',
            'circuit.loadAssignments',
          ],
          factEvidence: [
            _fact('circuit.definition'),
            _fact('circuit.loadAssignments'),
            if (includeConductor) _fact('circuit.conductorConstraints'),
          ],
        ),
        ApartmentEngineeringRequirement(
          requirementId: 'req-protection',
          domain: ApartmentEngineeringRequirementDomain.protection,
          subjectKind: ApartmentEngineeringRequirementSubjectKind.projection,
          subjectStableId: 'projection-fp',
          evidenceState:
              ApartmentEngineeringRequirementEvidenceState.indeterminate,
          criticality:
              ApartmentEngineeringRequirementCriticality.safetyCritical,
          rationaleCode: 'qualification.protection-d3',
          requiredFactKeys: const [
            'protection.disconnection',
            'protection.overload',
            'protection.residualCurrent',
            'protection.shortCircuit',
          ],
          factEvidence: [
            if (includeOverload) _fact('protection.overload'),
          ],
        ),
      ],
    );

ApartmentEngineeringFactEvidence _fact(String key) =>
    ApartmentEngineeringFactEvidence(
      factKey: key,
      valueKind: ApartmentEngineeringFactValueKind.text,
      value: 'qualification-$key',
      unit: ApartmentEngineeringFactUnit.code,
      sourceId: 'qualification',
      sourceRevision: 'r1',
    );

ApartmentEngineeringRequirement _unresolved({
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

final class _D4EvidenceFixture {
  const _D4EvidenceFixture({required this.request, required this.closure});

  final ElectricalShortCircuitClosureRequest request;
  final ElectricalShortCircuitClosureResult closure;
}
