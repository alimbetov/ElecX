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
  group('P9.5-D3 cable + protection closure', () {
    test('Q15 closes Ib -> Iz -> In with smallest compliant cable/device', () {
      final calculation = _calculation([
        _load('load-a', 3000),
      ]);
      final result = ElectricalCircuitClosureEngine.close(
        ElectricalCircuitClosureRequest(
          calculation: calculation,
          policies: [
            _policy(
              circuitId: 'circuit-001',
              cables: [
                _cableCandidate('cable-1.5', 1.5, ampacityA: 13),
                _cableCandidate('cable-2.5', 2.5, ampacityA: 21),
                _cableCandidate('cable-4', 4, ampacityA: 28),
              ],
              devices: const [_c20, _c10, _c16],
            ),
          ],
        ),
      );

      final outcome = result.outcomes.single;
      expect(outcome.status, ElectricalCircuitClosureStatus.closed);
      expect(outcome.selectedCable!.cable.id, 'cable-2.5');
      expect(outcome.selectedCableSizing!.governingAmpacityA, 21);
      expect(outcome.selectedProtection!.id, _c16.id);
      expect(outcome.circuit.calculation.designCurrentA, lessThan(16));
      expect(outcome.circuit.calculation.designCurrentA, greaterThan(13));
    });

    test('Q16 voltage drop can force a larger conductor', () {
      final calculation = _calculation([_load('load-a', 3500)]);
      final result = ElectricalCircuitClosureEngine.close(
        ElectricalCircuitClosureRequest(
          calculation: calculation,
          policies: [
            _policy(
              circuitId: 'circuit-001',
              cables: [
                _cableCandidate(
                  'cable-2.5',
                  2.5,
                  ampacityA: 25,
                  routeLengthMm: 100000,
                  resistanceOhmPerKm: 7.41,
                  maxVoltageDropRatio: 0.03,
                ),
                _cableCandidate(
                  'cable-4',
                  4,
                  ampacityA: 30,
                  routeLengthMm: 100000,
                  resistanceOhmPerKm: 2,
                  maxVoltageDropRatio: 0.03,
                ),
              ],
              devices: const [_c16, _c20],
            ),
          ],
        ),
      );

      final outcome = result.outcomes.single;
      expect(outcome.isClosed, isTrue);
      expect(outcome.selectedCable!.cable.id, 'cable-4');
      final rejected = outcome.cableEvaluations.singleWhere(
        (item) => item.candidate.cable.id == 'cable-2.5',
      );
      expect(rejected.sizing.voltageDropStatus, EngineeringCheckStatus.fail);
    });

    test('Q17 worst derated section governs protection upper bound Iz', () {
      final calculation = _calculation([_load('load-a', 3450)]);
      final cable = _cableCandidate(
        'cable-2.5',
        2.5,
        ampacityA: 25,
        sections: [
          SectionAmpacityEvidence(
            sectionId: 'tray',
            baseAmpacityA: 25,
            factors: const [],
            sourceKey: 'tray-table',
          ),
          SectionAmpacityEvidence(
            sectionId: 'riser',
            baseAmpacityA: 20,
            factors: const [
              ThermalCorrectionFactor(id: 'grouping', factor: 0.85),
            ],
            sourceKey: 'riser-table',
          ),
        ],
      );
      final result = ElectricalCircuitClosureEngine.close(
        ElectricalCircuitClosureRequest(
          calculation: calculation,
          policies: [
            _policy(
              circuitId: 'circuit-001',
              cables: [cable],
              devices: const [_c20, _c16],
            ),
          ],
        ),
      );

      final outcome = result.outcomes.single;
      expect(outcome.selectedCableSizing!.governingSectionId, 'riser');
      expect(outcome.selectedCableSizing!.governingAmpacityA, closeTo(17, 1e-9));
      expect(outcome.selectedProtection!.id, _c16.id);
      expect(
        outcome.protectionSelection!.rejections[_c20.id],
        contains('rated-current-exceeds-cable-ampacity'),
      );
    });

    test('Q18 missing cable evidence fails closed before protection selection', () {
      final calculation = _calculation([_load('load-a', 2000)]);
      final candidate = ElectricalCircuitCableCandidate(
        cable: _cable('cable-2.5', 2.5),
        routeLengthMm: 10000,
        maxVoltageDropRatio: 0.03,
        impedanceEvidence: null,
        ampacitySections: [
          SectionAmpacityEvidence(
            sectionId: 'wall',
            baseAmpacityA: 25,
            factors: const [],
            sourceKey: 'ampacity-table',
          ),
        ],
        sourceId: 'cable-evidence',
        sourceRevision: 'r1',
      );
      final result = ElectricalCircuitClosureEngine.close(
        ElectricalCircuitClosureRequest(
          calculation: calculation,
          policies: [
            _policy(
              circuitId: 'circuit-001',
              cables: [candidate],
              devices: const [_c16],
            ),
          ],
        ),
      );

      final outcome = result.outcomes.single;
      expect(outcome.status, ElectricalCircuitClosureStatus.noCompliantCable);
      expect(outcome.protectionSelection, isNull);
      expect(outcome.cableEvaluations.single.sizing.isIndeterminate, isTrue);
    });

    test('Q19 insufficient breaking capacity keeps closure unresolved', () {
      final calculation = _calculation([_load('load-a', 2000)]);
      final result = ElectricalCircuitClosureEngine.close(
        ElectricalCircuitClosureRequest(
          calculation: calculation,
          policies: [
            _policy(
              circuitId: 'circuit-001',
              cables: [_cableCandidate('cable-2.5', 2.5, ampacityA: 25)],
              devices: const [_c16, _c20],
              prospectiveShortCircuitCurrentA: 7000,
            ),
          ],
        ),
      );

      final outcome = result.outcomes.single;
      expect(
        outcome.status,
        ElectricalCircuitClosureStatus.noCompliantProtection,
      );
      expect(outcome.selectedCable, isNotNull);
      expect(outcome.protectionSelection!.isSelected, isFalse);
      expect(
        outcome.protectionSelection!.rejections[_c16.id],
        contains('breaking-capacity-below-prospective-short-circuit-current'),
      );
    });

    test('Q20 D3 preserves leading/lagging Q in cable voltage drop', () {
      final calculation = _calculation([
        _load(
          'leading-load',
          1000,
          powerFactor: 0.8,
          reactivePowerKind: ElectricalReactivePowerKind.leading,
        ),
        _load(
          'lagging-load',
          1000,
          powerFactor: 0.8,
          reactivePowerKind: ElectricalReactivePowerKind.lagging,
        ),
      ]);
      final candidate = _cableCandidate(
        'cable-2.5',
        2.5,
        ampacityA: 25,
        routeLengthMm: 100000,
        resistanceOhmPerKm: 1,
        reactanceOhmPerKm: 1,
        maxVoltageDropRatio: 0.2,
      );
      final result = ElectricalCircuitClosureEngine.close(
        ElectricalCircuitClosureRequest(
          calculation: calculation,
          policies: [
            _policy(
              circuitId: 'circuit-001',
              cables: [candidate],
              devices: const [_c10],
            ),
            _policy(
              circuitId: 'circuit-002',
              cables: [candidate],
              devices: const [_c10],
            ),
          ],
        ),
      );

      final leading = result.outcomes.singleWhere(
        (item) => item.circuitId == 'circuit-001',
      );
      final lagging = result.outcomes.singleWhere(
        (item) => item.circuitId == 'circuit-002',
      );
      expect(
        leading.selectedCableSizing!.voltageDropV,
        lessThan(lagging.selectedCableSizing!.voltageDropV!),
      );
    });

    test('Q21 structural conductor policy is enforced before sizing', () {
      final calculation = _calculation([_load('load-a', 1000)]);
      final aluminum = ElectricalCircuitCableCandidate(
        cable: CableSpec(
          id: 'al-cable',
          name: 'Al cable',
          medium: RouteMediumProfile.acPower,
          outerDiameterMm: 10,
          segregationClass: CableSegregationClass.power,
          conductorMaterial: ConductorMaterial.aluminum,
          conductorCount: 2,
          conductorCrossSectionMm2: 4,
          ratedVoltageV: 300,
        ),
        routeLengthMm: 10000,
        maxVoltageDropRatio: 0.05,
        impedanceEvidence: const CableImpedanceEvidence(
          resistanceOhmPerKm: 4,
          sourceKey: 'impedance-table',
        ),
        ampacitySections: [
          SectionAmpacityEvidence(
            sectionId: 'wall',
            baseAmpacityA: 30,
            factors: const [],
            sourceKey: 'ampacity-table',
          ),
        ],
        sourceId: 'cable-evidence',
        sourceRevision: 'r1',
      );
      final result = ElectricalCircuitClosureEngine.close(
        ElectricalCircuitClosureRequest(
          calculation: calculation,
          policies: [
            _policy(
              circuitId: 'circuit-001',
              cables: [aluminum],
              devices: const [_c16],
            ),
          ],
        ),
      );

      final evaluation = result.outcomes.single.cableEvaluations.single;
      expect(result.outcomes.single.isClosed, isFalse);
      expect(
        evaluation.structuralRejections,
        containsAll([
          'conductor-count-below-policy-minimum',
          'conductor-material-not-allowed',
          'cable-rated-voltage-below-policy-minimum',
        ]),
      );
    });
  });
}

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

ElectricalCircuitClosurePolicy _policy({
  required String circuitId,
  required List<ElectricalCircuitCableCandidate> cables,
  required List<OvercurrentProtectiveDeviceSpec> devices,
  double prospectiveShortCircuitCurrentA = 3500,
}) =>
    ElectricalCircuitClosurePolicy(
      circuitId: circuitId,
      cableCandidates: cables,
      minimumConductorCount: 3,
      allowedConductorMaterials: const {ConductorMaterial.copper},
      minimumCableRatedVoltageV: 450,
      prospectiveShortCircuitCurrentA: prospectiveShortCircuitCurrentA,
      protectionCandidates: devices,
      allowedProtectionKinds: const {OvercurrentDeviceKind.mcb},
      minimumProtectionPoleCount: 1,
      sourceId: 'closure-policy',
      sourceRevision: 'r1',
    );

ElectricalCircuitCableCandidate _cableCandidate(
  String id,
  double crossSectionMm2, {
  required double ampacityA,
  double routeLengthMm = 10000,
  double resistanceOhmPerKm = 7.41,
  double reactanceOhmPerKm = 0,
  double maxVoltageDropRatio = 0.05,
  List<SectionAmpacityEvidence>? sections,
}) =>
    ElectricalCircuitCableCandidate(
      cable: _cable(id, crossSectionMm2),
      routeLengthMm: routeLengthMm,
      maxVoltageDropRatio: maxVoltageDropRatio,
      impedanceEvidence: CableImpedanceEvidence(
        resistanceOhmPerKm: resistanceOhmPerKm,
        reactanceOhmPerKm: reactanceOhmPerKm,
        sourceKey: 'impedance-table',
      ),
      ampacitySections: sections ??
          [
            SectionAmpacityEvidence(
              sectionId: 'wall',
              baseAmpacityA: ampacityA,
              factors: const [],
              sourceKey: 'ampacity-table',
            ),
          ],
      sourceId: 'cable-evidence',
      sourceRevision: 'r1',
    );

CableSpec _cable(String id, double crossSectionMm2) => CableSpec(
      id: id,
      name: id,
      medium: RouteMediumProfile.acPower,
      outerDiameterMm: 10 + crossSectionMm2 / 10,
      segregationClass: CableSegregationClass.power,
      conductorMaterial: ConductorMaterial.copper,
      conductorCount: 3,
      conductorCrossSectionMm2: crossSectionMm2,
      ratedVoltageV: 450,
    );

ElectricalCircuitCalculationResult _calculation(
  List<ElectricalLoadInput> loads,
) {
  final circuits = <SynthesizedElectricalCircuit>[];
  for (var index = 0; index < loads.length; index++) {
    final load = loads[index];
    circuits.add(
      SynthesizedElectricalCircuit(
        id: 'circuit-${(index + 1).toString().padLeft(3, '0')}',
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
      ),
    );
  }
  final synthesis = ElectricalCircuitSynthesisResult(circuits: circuits);
  return ElectricalCircuitCalculationEngine.calculate(
    ElectricalCircuitCalculationRequest(
      synthesis: synthesis,
      policies: [
        for (final circuit in circuits)
          ElectricalCircuitCalculationPolicy(
            circuitId: circuit.id,
            nominalVoltageV: 230,
            diversityPolicy: ElectricalDiversityPolicy(
              id: 'diversity:${circuit.id}',
              factor: 1,
              sourceId: 'qualification-policy',
              sourceRevision: 'r1',
            ),
            reservePolicy: ElectricalReservePolicy(
              id: 'reserve:${circuit.id}',
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

ElectricalLoadInput _load(
  String id,
  int powerW, {
  double powerFactor = 1,
  ElectricalReactivePowerKind reactivePowerKind =
      ElectricalReactivePowerKind.lagging,
}) =>
    ElectricalLoadInput(
      id: id,
      ratedPowerW: powerW,
      quantity: 1,
      utilizationFactor: 1,
      powerFactor: powerFactor,
      reactivePowerKind: reactivePowerKind,
      sourceId: 'qualification-load',
      sourceRevision: 'r1',
    );
