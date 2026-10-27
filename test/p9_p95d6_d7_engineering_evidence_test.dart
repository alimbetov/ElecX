import 'package:elecx/src/application/project/wizard/apartment/apartment_circuit_closure_evidence.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_circuit_installation_method_evidence.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_engineering_final_gate.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_engineering_requirements.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_protection_coordination_evidence.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_residual_current_closure_evidence.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_short_circuit_closure_evidence.dart';
import 'package:elecx/src/domain/cable_spec.dart';
import 'package:elecx/src/domain/circuit_installation_method.dart';
import 'package:elecx/src/domain/electrical_circuit_calculation.dart';
import 'package:elecx/src/domain/electrical_circuit_synthesis.dart';
import 'package:elecx/src/domain/electrical_load_calculation.dart';
import 'package:elecx/src/domain/overcurrent_protection.dart';
import 'package:elecx/src/domain/protective_device_coordination.dart';
import 'package:elecx/src/domain/residual_current_protection.dart';
import 'package:elecx/src/domain/route_medium.dart';
import 'package:elecx/src/engine/cable_sizing_engine.dart';
import 'package:elecx/src/engine/circuit_installation_method_closure_engine.dart';
import 'package:elecx/src/engine/electrical_circuit_calculation_engine.dart';
import 'package:elecx/src/engine/electrical_circuit_closure_engine.dart';
import 'package:elecx/src/engine/electrical_short_circuit_closure_engine.dart';
import 'package:elecx/src/engine/protective_device_coordination_engine.dart';
import 'package:elecx/src/engine/residual_current_protection_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P9.5-D6/D7 evidence closure', () {
    test('Q76 D6 publishes coordination and closes protection only', () {
      final fixture = _fixture();
      final protection = _requirement(
        fixture.requirementsAfterD6,
        ApartmentEngineeringRequirementDomain.protection,
      );
      final circuit = _requirement(
        fixture.requirementsAfterD6,
        ApartmentEngineeringRequirementDomain.circuit,
      );

      expect(
        fixture.requirementsAfterD6.requirementsVersion,
        apartmentEngineeringRequirementsVersionV5,
      );
      expect(protection.isResolved, isTrue);
      expect(protection.factEvidence, contains('protection.coordination'));
      expect(
        protection.factEvidence['protection.coordination']!.value,
        contains('sel-total'),
      );
      expect(circuit.isResolved, isFalse);
      expect(
        circuit.factEvidence,
        isNot(contains('circuit.installationMethod')),
      );
      expect(
        fixture.requirementsAfterD6.readyForEquipmentConfiguration,
        isFalse,
      );
    });

    test('Q77 stale D5 residual lineage is rejected by D6 binder', () {
      final fixture = _fixture(buildD6Evidence: false);
      final stale = _replaceFactRevision(
        fixture.requirementsAfterD5,
        ApartmentEngineeringRequirementDomain.protection,
        'protection.residualCurrent',
        'stale-d5-revision',
      );

      expect(
        () => ApartmentProtectionCoordinationEvidenceService.apply(
          requirements: stale,
          request: fixture.d6Request,
          closure: fixture.d6Closure,
        ),
        throwsArgumentError,
      );
    });

    test('Q78 tampered D6 selected evidence is rejected by recomputation', () {
      final fixture = _fixture(
        buildD6Evidence: false,
        twoCoordinationEvidence: true,
      );
      final original = fixture.d6Closure.outcomes.single;
      final alternate = original.policy.selectivityEvidence.singleWhere(
        (item) => item.id != original.selectedEvidence!.id,
      );
      final tampered = ElectricalProtectionCoordinationClosureResult(
        outcomes: [
          ElectricalProtectionCoordinationClosureOutcome(
            d5Outcome: original.d5Outcome,
            policy: original.policy,
            evaluations: original.evaluations,
            selectedEvidence: alternate,
            status: ProtectiveDeviceCoordinationClosureStatus
                .closedRequiredWithEvidence,
          ),
        ],
      );

      expect(
        () => ApartmentProtectionCoordinationEvidenceService.apply(
          requirements: fixture.requirementsAfterD5,
          request: fixture.d6Request,
          closure: tampered,
        ),
        throwsArgumentError,
      );
    });

    test('Q79 D7 installation method closes exact circuit and final gate', () {
      final fixture = _fixture();
      final circuit = _requirement(
        fixture.requirementsAfterD7,
        ApartmentEngineeringRequirementDomain.circuit,
      );
      final installation =
          circuit.factEvidence['circuit.installationMethod']!;
      final gate = ApartmentEngineeringFinalGateService.evaluate(
        fixture.requirementsAfterD7,
      );

      expect(
        fixture.requirementsAfterD7.requirementsVersion,
        apartmentEngineeringRequirementsVersionV6,
      );
      expect(circuit.isResolved, isTrue);
      expect(installation.value, contains('reference-method-B2'));
      expect(installation.value, contains('ampacity-table'));
      expect(fixture.requirementsAfterD7.readyForEquipmentConfiguration, isTrue);
      expect(gate.accepted, isTrue);
      expect(gate.blockerCodes, isEmpty);
    });

    test('Q80 D7 rejects installation evidence bound to another ampacity source',
        () {
      final fixture = _fixture(buildD7Evidence: false);

      expect(
        () => ElectricalCircuitInstallationMethodClosureRequest(
          d6Closure: fixture.d6Closure,
          policies: [
            CircuitInstallationMethodPolicy(
              circuitId: 'circuit-001',
              cableId: 'cable-2.5',
              sections: [
                CircuitInstallationSectionMethodEvidence(
                  sectionId: 'wall',
                  installationMethodId: 'reference-method-B2',
                  ampacitySourceKey: 'different-ampacity-table',
                  sourceId: 'installation-method-registry',
                  sourceRevision: '2026.1',
                ),
              ],
              sourceId: 'installation-policy',
              sourceRevision: '2026.1',
            ),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('Q81 final gate refuses D6 state while installation remains unresolved',
        () {
      final fixture = _fixture(buildD7Evidence: false);
      final gate = ApartmentEngineeringFinalGateService.evaluate(
        fixture.requirementsAfterD6,
      );

      expect(gate.accepted, isFalse);
      expect(gate.blockerCodes, contains('requirements-version-not-final'));
      expect(
        gate.blockerCodes,
        contains('installation-method-evidence-missing'),
      );
      expect(
        gate.blockerCodes,
        contains('requirements-not-ready-for-equipment-configuration'),
      );
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

_EngineeringEvidenceFixture _fixture({
  bool buildD6Evidence = true,
  bool buildD7Evidence = true,
  bool twoCoordinationEvidence = false,
}) {
  final d3Request = _d3Request();
  final d3Closure = ElectricalCircuitClosureEngine.close(d3Request);
  final afterD3 = ApartmentCircuitClosureEvidenceService.apply(
    requirements: _baseRequirements(),
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
    policies: [
      ResidualCurrentProtectionPolicy(
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
      ),
    ],
  );
  final d5Closure = ResidualCurrentProtectionEngine.close(d5Request);
  final afterD5 = ApartmentResidualCurrentClosureEvidenceService.apply(
    requirements: afterD4,
    request: d5Request,
    closure: d5Closure,
  );

  final selectivityEvidence = <ProtectiveDeviceSelectivityEvidence>[
    _coordinationEvidence('sel-total', ProtectiveDeviceSelectivityKind.total),
    if (twoCoordinationEvidence)
      _coordinationEvidence(
        'sel-limited-6ka',
        ProtectiveDeviceSelectivityKind.limited,
        limitA: 6000,
      ),
  ];
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
        selectivityEvidence: selectivityEvidence,
        sourceId: 'coordination-policy',
        sourceRevision: '2026.1',
      ),
    ],
  );
  final d6Closure = ProtectiveDeviceCoordinationEngine.close(d6Request);
  final afterD6 = buildD6Evidence
      ? ApartmentProtectionCoordinationEvidenceService.apply(
          requirements: afterD5,
          request: d6Request,
          closure: d6Closure,
        )
      : afterD5;

  if (!buildD6Evidence || !buildD7Evidence) {
    return _EngineeringEvidenceFixture(
      requirementsAfterD5: afterD5,
      requirementsAfterD6: afterD6,
      requirementsAfterD7: afterD6,
      d6Request: d6Request,
      d6Closure: d6Closure,
    );
  }

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
            sourceRevision: '2026.1',
          ),
        ],
        sourceId: 'installation-policy',
        sourceRevision: '2026.1',
      ),
    ],
  );
  final d7Closure = CircuitInstallationMethodClosureEngine.close(d7Request);
  final afterD7 = ApartmentCircuitInstallationMethodEvidenceService.apply(
    requirements: afterD6,
    request: d7Request,
    closure: d7Closure,
  );

  return _EngineeringEvidenceFixture(
    requirementsAfterD5: afterD5,
    requirementsAfterD6: afterD6,
    requirementsAfterD7: afterD7,
    d6Request: d6Request,
    d6Closure: d6Closure,
  );
}

ProtectiveDeviceSelectivityEvidence _coordinationEvidence(
  String id,
  ProtectiveDeviceSelectivityKind kind, {
  double? limitA,
}) =>
    ProtectiveDeviceSelectivityEvidence(
      id: id,
      downstreamDeviceId: _mcb16.id,
      upstreamDeviceId: _upstream.id,
      kind: kind,
      selectivityLimitA: limitA,
      sourceId: 'manufacturer-selectivity-table',
      sourceRevision: '2026.1',
    );

ElectricalCircuitClosureRequest _d3Request() =>
    ElectricalCircuitClosureRequest(
      calculation: _calculation(),
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
        ApartmentEngineeringRequirement(
          requirementId: 'req-protection',
          domain: ApartmentEngineeringRequirementDomain.protection,
          subjectKind: ApartmentEngineeringRequirementSubjectKind.projection,
          subjectStableId: 'projection-fp',
          evidenceState:
              ApartmentEngineeringRequirementEvidenceState.notEvaluated,
          criticality:
              ApartmentEngineeringRequirementCriticality.safetyCritical,
          rationaleCode: 'qualification.protection',
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
      factEvidence: [for (final key in facts) _fact(key, 'qualification-value')],
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

ApartmentEngineeringRequirement _requirement(
  ApartmentEngineeringDesignRequirements requirements,
  ApartmentEngineeringRequirementDomain domain,
) =>
    requirements.requirements.singleWhere((item) => item.domain == domain);

ApartmentEngineeringDesignRequirements _replaceFactRevision(
  ApartmentEngineeringDesignRequirements requirements,
  ApartmentEngineeringRequirementDomain domain,
  String factKey,
  String revision,
) {
  final currentRequirement = _requirement(requirements, domain);
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

final class _EngineeringEvidenceFixture {
  const _EngineeringEvidenceFixture({
    required this.requirementsAfterD5,
    required this.requirementsAfterD6,
    required this.requirementsAfterD7,
    required this.d6Request,
    required this.d6Closure,
  });

  final ApartmentEngineeringDesignRequirements requirementsAfterD5;
  final ApartmentEngineeringDesignRequirements requirementsAfterD6;
  final ApartmentEngineeringDesignRequirements requirementsAfterD7;
  final ElectricalProtectionCoordinationClosureRequest d6Request;
  final ElectricalProtectionCoordinationClosureResult d6Closure;
}
