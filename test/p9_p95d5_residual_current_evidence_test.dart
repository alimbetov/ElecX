import 'package:elecx/src/application/project/wizard/apartment/apartment_circuit_closure_evidence.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_engineering_requirements.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_residual_current_closure_evidence.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_short_circuit_closure_evidence.dart';
import 'package:elecx/src/domain/cable_spec.dart';
import 'package:elecx/src/domain/electrical_circuit_calculation.dart';
import 'package:elecx/src/domain/electrical_circuit_synthesis.dart';
import 'package:elecx/src/domain/electrical_load_calculation.dart';
import 'package:elecx/src/domain/overcurrent_protection.dart';
import 'package:elecx/src/domain/residual_current_protection.dart';
import 'package:elecx/src/domain/route_medium.dart';
import 'package:elecx/src/engine/cable_sizing_engine.dart';
import 'package:elecx/src/engine/electrical_circuit_calculation_engine.dart';
import 'package:elecx/src/engine/electrical_circuit_closure_engine.dart';
import 'package:elecx/src/engine/electrical_short_circuit_closure_engine.dart';
import 'package:elecx/src/engine/residual_current_protection_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P9.5-D5 residual-current evidence', () {
    test(
        'Q62 publishes residual-current evidence and keeps coordination blocking',
        () {
      final fixture = _fixture();
      final updated = ApartmentResidualCurrentClosureEvidenceService.apply(
        requirements: fixture.requirementsAfterD4,
        request: fixture.d5Request,
        closure: fixture.d5Closure,
      );
      final protection = _protection(updated);
      final residual = protection.factEvidence['protection.residualCurrent']!;

      expect(
        updated.requirementsVersion,
        apartmentEngineeringRequirementsVersionV4,
      );
      expect(
        protection.requiredFactKeys,
        containsAll([
          'protection.overload',
          'protection.shortCircuit',
          'protection.disconnection',
          'protection.residualCurrent',
          'protection.coordination',
        ]),
      );
      expect(protection.factEvidence, contains('protection.residualCurrent'));
      expect(residual.value, contains('evaluatedLoadIds'));
      expect(residual.value, contains('load-a'));
      expect(
          protection.factEvidence, isNot(contains('protection.coordination')));
      expect(
        protection.evidenceState,
        ApartmentEngineeringRequirementEvidenceState.indeterminate,
      );
      expect(protection.blocksEquipmentConfiguration, isTrue);
      expect(updated.readyForEquipmentConfiguration, isFalse);
    });

    test('Q63 stale D4 provenance cannot be rebound into D5 evidence', () {
      final fixture = _fixture();
      final stale = _replaceProtectionFact(
        fixture.requirementsAfterD4,
        'protection.shortCircuit',
        sourceRevision: 'stale-d4-revision',
      );

      expect(
        () => ApartmentResidualCurrentClosureEvidenceService.apply(
          requirements: stale,
          request: fixture.d5Request,
          closure: fixture.d5Closure,
        ),
        throwsArgumentError,
      );
    });

    test('Q64 tampered D5 selected device is rejected by recomputation binding',
        () {
      final fixture = _fixture(twoCandidates: true);
      final original = fixture.d5Closure.outcomes.single;
      final other = original.policy.candidates.singleWhere(
        (candidate) => candidate.id != original.selectedDevice!.id,
      );
      final tampered = ElectricalResidualCurrentClosureResult(
        outcomes: [
          ElectricalResidualCurrentClosureOutcome(
            d4Outcome: original.d4Outcome,
            policy: original.policy,
            evaluations: original.evaluations,
            selectedDevice: other,
            status: ResidualCurrentClosureStatus.closedRequiredWithDevice,
          ),
        ],
      );

      expect(
        () => ApartmentResidualCurrentClosureEvidenceService.apply(
          requirements: fixture.requirementsAfterD4,
          request: fixture.d5Request,
          closure: tampered,
        ),
        throwsArgumentError,
      );
    });

    test('Q65 incomplete D5 closure cannot publish projection evidence', () {
      final fixture = _fixture(nonCompliantOnly: true);
      expect(fixture.d5Closure.isFullyClosed, isFalse);

      expect(
        () => ApartmentResidualCurrentClosureEvidenceService.apply(
          requirements: fixture.requirementsAfterD4,
          request: fixture.d5Request,
          closure: fixture.d5Closure,
        ),
        throwsArgumentError,
      );
    });

    test('Q66 explicit not-required policy is evidenced, not silently omitted',
        () {
      final fixture = _fixture(notRequired: true);
      final updated = ApartmentResidualCurrentClosureEvidenceService.apply(
        requirements: fixture.requirementsAfterD4,
        request: fixture.d5Request,
        closure: fixture.d5Closure,
      );
      final protection = _protection(updated);
      final evidence = protection.factEvidence['protection.residualCurrent']!;

      expect(evidence.value, contains('notRequired'));
      expect(evidence.value, contains('evaluatedLoadIds'));
      expect(evidence.value, contains('load-a'));
      expect(protection.requiredFactKeys, contains('protection.coordination'));
      expect(protection.blocksEquipmentConfiguration, isTrue);
    });

    test('Q67 D5 migration rejects an already-upgraded or unknown schema', () {
      final fixture = _fixture();
      final alreadyV4 = ApartmentEngineeringDesignRequirements(
        requirementsVersion: apartmentEngineeringRequirementsVersionV4,
        selectedCandidateFingerprint:
            fixture.requirementsAfterD4.selectedCandidateFingerprint,
        projectionFingerprint:
            fixture.requirementsAfterD4.projectionFingerprint,
        graphFingerprint: fixture.requirementsAfterD4.graphFingerprint,
        placementFingerprint: fixture.requirementsAfterD4.placementFingerprint,
        normativeEvidenceFingerprint:
            fixture.requirementsAfterD4.normativeEvidenceFingerprint,
        normativeProfileId: fixture.requirementsAfterD4.normativeProfileId,
        normativeProfileVersion:
            fixture.requirementsAfterD4.normativeProfileVersion,
        requirements: fixture.requirementsAfterD4.requirements,
      );

      expect(
        () => ApartmentResidualCurrentClosureEvidenceService.apply(
          requirements: alreadyV4,
          request: fixture.d5Request,
          closure: fixture.d5Closure,
        ),
        throwsArgumentError,
      );
    });
  });
}

const _mcb16Id = 'mcb-c16-6ka';

const _mcb16 = OvercurrentProtectiveDeviceSpec(
  id: _mcb16Id,
  kind: OvercurrentDeviceKind.mcb,
  ratedCurrentA: 16,
  breakingCapacityKa: 6,
  poleCount: 1,
  tripCurve: OvercurrentTripCurve.c,
  sourceId: 'device-catalog',
  sourceRevision: 'r1',
);

_D5EvidenceFixture _fixture({
  bool twoCandidates = false,
  bool nonCompliantOnly = false,
  bool notRequired = false,
}) {
  final d3Request = _d3Request();
  final d3Closure = ElectricalCircuitClosureEngine.close(d3Request);
  final d4Request = _d4Request(d3Closure);
  final d4Closure = ElectricalShortCircuitClosureEngine.close(d4Request);

  final afterD3 = ApartmentCircuitClosureEvidenceService.apply(
    requirements: _baseRequirements(),
    request: d3Request,
    closure: d3Closure,
  );
  final afterD4 = ApartmentShortCircuitClosureEvidenceService.apply(
    requirements: afterD3,
    request: d4Request,
    closure: d4Closure,
  );

  final candidates = <ResidualCurrentProtectiveDeviceSpec>[
    if (!nonCompliantOnly) _rcd(id: 'rcd-a-30', residualOperatingCurrentMa: 30),
    if (twoCandidates) _rcd(id: 'rcd-a-25', residualOperatingCurrentMa: 25),
    if (nonCompliantOnly)
      _rcd(id: 'rcd-a-100', residualOperatingCurrentMa: 100),
  ];
  final policy = notRequired
      ? ResidualCurrentProtectionPolicy(
          circuitId: 'circuit-001',
          applicability: ResidualCurrentApplicability.notRequired,
          rationaleCode: 'qualification.not-required',
          evaluatedLoadIds: const ['load-a'],
          applicabilityEvidenceIds: const ['norm-not-required'],
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
        )
      : ResidualCurrentProtectionPolicy(
          circuitId: 'circuit-001',
          applicability: ResidualCurrentApplicability.required,
          rationaleCode: 'qualification.required',
          evaluatedLoadIds: const ['load-a'],
          applicabilityEvidenceIds: const ['norm-required'],
          loadCharacteristicEvidenceIds: const ['load-characteristic'],
          maximumResidualOperatingCurrentMa: 30,
          allowedTypes: const {ResidualCurrentType.a},
          preferredTypes: const [ResidualCurrentType.a],
          allowedDeviceKinds: const {ResidualCurrentDeviceKind.rcd},
          preferredDeviceKinds: const [ResidualCurrentDeviceKind.rcd],
          minimumPoleCount: 2,
          sensitivityPreference:
              ResidualCurrentSensitivityPreference.lowestAvailable,
          candidates: candidates,
          sourceId: 'residual-policy',
          sourceRevision: '2026.1',
        );
  final d5Request = ElectricalResidualCurrentClosureRequest(
    d4Closure: d4Closure,
    policies: [policy],
  );

  return _D5EvidenceFixture(
    requirementsAfterD4: afterD4,
    d5Request: d5Request,
    d5Closure: ResidualCurrentProtectionEngine.close(d5Request),
  );
}

ResidualCurrentProtectiveDeviceSpec _rcd({
  required String id,
  required double residualOperatingCurrentMa,
}) =>
    ResidualCurrentProtectiveDeviceSpec(
      id: id,
      kind: ResidualCurrentDeviceKind.rcd,
      ratedCurrentA: 25,
      residualOperatingCurrentMa: residualOperatingCurrentMa,
      residualType: ResidualCurrentType.a,
      poleCount: 2,
      overcurrentDeviceId: null,
      conditionalShortCircuitCurrentA: 6000,
      compatibleBackupOvercurrentDeviceIds: const [_mcb16Id],
      sourceId: 'residual-catalog',
      sourceRevision: '2026.1',
    );

ElectricalCircuitClosureRequest _d3Request() {
  final calculation = _calculation();
  return ElectricalCircuitClosureRequest(
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
}

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

CableSpec _cable() => CableSpec(
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
          sourceId: 'calculation-policy',
          sourceRevision: 'r1',
        ),
      ],
    ),
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
          rationaleCode: 'qualification.circuit-d2',
          requiredFactKeys: const [
            'circuit.conductorConstraints',
            'circuit.definition',
            'circuit.installationMethod',
            'circuit.loadAssignments',
          ],
          factEvidence: [
            _fact('circuit.definition', 'd2-definition'),
            _fact('circuit.loadAssignments', 'd2-load-assignments'),
          ],
        ),
        _unresolved(
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

ApartmentEngineeringFactEvidence _fact(String key, String value) =>
    ApartmentEngineeringFactEvidence(
      factKey: key,
      valueKind: ApartmentEngineeringFactValueKind.text,
      value: value,
      unit: ApartmentEngineeringFactUnit.code,
      sourceId: 'qualification',
      sourceRevision: 'r1',
    );

ApartmentEngineeringRequirement _protection(
  ApartmentEngineeringDesignRequirements requirements,
) =>
    requirements.requirements.singleWhere(
      (item) => item.domain == ApartmentEngineeringRequirementDomain.protection,
    );

ApartmentEngineeringDesignRequirements _replaceProtectionFact(
  ApartmentEngineeringDesignRequirements requirements,
  String factKey, {
  required String sourceRevision,
}) {
  final protection = _protection(requirements);
  final current = protection.factEvidence[factKey]!;
  final replacement = ApartmentEngineeringFactEvidence(
    factKey: current.factKey,
    valueKind: current.valueKind,
    value: current.value,
    unit: current.unit,
    sourceId: current.sourceId,
    sourceRevision: sourceRevision,
  );
  final updatedProtection = ApartmentEngineeringRequirement(
    requirementId: protection.requirementId,
    domain: protection.domain,
    subjectKind: protection.subjectKind,
    subjectStableId: protection.subjectStableId,
    evidenceState: protection.evidenceState,
    criticality: protection.criticality,
    rationaleCode: protection.rationaleCode,
    requiredFactKeys: protection.requiredFactKeys,
    factEvidence: [
      for (final evidence in protection.factEvidence.values)
        if (evidence.factKey != factKey) evidence,
      replacement,
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
        if (item.requirementId == protection.requirementId)
          updatedProtection
        else
          item,
    ],
  );
}

final class _D5EvidenceFixture {
  const _D5EvidenceFixture({
    required this.requirementsAfterD4,
    required this.d5Request,
    required this.d5Closure,
  });

  final ApartmentEngineeringDesignRequirements requirementsAfterD4;
  final ElectricalResidualCurrentClosureRequest d5Request;
  final ElectricalResidualCurrentClosureResult d5Closure;
}
