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
          sourceId: 'project-load-schedule',
          sourceRevision: '1',
        ),
        ElectricalLoadInput(
          id: 'lighting',
          ratedPowerW: 500,
          quantity: 1,
          utilizationFactor: 0.80,
          powerFactor: 0.90,
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
    expect(result.designPowerW, closeTo(2400, 0.001));
    expect(result.designApparentPowerVa, closeTo(2549.7076, 0.001));
    expect(result.designCurrentA, closeTo(11.0857, 0.001));
    expect(result.equivalentPowerFactor, closeTo(0.941284, 0.0001));
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

  test('mixed power factors are aggregated as apparent power per load', () {
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
          sourceId: 'catalog',
          sourceRevision: '1',
        ),
        ElectricalLoadInput(
          id: 'motor',
          ratedPowerW: 1000,
          quantity: 1,
          utilizationFactor: 1,
          powerFactor: 0.5,
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
    expect(result.designApparentPowerVa, 3000);
    expect(result.equivalentPowerFactor, closeTo(2 / 3, 0.0001));
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
            sourceId: 'catalog',
            sourceRevision: '1',
          ),
          ElectricalLoadInput(
            id: 'same',
            ratedPowerW: 200,
            quantity: 1,
            utilizationFactor: 1,
            powerFactor: 1,
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
