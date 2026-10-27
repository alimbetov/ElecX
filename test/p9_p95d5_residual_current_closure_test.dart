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
  group('P9.5-D5 RCD/RCBO normative closure', () {
    test('Q50 explicit required policy selects compliant Type A 30 mA RCD', () {
      final d4 = _d4Closure();
      final request = ElectricalResidualCurrentClosureRequest(
        d4Closure: d4,
        policies: [
          _requiredPolicy(
            maximumResidualOperatingCurrentMa: 30,
            allowedTypes: const {ResidualCurrentType.a},
            preferredTypes: const [ResidualCurrentType.a],
            candidates: [_rcd(id: 'rcd-a-30', type: ResidualCurrentType.a)],
          ),
        ],
      );

      final outcome = ResidualCurrentProtectionEngine.close(request).outcomes.single;

      expect(outcome.status, ResidualCurrentClosureStatus.closedRequiredWithDevice);
      expect(outcome.selectedDevice!.id, 'rcd-a-30');
      expect(outcome.selectedDevice!.residualType, ResidualCurrentType.a);
      expect(outcome.selectedDevice!.residualOperatingCurrentMa, 30);
    });

    test('Q51 explicit 100 mA Type AC policy proves no hidden 30 mA or Type A',
        () {
      final d4 = _d4Closure();
      final request = ElectricalResidualCurrentClosureRequest(
        d4Closure: d4,
        policies: [
          _requiredPolicy(
            maximumResidualOperatingCurrentMa: 100,
            allowedTypes: const {ResidualCurrentType.ac},
            preferredTypes: const [ResidualCurrentType.ac],
            sensitivityPreference:
                ResidualCurrentSensitivityPreference.highestPermitted,
            candidates: [
              _rcd(
                id: 'rcd-ac-30',
                type: ResidualCurrentType.ac,
                residualOperatingCurrentMa: 30,
              ),
              _rcd(
                id: 'rcd-ac-100',
                type: ResidualCurrentType.ac,
                residualOperatingCurrentMa: 100,
              ),
              _rcd(id: 'rcd-a-30', type: ResidualCurrentType.a),
            ],
          ),
        ],
      );

      final outcome = ResidualCurrentProtectionEngine.close(request).outcomes.single;

      expect(outcome.selectedDevice!.id, 'rcd-ac-100');
      expect(outcome.selectedDevice!.residualType, ResidualCurrentType.ac);
      expect(outcome.selectedDevice!.residualOperatingCurrentMa, 100);
      expect(
        outcome.evaluations
            .singleWhere((item) => item.candidate.id == 'rcd-a-30')
            .rejections,
        contains('residual-current-type-not-allowed'),
      );
    });

    test('Q52 Type B requirement selects B and rejects Type A', () {
      final request = ElectricalResidualCurrentClosureRequest(
        d4Closure: _d4Closure(),
        policies: [
          _requiredPolicy(
            maximumResidualOperatingCurrentMa: 30,
            allowedTypes: const {ResidualCurrentType.b},
            preferredTypes: const [ResidualCurrentType.b],
            candidates: [
              _rcd(id: 'rcd-a', type: ResidualCurrentType.a),
              _rcd(id: 'rcd-b', type: ResidualCurrentType.b),
            ],
          ),
        ],
      );

      final outcome = ResidualCurrentProtectionEngine.close(request).outcomes.single;

      expect(outcome.selectedDevice!.id, 'rcd-b');
      expect(
        outcome.evaluations
            .singleWhere((item) => item.candidate.id == 'rcd-a')
            .rejections,
        contains('residual-current-type-not-allowed'),
      );
    });

    test('Q53 explicit authoritative not-required policy closes without device',
        () {
      final request = ElectricalResidualCurrentClosureRequest(
        d4Closure: _d4Closure(),
        policies: [_notRequiredPolicy()],
      );

      final outcome = ResidualCurrentProtectionEngine.close(request).outcomes.single;

      expect(outcome.status, ResidualCurrentClosureStatus.closedNotRequired);
      expect(outcome.selectedDevice, isNull);
      expect(outcome.isClosed, isTrue);
    });

    test('Q54 every D4 circuit requires an explicit D5 policy', () {
      expect(
        () => ElectricalResidualCurrentClosureRequest(
          d4Closure: _d4Closure(),
          policies: const [],
        ),
        throwsArgumentError,
      );
    });

    test('Q55 device above explicit maximum I delta n is rejected', () {
      final request = ElectricalResidualCurrentClosureRequest(
        d4Closure: _d4Closure(),
        policies: [
          _requiredPolicy(
            maximumResidualOperatingCurrentMa: 30,
            candidates: [
              _rcd(
                id: 'rcd-a-100',
                type: ResidualCurrentType.a,
                residualOperatingCurrentMa: 100,
              ),
            ],
          ),
        ],
      );

      final outcome = ResidualCurrentProtectionEngine.close(request).outcomes.single;

      expect(outcome.status, ResidualCurrentClosureStatus.noCompliantDevice);
      expect(
        outcome.evaluations.single.rejections,
        contains('residual-operating-current-exceeds-policy-maximum'),
      );
    });

    test('Q56 standalone RCD In below D3 branch In is rejected', () {
      final request = ElectricalResidualCurrentClosureRequest(
        d4Closure: _d4Closure(),
        policies: [
          _requiredPolicy(
            candidates: [
              _rcd(
                id: 'rcd-10a',
                type: ResidualCurrentType.a,
                ratedCurrentA: 10,
              ),
            ],
          ),
        ],
      );

      final outcome = ResidualCurrentProtectionEngine.close(request).outcomes.single;

      expect(outcome.status, ResidualCurrentClosureStatus.noCompliantDevice);
      expect(
        outcome.evaluations.single.rejections,
        contains('rcd-rated-current-below-upstream-overcurrent-rating'),
      );
    });

    test('Q57 standalone RCD needs sufficient conditional SCC and backup match',
        () {
      final request = ElectricalResidualCurrentClosureRequest(
        d4Closure: _d4Closure(),
        policies: [
          _requiredPolicy(
            candidates: [
              _rcd(
                id: 'rcd-bad-coordination',
                type: ResidualCurrentType.a,
                conditionalShortCircuitCurrentA: 2000,
                compatibleBackupIds: const ['different-breaker'],
              ),
            ],
          ),
        ],
      );

      final outcome = ResidualCurrentProtectionEngine.close(request).outcomes.single;
      final reasons = outcome.evaluations.single.rejections;

      expect(
        reasons,
        contains('rcd-conditional-short-circuit-current-insufficient'),
      );
      expect(
        reasons,
        contains('rcd-backup-overcurrent-device-not-compatible'),
      );
      expect(outcome.isClosed, isFalse);
    });

    test('Q58 RCBO cannot silently replace D3 selected MCB', () {
      final request = ElectricalResidualCurrentClosureRequest(
        d4Closure: _d4Closure(),
        policies: [
          _requiredPolicy(
            allowedDeviceKinds: const {ResidualCurrentDeviceKind.rcbo},
            preferredDeviceKinds: const [ResidualCurrentDeviceKind.rcbo],
            candidates: [
              _rcbo(
                id: 'residual-rcbo-record',
                overcurrentDeviceId: _mcb16.id,
              ),
            ],
          ),
        ],
      );

      final outcome = ResidualCurrentProtectionEngine.close(request).outcomes.single;

      expect(outcome.status, ResidualCurrentClosureStatus.noCompliantDevice);
      expect(
        outcome.evaluations.single.rejections,
        contains('rcbo-cannot-replace-d3-selected-overcurrent-device'),
      );
    });

    test('Q59 RCBO residual evidence must bind exact D3 selected RCBO', () {
      final request = ElectricalResidualCurrentClosureRequest(
        d4Closure: _d4Closure(overcurrent: _rcbo16),
        policies: [
          _requiredPolicy(
            allowedDeviceKinds: const {ResidualCurrentDeviceKind.rcbo},
            preferredDeviceKinds: const [ResidualCurrentDeviceKind.rcbo],
            candidates: [
              _rcbo(
                id: 'rcbo-residual-profile',
                overcurrentDeviceId: _rcbo16.id,
              ),
            ],
          ),
        ],
      );

      final outcome = ResidualCurrentProtectionEngine.close(request).outcomes.single;

      expect(outcome.isClosed, isTrue);
      expect(outcome.selectedDevice!.kind, ResidualCurrentDeviceKind.rcbo);
      expect(outcome.selectedDevice!.overcurrentDeviceId, _rcbo16.id);
    });

    test('Q60 candidate order does not change deterministic D5 selection', () {
      final first = _rcd(id: 'rcd-z', type: ResidualCurrentType.a);
      final second = _rcd(id: 'rcd-a', type: ResidualCurrentType.a);
      final d4 = _d4Closure();

      String selected(List<ResidualCurrentProtectiveDeviceSpec> candidates) {
        final result = ResidualCurrentProtectionEngine.close(
          ElectricalResidualCurrentClosureRequest(
            d4Closure: d4,
            policies: [_requiredPolicy(candidates: candidates)],
          ),
        );
        return result.outcomes.single.selectedDevice!.id;
      }

      expect(selected([first, second]), 'rcd-a');
      expect(selected([second, first]), 'rcd-a');
    });

    test('Q61 malformed residual-current evidence is rejected at runtime', () {
      expect(
        () => ResidualCurrentProtectiveDeviceSpec(
          id: 'bad-device',
          kind: ResidualCurrentDeviceKind.rcd,
          ratedCurrentA: double.nan,
          residualOperatingCurrentMa: 30,
          residualType: ResidualCurrentType.a,
          poleCount: 2,
          overcurrentDeviceId: null,
          conditionalShortCircuitCurrentA: 6000,
          compatibleBackupOvercurrentDeviceIds: const [_mcb16Id],
          sourceId: 'catalog',
          sourceRevision: 'r1',
        ),
        throwsArgumentError,
      );

      expect(
        () => ResidualCurrentProtectionPolicy(
          circuitId: 'circuit-001',
          applicability: ResidualCurrentApplicability.required,
          rationaleCode: 'qualification.required',
          applicabilityEvidenceIds: const ['norm-rule'],
          loadCharacteristicEvidenceIds: const [],
          maximumResidualOperatingCurrentMa: 30,
          allowedTypes: const {ResidualCurrentType.a},
          preferredTypes: const [ResidualCurrentType.a],
          allowedDeviceKinds: const {ResidualCurrentDeviceKind.rcd},
          preferredDeviceKinds: const [ResidualCurrentDeviceKind.rcd],
          minimumPoleCount: 2,
          sensitivityPreference:
              ResidualCurrentSensitivityPreference.lowestAvailable,
          candidates: const [],
          sourceId: 'norm-profile',
          sourceRevision: 'r1',
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

const _rcbo16 = OvercurrentProtectiveDeviceSpec(
  id: 'rcbo-c16-6ka',
  kind: OvercurrentDeviceKind.rcbo,
  ratedCurrentA: 16,
  breakingCapacityKa: 6,
  poleCount: 2,
  tripCurve: OvercurrentTripCurve.c,
  sourceId: 'device-catalog',
  sourceRevision: 'r1',
);

ResidualCurrentProtectiveDeviceSpec _rcd({
  required String id,
  required ResidualCurrentType type,
  double ratedCurrentA = 25,
  double residualOperatingCurrentMa = 30,
  double conditionalShortCircuitCurrentA = 6000,
  List<String> compatibleBackupIds = const [_mcb16Id],
}) =>
    ResidualCurrentProtectiveDeviceSpec(
      id: id,
      kind: ResidualCurrentDeviceKind.rcd,
      ratedCurrentA: ratedCurrentA,
      residualOperatingCurrentMa: residualOperatingCurrentMa,
      residualType: type,
      poleCount: 2,
      overcurrentDeviceId: null,
      conditionalShortCircuitCurrentA: conditionalShortCircuitCurrentA,
      compatibleBackupOvercurrentDeviceIds: compatibleBackupIds,
      sourceId: 'residual-device-catalog',
      sourceRevision: '2026.1',
    );

ResidualCurrentProtectiveDeviceSpec _rcbo({
  required String id,
  required String overcurrentDeviceId,
}) =>
    ResidualCurrentProtectiveDeviceSpec(
      id: id,
      kind: ResidualCurrentDeviceKind.rcbo,
      ratedCurrentA: 16,
      residualOperatingCurrentMa: 30,
      residualType: ResidualCurrentType.a,
      poleCount: 2,
      overcurrentDeviceId: overcurrentDeviceId,
      conditionalShortCircuitCurrentA: null,
      compatibleBackupOvercurrentDeviceIds: const [],
      sourceId: 'residual-device-catalog',
      sourceRevision: '2026.1',
    );

ResidualCurrentProtectionPolicy _requiredPolicy({
  double maximumResidualOperatingCurrentMa = 30,
  Set<ResidualCurrentType> allowedTypes = const {ResidualCurrentType.a},
  List<ResidualCurrentType> preferredTypes = const [ResidualCurrentType.a],
  Set<ResidualCurrentDeviceKind> allowedDeviceKinds = const {
    ResidualCurrentDeviceKind.rcd,
  },
  List<ResidualCurrentDeviceKind> preferredDeviceKinds = const [
    ResidualCurrentDeviceKind.rcd,
  ],
  ResidualCurrentSensitivityPreference sensitivityPreference =
      ResidualCurrentSensitivityPreference.lowestAvailable,
  List<ResidualCurrentProtectiveDeviceSpec> candidates = const [],
}) =>
    ResidualCurrentProtectionPolicy(
      circuitId: 'circuit-001',
      applicability: ResidualCurrentApplicability.required,
      rationaleCode: 'qualification.rcd-required',
      applicabilityEvidenceIds: const ['norm-applicability-rule'],
      loadCharacteristicEvidenceIds: const ['load-characteristic-evidence'],
      maximumResidualOperatingCurrentMa: maximumResidualOperatingCurrentMa,
      allowedTypes: allowedTypes,
      preferredTypes: preferredTypes,
      allowedDeviceKinds: allowedDeviceKinds,
      preferredDeviceKinds: preferredDeviceKinds,
      minimumPoleCount: 2,
      sensitivityPreference: sensitivityPreference,
      candidates: candidates,
      sourceId: 'qualification-rccd-policy',
      sourceRevision: '2026.1',
    );

ResidualCurrentProtectionPolicy _notRequiredPolicy() =>
    ResidualCurrentProtectionPolicy(
      circuitId: 'circuit-001',
      applicability: ResidualCurrentApplicability.notRequired,
      rationaleCode: 'qualification.rcd-not-required',
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
    );

ElectricalShortCircuitClosureResult _d4Closure({
  OvercurrentProtectiveDeviceSpec overcurrent = _mcb16,
}) {
  final calculation = _calculation();
  final d3Request = ElectricalCircuitClosureRequest(
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
        protectionCandidates: [overcurrent],
        allowedProtectionKinds: {overcurrent.kind},
        minimumProtectionPoleCount: 1,
        sourceId: 'closure-policy',
        sourceRevision: 'r1',
      ),
    ],
  );
  final d3 = ElectricalCircuitClosureEngine.close(d3Request);
  if (!d3.isFullyClosed) {
    throw StateError('D5 fixture requires fully closed D3.');
  }

  final d4Request = ElectricalShortCircuitClosureRequest(
    d3Closure: d3,
    policies: [
      ElectricalShortCircuitClosurePolicy(
        circuitId: 'circuit-001',
        disconnectionFaultCase: _faultCase('minimum-disconnection', 0.04),
        thermalFaultCase: _faultCase('maximum-thermal', 0.02),
        requiredMaxDisconnectionTimeS: 0.4,
        timeCurrentEvidence: ProtectiveDeviceTimeCurrentEvidence(
          deviceId: overcurrent.id,
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
    throw StateError('D5 fixture requires fully closed D4.');
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
