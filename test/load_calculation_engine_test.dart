import 'package:elecx/src/domain/electrical_load_calculation.dart';
import 'package:elecx/src/engine/load_calculation_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('single-phase group keeps Ki, diversity and reserve separate', () {
    final request = ElectricalLoadCalculationRequest(
      phaseSystem: ElectricalLoadPhaseSystem.singlePhaseAc,
      nominalVoltageV: 230,
      loads: const [
        ElectricalLoadInput(
          id: 'sockets',
          ratedPowerW: 3000,
          quantity: 1,
          utilizationFactor: 0.70,
          powerFactor: 0.95,
          reactivePowerKind: ElectricalReactivePowerKind.lagging,
          sourceId: 'project-load-schedule',
          sourceRevision: '1',
        ),
        ElectricalLoadInput(
          id: 'lighting',
          ratedPowerW: 500,
          quantity: 1,
          utilizationFactor: 0.80,
          powerFactor: 0.90,
          reactivePowerKind: ElectricalReactivePowerKind.lagging,
          sourceId: 'project-load-schedule',
          sourceRevision: '1',
        ),
      ],
      diversityPolicy: const ElectricalDiversityPolicy(
        id: 'residential-general-0.80',
        factor: 0.80,
        sourceId: 'project-diversity-policy',
        sourceRevision: '1',
      ),
      reservePolicy: const ElectricalReservePolicy(
        id: 'project-reserve-20',
        reserveRatio: 0.20,
        sourceId: 'project-reserve-policy',
        sourceRevision: '1',
      ),
    );

    final result = LoadCalculationEngine.calculate(request);

    expect(result.connectedPowerW, 3500);
    expect(result.utilizedPowerW, closeTo(2500, 0.001));
    expect(result.utilizedReactivePowerVar, closeTo(883.9655, 0.001));
    expect(result.designPowerW, closeTo(2400, 0.001));
    expect(result.designReactivePowerVar, closeTo(848.6068, 0.001));
    expect(result.designApparentPowerVa, closeTo(2545.6106, 0.001));
    expect(result.designCurrentA, closeTo(11.0679, 0.001));
    expect(result.equivalentPowerFactor, closeTo(0.94280, 0.0001));
    expect(result.diversityFactor, 0.80);
    expect(result.reserveRatio, 0.20);
  });

  test('three-phase current uses sqrt(3) and line voltage', () {
    final request = ElectricalLoadCalculationRequest(
      phaseSystem: ElectricalLoadPhaseSystem.threePhaseAc,
      nominalVoltageV: 400,
      loads: const [
        ElectricalLoadInput(
          id: 'hob',
          ratedPowerW: 9000,
          quantity: 1,
          utilizationFactor: 1,
          powerFactor: 0.90,
          reactivePowerKind: ElectricalReactivePowerKind.lagging,
          sourceId: 'manufacturer',
          sourceRevision: 'hob-v1',
        ),
      ],
      diversityPolicy: const ElectricalDiversityPolicy(
        id: 'dedicated-load',
        factor: 1,
        sourceId: 'project-diversity-policy',
        sourceRevision: '1',
      ),
    );

    final result = LoadCalculationEngine.calculate(request);

    expect(result.designPowerW, 9000);
    expect(result.designApparentPowerVa, closeTo(10000, 0.001));
    expect(result.designCurrentA, closeTo(14.4338, 0.001));
  });

  test('mixed power factors aggregate P and Q before deriving S', () {
    final request = ElectricalLoadCalculationRequest(
      phaseSystem: ElectricalLoadPhaseSystem.singlePhaseAc,
      nominalVoltageV: 230,
      loads: const [
        ElectricalLoadInput(
          id: 'resistive',
          ratedPowerW: 1000,
          quantity: 1,
          utilizationFactor: 1,
          powerFactor: 1,
          reactivePowerKind: ElectricalReactivePowerKind.lagging,
          sourceId: 'catalog',
          sourceRevision: '1',
        ),
        ElectricalLoadInput(
          id: 'motor',
          ratedPowerW: 1000,
          quantity: 1,
          utilizationFactor: 1,
          powerFactor: 0.5,
          reactivePowerKind: ElectricalReactivePowerKind.lagging,
          sourceId: 'catalog',
          sourceRevision: '1',
        ),
      ],
      diversityPolicy: const ElectricalDiversityPolicy(
        id: 'all-simultaneous',
        factor: 1,
        sourceId: 'project-diversity-policy',
        sourceRevision: '1',
      ),
    );

    final result = LoadCalculationEngine.calculate(request);

    expect(result.designPowerW, 2000);
    expect(result.designReactivePowerVar, closeTo(1732.0508, 0.001));
    expect(result.designApparentPowerVa, closeTo(2645.7513, 0.001));
    expect(result.equivalentPowerFactor, closeTo(0.75593, 0.0001));
  });

  test('leading and lagging reactive power can cancel', () {
    final request = ElectricalLoadCalculationRequest(
      phaseSystem: ElectricalLoadPhaseSystem.singlePhaseAc,
      nominalVoltageV: 230,
      loads: const [
        ElectricalLoadInput(
          id: 'lagging',
          ratedPowerW: 1000,
          quantity: 1,
          utilizationFactor: 1,
          powerFactor: 0.8,
          reactivePowerKind: ElectricalReactivePowerKind.lagging,
          sourceId: 'catalog',
          sourceRevision: '1',
        ),
        ElectricalLoadInput(
          id: 'leading',
          ratedPowerW: 1000,
          quantity: 1,
          utilizationFactor: 1,
          powerFactor: 0.8,
          reactivePowerKind: ElectricalReactivePowerKind.leading,
          sourceId: 'catalog',
          sourceRevision: '1',
        ),
      ],
      diversityPolicy: const ElectricalDiversityPolicy(
        id: 'all-simultaneous',
        factor: 1,
        sourceId: 'project-diversity-policy',
        sourceRevision: '1',
      ),
    );

    final result = LoadCalculationEngine.calculate(request);

    expect(result.designReactivePowerVar, closeTo(0, 0.001));
    expect(result.designApparentPowerVa, closeTo(2000, 0.001));
    expect(result.equivalentPowerFactor, closeTo(1, 0.0001));
  });

  test('duplicate load identity is rejected', () {
    expect(
      () => ElectricalLoadCalculationRequest(
        phaseSystem: ElectricalLoadPhaseSystem.singlePhaseAc,
        nominalVoltageV: 230,
        loads: const [
          ElectricalLoadInput(
            id: 'same',
            ratedPowerW: 100,
            quantity: 1,
            utilizationFactor: 1,
            powerFactor: 1,
            reactivePowerKind: ElectricalReactivePowerKind.lagging,
            sourceId: 'catalog',
            sourceRevision: '1',
          ),
          ElectricalLoadInput(
            id: 'same',
            ratedPowerW: 200,
            quantity: 1,
            utilizationFactor: 1,
            powerFactor: 1,
            reactivePowerKind: ElectricalReactivePowerKind.lagging,
            sourceId: 'catalog',
            sourceRevision: '1',
          ),
        ],
        diversityPolicy: const ElectricalDiversityPolicy(
          id: 'all-simultaneous',
          factor: 1,
          sourceId: 'policy',
          sourceRevision: '1',
        ),
      ),
      throwsArgumentError,
    );
  });
}
