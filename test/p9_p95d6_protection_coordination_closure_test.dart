import 'package:elecx/src/domain/cable_spec.dart';
import 'package:elecx/src/domain/electrical_circuit_calculation.dart';
import 'package:elecx/src/domain/electrical_circuit_synthesis.dart';
import 'package:elecx/src/domain/electrical_load_calculation.dart';
import 'package:elecx/src/domain/overcurrent_protection.dart';
import 'package:elecx/src/domain/protective_device_coordination.dart';
import 'package:elecx/src/domain/residual_current_protection.dart';
import 'package:elecx/src/domain/route_medium.dart';
import 'package:elecx/src/engine/cable_sizing_engine.dart';
import 'package:elecx/src/engine/electrical_circuit_calculation_engine.dart';
import 'package:elecx/src/engine/electrical_circuit_closure_engine.dart';
import 'package:elecx/src/engine/electrical_short_circuit_closure_engine.dart';
import 'package:elecx/src/engine/protective_device_coordination_engine.dart';
import 'package:elecx/src/engine/residual_current_protection_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P9.5-D6 protection coordination closure', () {
    test('Q68 total-selectivity manufacturer evidence closes exact pair', () {
      final request = ElectricalProtectionCoordinationClosureRequest(
        d5Closure: _d5Closure(),
        policies: [
          _requiredCoordinationPolicy(
            evidence: [_totalEvidence(id: 'sel-total')],
          ),
        ],
      );

      final outcome =
          ProtectiveDeviceCoordinationEngine.close(request).outcomes.single;

      expect(
        outcome.status,
        ProtectiveDeviceCoordinationClosureStatus.closedRequiredWithEvidence,
      );
      expect(outcome.selectedEvidence!.id, 'sel-total');
      expect(
        outcome.selectedEvidence!.kind,
        ProtectiveDeviceSelectivityKind.total,
      );
    });

    test('Q69 limited selectivity closes only when limit covers D3 Ik', () {
      final request = ElectricalProtectionCoordinationClosureRequest(
        d5Closure: _d5Closure(),
        policies: [
          _requiredCoordinationPolicy(
            evidence: [_limitedEvidence(id: 'sel-4ka', limitA: 4000)],
          ),
        ],
      );

      final outcome =
          ProtectiveDeviceCoordinationEngine.close(request).outcomes.single;

      expect(outcome.isClosed, isTrue);
      expect(outcome.selectedEvidence!.selectivityLimitA, 4000);
    });

    test('Q70 selectivity limit below prospective fault current fails closed',
        () {
      final request = ElectricalProtectionCoordinationClosureRequest(
        d5Closure: _d5Closure(),
        policies: [
          _requiredCoordinationPolicy(
            evidence: [_limitedEvidence(id: 'sel-2ka', limitA: 2000)],
          ),
        ],
      );

      final outcome =
          ProtectiveDeviceCoordinationEngine.close(request).outcomes.single;

      expect(
        outcome.status,
        ProtectiveDeviceCoordinationClosureStatus.noCompliantEvidence,
      );
      expect(outcome.selectedEvidence, isNull);
      expect(
        outcome.evaluations.single.rejections,
        contains('selectivity-limit-below-prospective-short-circuit-current'),
      );
    });

    test('Q71 stale downstream-device policy cannot be replayed', () {
      expect(
        () => ElectricalProtectionCoordinationClosureRequest(
          d5Closure: _d5Closure(),
          policies: [
            ProtectiveDeviceCoordinationPolicy(
              circuitId: 'circuit-001',
              applicability: ProtectiveDeviceCoordinationApplicability.required,
              rationaleCode: 'qualification.coordination-required',
              evaluatedDownstreamDeviceId: 'different-device',
              applicabilityEvidenceIds: const ['coordination-rule'],
              upstreamDevice: _upstream,
              selectivityEvidence: [_totalEvidence(id: 'sel-total')],
              sourceId: 'coordination-policy',
              sourceRevision: '2026.1',
            ),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('Q72 manufacturer evidence for a different pair is rejected', () {
      final request = ElectricalProtectionCoordinationClosureRequest(
        d5Closure: _d5Closure(),
        policies: [
          _requiredCoordinationPolicy(
            evidence: [
              ProtectiveDeviceSelectivityEvidence(
                id: 'wrong-pair',
                downstreamDeviceId: _mcb16.id,
                upstreamDeviceId: 'different-upstream',
                kind: ProtectiveDeviceSelectivityKind.total,
                selectivityLimitA: null,
                sourceId: 'manufacturer-table',
                sourceRevision: '2026.1',
              ),
            ],
          ),
        ],
      );

      final outcome =
          ProtectiveDeviceCoordinationEngine.close(request).outcomes.single;

      expect(outcome.isClosed, isFalse);
      expect(
        outcome.evaluations.single.rejections,
        contains('coordination-upstream-device-mismatch'),
      );
    });

    test('Q73 explicit not-required coordination closes without pair evidence',
        () {
      final request = ElectricalProtectionCoordinationClosureRequest(
        d5Closure: _d5Closure(),
        policies: [
          ProtectiveDeviceCoordinationPolicy(
            circuitId: 'circuit-001',
            applicability:
                ProtectiveDeviceCoordinationApplicability.notRequired,
            rationaleCode: 'qualification.coordination-not-required',
            evaluatedDownstreamDeviceId: _mcb16.id,
            applicabilityEvidenceIds: const ['coordination-not-required-rule'],
            upstreamDevice: null,
            selectivityEvidence: const [],
            sourceId: 'coordination-policy',
            sourceRevision: '2026.1',
          ),
        ],
      );

      final outcome =
          ProtectiveDeviceCoordinationEngine.close(request).outcomes.single;

      expect(
        outcome.status,
        ProtectiveDeviceCoordinationClosureStatus.closedNotRequired,
      );
      expect(outcome.selectedEvidence, isNull);
    });

    test('Q74 deterministic evidence selection prefers total selectivity', () {
      final evidence = [
        _limitedEvidence(id: 'z-limited', limitA: 6000),
        _totalEvidence(id: 'a-total'),
      ];
      final forward = ProtectiveDeviceCoordinationEngine.close(
        ElectricalProtectionCoordinationClosureRequest(
          d5Closure: _d5Closure(),
          policies: [_requiredCoordinationPolicy(evidence: evidence)],
        ),
      ).outcomes.single.selectedEvidence;
      final reverse = ProtectiveDeviceCoordinationEngine.close(
        ElectricalProtectionCoordinationClosureRequest(
          d5Closure: _d5Closure(),
          policies: [
            _requiredCoordinationPolicy(evidence: evidence.reversed.toList()),
          ],
        ),
      ).outcomes.single.selectedEvidence;

      expect(forward!.id, 'a-total');
      expect(reverse!.id, 'a-total');
    });

    test('Q75 malformed limited-selectivity evidence is rejected', () {
      expect(
        () => ProtectiveDeviceSelectivityEvidence(
          id: 'bad',
          downstreamDeviceId: _mcb16.id,
          upstreamDeviceId: _upstream.id,
          kind: ProtectiveDeviceSelectivityKind.limited,
          selectivityLimitA: null,
          sourceId: 'manufacturer-table',
          sourceRevision: '2026.1',
        ),
        throwsArgumentError,
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

ProtectiveDeviceCoordinationPolicy _requiredCoordinationPolicy({
  required List<ProtectiveDeviceSelectivityEvidence> evidence,
}) =>
    ProtectiveDeviceCoordinationPolicy(
      circuitId: 'circuit-001',
      applicability: ProtectiveDeviceCoordinationApplicability.required,
      rationaleCode: 'qualification.coordination-required',
      evaluatedDownstreamDeviceId: _mcb16.id,
      applicabilityEvidenceIds: const ['coordination-rule'],
      upstreamDevice: _upstream,
      selectivityEvidence: evidence,
      sourceId: 'coordination-policy',
      sourceRevision: '2026.1',
    );

ProtectiveDeviceSelectivityEvidence _totalEvidence({required String id}) =>
    ProtectiveDeviceSelectivityEvidence(
      id: id,
      downstreamDeviceId: _mcb16.id,
      upstreamDeviceId: _upstream.id,
      kind: ProtectiveDeviceSelectivityKind.total,
      selectivityLimitA: null,
      sourceId: 'manufacturer-table',
      sourceRevision: '2026.1',
    );

ProtectiveDeviceSelectivityEvidence _limitedEvidence({
  required String id,
  required double limitA,
}) =>
    ProtectiveDeviceSelectivityEvidence(
      id: id,
      downstreamDeviceId: _mcb16.id,
      upstreamDeviceId: _upstream.id,
      kind: ProtectiveDeviceSelectivityKind.limited,
      selectivityLimitA: limitA,
      sourceId: 'manufacturer-table',
      sourceRevision: '2026.1',
    );

ElectricalResidualCurrentClosureResult _d5Closure() {
  final d4 = _d4Closure();
  final request = ElectricalResidualCurrentClosureRequest(
    d4Closure: d4,
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
        sourceId: 'qualification-rccd-policy',
        sourceRevision: '2026.1',
      ),
    ],
  );
  final d5 = ResidualCurrentProtectionEngine.close(request);
  if (!d5.isFullyClosed) {
    throw StateError('D6 fixture requires fully closed D5.');
  }
  return d5;
}

ElectricalShortCircuitClosureResult _d4Closure() {
  final d3Request = ElectricalCircuitClosureRequest(
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
  final d3 = ElectricalCircuitClosureEngine.close(d3Request);

  final d4Request = ElectricalShortCircuitClosureRequest(
    d3Closure: d3,
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
  final d4 = ElectricalShortCircuitClosureEngine.close(d4Request);
  if (!d4.isFullyClosed) {
    throw StateError('D6 fixture requires fully closed D4.');
  }
  return d4;
}

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
          sourceId: 'qualification-circuit-policy',
          sourceRevision: 'r1',
        ),
      ],
    ),
  );
}
