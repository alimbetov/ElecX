import 'package:elecx/src/domain/cable_spec.dart';
import 'package:elecx/src/domain/electrical_circuit_calculation.dart';
import 'package:elecx/src/domain/electrical_circuit_synthesis.dart';
import 'package:elecx/src/domain/electrical_load_calculation.dart';
import 'package:elecx/src/domain/overcurrent_protection.dart';
import 'package:elecx/src/domain/route_medium.dart';
import 'package:elecx/src/engine/cable_sizing_engine.dart';
import 'package:elecx/src/engine/circuit_grouping_engine.dart';
import 'package:elecx/src/engine/electrical_circuit_calculation_engine.dart';
import 'package:elecx/src/engine/electrical_circuit_closure_engine.dart';
import 'package:elecx/src/engine/electrical_short_circuit_closure_engine.dart';
import 'package:elecx/src/engine/load_calculation_engine.dart';
import 'package:elecx/src/engine/overcurrent_protection_selection_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P9.5 hard-review safety regressions', () {
    test('Q41 load engine rejects non-finite voltage at runtime', () {
      final request = ElectricalLoadCalculationRequest(
        phaseSystem: ElectricalLoadPhaseSystem.singlePhaseAc,
        nominalVoltageV: double.nan,
        loads: const [_validLoad],
        diversityPolicy: _diversity,
        reservePolicy: _reserve,
      );

      expect(
        () => LoadCalculationEngine.calculate(request),
        throwsArgumentError,
      );
    });

    test('Q42 cable engine rejects non-finite impedance at runtime', () {
      final request = CableSizingRequest(
        cable: _cable(),
        requirement: const CircuitElectricalRequirement(
          phaseSystem: CircuitPhaseSystem.singlePhaseAc,
          designCurrentA: 10,
          nominalVoltageV: 230,
          routeLengthMm: 10000,
          maxVoltageDropRatio: 0.05,
        ),
        impedanceEvidence: const CableImpedanceEvidence(
          resistanceOhmPerKm: double.infinity,
          sourceKey: 'invalid-impedance-evidence',
        ),
        ampacitySections: [
          SectionAmpacityEvidence(
            sectionId: 'wall',
            baseAmpacityA: 21,
            factors: const [],
            sourceKey: 'ampacity-table',
          ),
        ],
      );

      expect(() => CableSizingEngine.evaluate(request), throwsArgumentError);
    });

    test('Q43 overcurrent engine rejects non-finite catalog ratings', () {
      const invalid = OvercurrentProtectiveDeviceSpec(
        id: 'invalid-infinite-rating',
        kind: OvercurrentDeviceKind.mcb,
        ratedCurrentA: double.infinity,
        breakingCapacityKa: 6,
        poleCount: 1,
        sourceId: 'device-catalog',
        sourceRevision: 'bad-fixture',
      );
      final request = OvercurrentProtectionRequest(
        designCurrentA: 10,
        cableAmpacityA: 21,
        prospectiveShortCircuitCurrentA: 3500,
        candidates: const [invalid],
      );

      expect(
        () => OvercurrentProtectionSelectionEngine.select(request),
        throwsArgumentError,
      );
    });

    test('Q44 D4 cannot overstate PE cross-section beyond selected cable', () {
      final d3 = _d3Closure();
      final request = ElectricalShortCircuitClosureRequest(
        d3Closure: d3,
        policies: [
          ElectricalShortCircuitClosurePolicy(
            circuitId: 'circuit-001',
            disconnectionFaultCase: _faultCase('minimum-disconnection', 0.04),
            thermalFaultCase: _faultCase('maximum-thermal', 0.02),
            requiredMaxDisconnectionTimeS: 0.4,
            timeCurrentEvidence: ProtectiveDeviceTimeCurrentEvidence(
              deviceId: _c10.id,
              points: const [
                TimeCurrentUpperBoundPoint(
                  minimumFaultCurrentA: 50,
                  maximumOperatingTimeS: 0.4,
                ),
                TimeCurrentUpperBoundPoint(
                  minimumFaultCurrentA: 100,
                  maximumOperatingTimeS: 0.1,
                ),
              ],
              sourceId: 'manufacturer-time-current',
              sourceRevision: '2026.1',
            ),
            thermalEvidence: ProtectiveConductorThermalEvidence(
              cableId: 'cable-2.5',
              crossSectionMm2: 10,
              kCoefficientArootSPerMm2: 143,
              sourceId: 'thermal-registry',
              sourceRevision: '2026.1',
            ),
            sourceId: 'd4-policy',
            sourceRevision: '2026.1',
          ),
        ],
      );

      final outcome =
          ElectricalShortCircuitClosureEngine.close(request).outcomes.single;

      expect(outcome.thermalStatus, EngineeringCheckStatus.indeterminate);
      expect(outcome.isClosed, isFalse);
      expect(
        outcome.reasons,
        contains(
          'thermal-evidence-cross-section-exceeds-selected-cable-conductor',
        ),
      );
    });

    test('Q46 circuit synthesis rejects whitespace-only location at runtime',
        () {
      final request = ElectricalCircuitSynthesisRequest(
        loads: const [
          CircuitSynthesisLoad(
            load: _validLoad,
            kind: ElectricalCircuitLoadKind.other,
            locationId: '   ',
            requiredPhaseSystem: ElectricalLoadPhaseSystem.singlePhaseAc,
          ),
        ],
        groupingPolicy: _groupingPolicy(),
        dedicatedCircuitPolicy: DedicatedCircuitPolicy(
          id: 'dedicated-none',
          rules: const [],
          sourceId: 'qualification-policy',
          sourceRevision: 'r1',
        ),
      );

      expect(() => CircuitGroupingEngine.synthesize(request), throwsArgumentError);
    });

    test('Q47 ambiguous dedicated rules fail closed without hidden priority', () {
      final request = ElectricalCircuitSynthesisRequest(
        loads: const [
          CircuitSynthesisLoad(
            load: _validLoad,
            kind: ElectricalCircuitLoadKind.other,
            locationId: 'qualification',
            requiredPhaseSystem: ElectricalLoadPhaseSystem.singlePhaseAc,
          ),
        ],
        groupingPolicy: _groupingPolicy(),
        dedicatedCircuitPolicy: DedicatedCircuitPolicy(
          id: 'dedicated-ambiguous',
          rules: [
            DedicatedCircuitRule(
              id: 'by-kind',
              loadKinds: const {ElectricalCircuitLoadKind.other},
              sourceId: 'qualification-policy',
              sourceRevision: 'r1',
            ),
            DedicatedCircuitRule(
              id: 'by-id',
              loadIds: const {'load-a'},
              sourceId: 'qualification-policy',
              sourceRevision: 'r1',
            ),
          ],
          sourceId: 'qualification-policy',
          sourceRevision: 'r1',
        ),
      );

      expect(() => CircuitGroupingEngine.synthesize(request), throwsStateError);
    });
  });
}

const _validLoad = ElectricalLoadInput(
  id: 'load-a',
  ratedPowerW: 1000,
  quantity: 1,
  utilizationFactor: 1,
  powerFactor: 1,
  reactivePowerKind: ElectricalReactivePowerKind.lagging,
  sourceId: 'qualification-load',
  sourceRevision: 'r1',
);

const _diversity = ElectricalDiversityPolicy(
  id: 'diversity',
  factor: 1,
  sourceId: 'qualification-policy',
  sourceRevision: 'r1',
);

const _reserve = ElectricalReservePolicy(
  id: 'reserve',
  reserveRatio: 0,
  sourceId: 'qualification-policy',
  sourceRevision: 'r1',
);

const _c10 = OvercurrentProtectiveDeviceSpec(
  id: 'mcb-c10-6ka',
  kind: OvercurrentDeviceKind.mcb,
  ratedCurrentA: 10,
  breakingCapacityKa: 6,
  poleCount: 1,
  tripCurve: OvercurrentTripCurve.c,
  sourceId: 'device-catalog',
  sourceRevision: 'r1',
);

CircuitGroupingPolicy _groupingPolicy() => CircuitGroupingPolicy(
      id: 'grouping-policy',
      maxGroupedLoadsPerCircuit: 8,
      maxGroupedConnectedPowerW: 5000,
      separateByLocation: false,
      separateByLoadKind: false,
      sourceId: 'qualification-policy',
      sourceRevision: 'r1',
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
  final circuit = SynthesizedElectricalCircuit(
    id: 'circuit-001',
    requiredPhaseSystem: ElectricalLoadPhaseSystem.singlePhaseAc,
    dedicated: false,
    loads: const [
      CircuitSynthesisLoad(
        load: _validLoad,
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
  final calculation = ElectricalCircuitCalculationEngine.calculate(
    ElectricalCircuitCalculationRequest(
      synthesis: ElectricalCircuitSynthesisResult(circuits: [circuit]),
      policies: [
        ElectricalCircuitCalculationPolicy(
          circuitId: circuit.id,
          nominalVoltageV: 230,
          diversityPolicy: _diversity,
          reservePolicy: _reserve,
          sourceId: 'circuit-policy',
          sourceRevision: 'r1',
        ),
      ],
    ),
  );
  final closure = ElectricalCircuitClosureEngine.close(
    ElectricalCircuitClosureRequest(
      calculation: calculation,
      policies: [
        ElectricalCircuitClosurePolicy(
          circuitId: circuit.id,
          cableCandidates: [
            ElectricalCircuitCableCandidate(
              cable: _cable(),
              routeLengthMm: 10000,
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
          protectionCandidates: const [_c10],
          allowedProtectionKinds: const {OvercurrentDeviceKind.mcb},
          minimumProtectionPoleCount: 1,
          sourceId: 'closure-policy',
          sourceRevision: 'r1',
        ),
      ],
    ),
  );
  if (!closure.isFullyClosed) {
    throw StateError('Hard-review fixture requires a fully closed D3 result.');
  }
  return closure;
}
