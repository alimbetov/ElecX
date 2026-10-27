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
  group('P9.5-D4 short-circuit + automatic disconnection closure', () {
    test('Q25 computes end fault current from source, phase and PE impedance',
        () {
      final fixture = _fixture();
      final result = ElectricalShortCircuitClosureEngine.close(fixture.request);
      final outcome = result.outcomes.single;
      final fault = outcome.disconnectionFault!;

      // 15 m route: 0.04 + 0.015 * (7.41 + 7.41) = 0.2623 ohm.
      expect(fault.loopResistanceOhm, closeTo(0.2623, 1e-9));
      expect(fault.loopReactanceOhm, 0);
      expect(fault.faultCurrentA, closeTo(230 / 0.2623, 1e-6));
      expect(outcome.isClosed, isTrue);
    });

    test('Q26 longer route lowers minimum end fault current', () {
      final short = _fixture(routeLengthMm: 10000);
      final long = _fixture(routeLengthMm: 40000);

      final shortCurrent = ElectricalShortCircuitClosureEngine.close(
        short.request,
      ).outcomes.single.disconnectionFault!.faultCurrentA;
      final longCurrent = ElectricalShortCircuitClosureEngine.close(
        long.request,
      ).outcomes.single.disconnectionFault!.faultCurrentA;

      expect(longCurrent, lessThan(shortCurrent));
    });

    test('Q27 certified time-current upper bound proves disconnection time',
        () {
      final fixture = _fixture(requiredMaxDisconnectionTimeS: 0.4);
      final outcome = ElectricalShortCircuitClosureEngine.close(
        fixture.request,
      ).outcomes.single;

      expect(outcome.disconnectionOperatingTimeS, 0.1);
      expect(outcome.disconnectionStatus, EngineeringCheckStatus.pass);
    });

    test('Q28 D4 does not interpolate between time-current evidence points',
        () {
      final evidence = ProtectiveDeviceTimeCurrentEvidence(
        deviceId: _c16.id,
        points: const [
          TimeCurrentUpperBoundPoint(
            minimumFaultCurrentA: 100,
            maximumOperatingTimeS: 0.4,
          ),
          TimeCurrentUpperBoundPoint(
            minimumFaultCurrentA: 500,
            maximumOperatingTimeS: 0.1,
          ),
        ],
        sourceId: 'manufacturer-curve',
        sourceRevision: 'r1',
      );

      expect(evidence.maximumOperatingTimeAt(99), isNull);
      expect(evidence.maximumOperatingTimeAt(300), 0.4);
      expect(evidence.maximumOperatingTimeAt(500), 0.1);
      expect(evidence.maximumOperatingTimeAt(1000), 0.1);
    });

    test('Q29 required disconnection time failure is explicit', () {
      final fixture = _fixture(requiredMaxDisconnectionTimeS: 0.05);
      final outcome = ElectricalShortCircuitClosureEngine.close(
        fixture.request,
      ).outcomes.single;

      expect(outcome.disconnectionOperatingTimeS, 0.1);
      expect(outcome.disconnectionStatus, EngineeringCheckStatus.fail);
      expect(outcome.isClosed, isFalse);
      expect(outcome.reasons, contains('required-disconnection-time-exceeded'));
    });

    test('Q30 thermal withstand uses I squared t against k squared S squared',
        () {
      final fixture = _fixture();
      final outcome = ElectricalShortCircuitClosureEngine.close(
        fixture.request,
      ).outcomes.single;

      final expectedEnergy = outcome.thermalFault!.faultCurrentA *
          outcome.thermalFault!.faultCurrentA *
          outcome.thermalOperatingTimeS!;
      final expectedCapacity = (143 * 2.5) * (143 * 2.5);

      expect(outcome.faultEnergyA2s, closeTo(expectedEnergy, 1e-6));
      expect(outcome.thermalCapacityA2s, closeTo(expectedCapacity, 1e-9));
      expect(outcome.thermalStatus, EngineeringCheckStatus.pass);
    });

    test('Q31 insufficient protective conductor thermal capacity fails closed',
        () {
      final fixture = _fixture(protectiveCrossSectionMm2: 1);
      final outcome = ElectricalShortCircuitClosureEngine.close(
        fixture.request,
      ).outcomes.single;

      expect(outcome.thermalStatus, EngineeringCheckStatus.fail);
      expect(outcome.isClosed, isFalse);
      expect(
        outcome.reasons,
        contains('protective-conductor-thermal-withstand-exceeded'),
      );
    });

    test('Q32 time-current evidence must match the D3 selected device', () {
      final fixture = _fixture(timeCurrentDeviceId: _c20.id);
      final outcome = ElectricalShortCircuitClosureEngine.close(
        fixture.request,
      ).outcomes.single;

      expect(outcome.disconnectionStatus, EngineeringCheckStatus.indeterminate);
      expect(outcome.thermalStatus, EngineeringCheckStatus.indeterminate);
      expect(outcome.isClosed, isFalse);
      expect(
        outcome.reasons,
        contains('time-current-device-does-not-match-selected-protection'),
      );
    });

    test('Q33 thermal evidence must bind to the D3 selected cable', () {
      final fixture = _fixture(thermalCableId: 'other-cable');
      final outcome = ElectricalShortCircuitClosureEngine.close(
        fixture.request,
      ).outcomes.single;

      expect(outcome.thermalStatus, EngineeringCheckStatus.indeterminate);
      expect(outcome.isClosed, isFalse);
      expect(
        outcome.reasons,
        contains('thermal-evidence-cable-does-not-match-selected-cable'),
      );
    });

    test('Q34 D4 rejects fault cases above D3 upstream prospective current',
        () {
      final fixture = _fixture(
        disconnectionSourceResistanceOhm: 0.001,
        thermalSourceResistanceOhm: 0.001,
        phaseResistanceOhmPerKm: 0.1,
        protectiveResistanceOhmPerKm: 0.1,
      );
      final outcome = ElectricalShortCircuitClosureEngine.close(
        fixture.request,
      ).outcomes.single;

      expect(outcome.upstreamConsistencyStatus, EngineeringCheckStatus.fail);
      expect(outcome.isClosed, isFalse);
      expect(
        outcome.reasons,
        contains('d4-fault-current-exceeds-d3-upstream-prospective-current'),
      );
    });

    test('Q35 missing D4 evidence remains indeterminate, never implicit pass',
        () {
      final fixture = _fixture(missingEvidence: true);
      final outcome = ElectricalShortCircuitClosureEngine.close(
        fixture.request,
      ).outcomes.single;

      expect(
        outcome.upstreamConsistencyStatus,
        EngineeringCheckStatus.indeterminate,
      );
      expect(outcome.disconnectionStatus, EngineeringCheckStatus.indeterminate);
      expect(outcome.thermalStatus, EngineeringCheckStatus.indeterminate);
      expect(outcome.isClosed, isFalse);
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

_D4Fixture _fixture({
  double routeLengthMm = 15000,
  double requiredMaxDisconnectionTimeS = 0.4,
  double protectiveCrossSectionMm2 = 2.5,
  String timeCurrentDeviceId = 'mcb-c16-6ka',
  String thermalCableId = 'cable-2.5',
  double disconnectionSourceResistanceOhm = 0.04,
  double thermalSourceResistanceOhm = 0.02,
  double phaseResistanceOhmPerKm = 7.41,
  double protectiveResistanceOhmPerKm = 7.41,
  bool missingEvidence = false,
}) {
  final d3 = _d3Closure(routeLengthMm: routeLengthMm);
  final policy = ElectricalShortCircuitClosurePolicy(
    circuitId: 'circuit-001',
    disconnectionFaultCase: missingEvidence
        ? null
        : _faultCase(
            id: 'minimum-disconnection',
            sourceResistanceOhm: disconnectionSourceResistanceOhm,
            phaseResistanceOhmPerKm: phaseResistanceOhmPerKm,
            protectiveResistanceOhmPerKm: protectiveResistanceOhmPerKm,
          ),
    thermalFaultCase: missingEvidence
        ? null
        : _faultCase(
            id: 'maximum-thermal',
            sourceResistanceOhm: thermalSourceResistanceOhm,
            phaseResistanceOhmPerKm: phaseResistanceOhmPerKm,
            protectiveResistanceOhmPerKm: protectiveResistanceOhmPerKm,
          ),
    requiredMaxDisconnectionTimeS:
        missingEvidence ? null : requiredMaxDisconnectionTimeS,
    timeCurrentEvidence: missingEvidence
        ? null
        : ProtectiveDeviceTimeCurrentEvidence(
            deviceId: timeCurrentDeviceId,
            points: const [
              TimeCurrentUpperBoundPoint(
                minimumFaultCurrentA: 80,
                maximumOperatingTimeS: 0.4,
              ),
              TimeCurrentUpperBoundPoint(
                minimumFaultCurrentA: 160,
                maximumOperatingTimeS: 0.2,
              ),
              TimeCurrentUpperBoundPoint(
                minimumFaultCurrentA: 800,
                maximumOperatingTimeS: 0.1,
              ),
            ],
            sourceId: 'manufacturer-time-current',
            sourceRevision: '2026.1',
          ),
    thermalEvidence: missingEvidence
        ? null
        : ProtectiveConductorThermalEvidence(
            cableId: thermalCableId,
            crossSectionMm2: protectiveCrossSectionMm2,
            kCoefficientArootSPerMm2: 143,
            sourceId: 'thermal-coefficient-registry',
            sourceRevision: '2026.1',
          ),
    sourceId: 'd4-policy',
    sourceRevision: '2026.1',
  );
  final request = ElectricalShortCircuitClosureRequest(
    d3Closure: d3,
    policies: [policy],
  );
  return _D4Fixture(request: request);
}

FaultLoopCaseEvidence _faultCase({
  required String id,
  required double sourceResistanceOhm,
  required double phaseResistanceOhmPerKm,
  required double protectiveResistanceOhmPerKm,
}) =>
    FaultLoopCaseEvidence(
      id: id,
      faultVoltageV: 230,
      sourceResistanceOhm: sourceResistanceOhm,
      sourceReactanceOhm: 0,
      phaseResistanceOhmPerKm: phaseResistanceOhmPerKm,
      phaseReactanceOhmPerKm: 0,
      protectiveResistanceOhmPerKm: protectiveResistanceOhmPerKm,
      protectiveReactanceOhmPerKm: 0,
      sourceId: 'fault-loop-registry',
      sourceRevision: '2026.1',
    );

ElectricalCircuitClosureResult _d3Closure({required double routeLengthMm}) {
  final calculation = _calculation();
  final request = ElectricalCircuitClosureRequest(
    calculation: calculation,
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
            routeLengthMm: routeLengthMm,
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
        protectionCandidates: const [_c16, _c20],
        allowedProtectionKinds: const {OvercurrentDeviceKind.mcb},
        minimumProtectionPoleCount: 1,
        sourceId: 'closure-policy',
        sourceRevision: 'r1',
      ),
    ],
  );
  final closure = ElectricalCircuitClosureEngine.close(request);
  if (!closure.isFullyClosed) {
    throw StateError('D3 qualification fixture must be fully closed.');
  }
  return closure;
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

final class _D4Fixture {
  const _D4Fixture({required this.request});

  final ElectricalShortCircuitClosureRequest request;
}
