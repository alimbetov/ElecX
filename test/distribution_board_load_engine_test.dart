import 'dart:math' as math;

import 'package:elecx/src/domain/distribution_board_load.dart';
import 'package:elecx/src/engine/distribution_board_load_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('balanced single-phase circuits produce balanced three-phase board', () {
    final result = DistributionBoardLoadEngine.calculate(
      DistributionBoardLoadRequest(
        phaseSystem: DistributionBoardPhaseSystem.threePhase,
        lineNeutralVoltageV: 230,
        lineLineVoltageV: 400,
        availablePowerW: 10000,
        supplyMaxCurrentA: 16,
        circuits: const [
          BoardCircuitLoad(
            id: 'l1',
            phaseSystem: DistributionBoardPhaseSystem.singlePhase,
            connectedPowerW: 2300,
            designPowerW: 2300,
            designReactivePowerVar: 0,
            phase: DistributionBoardPhase.l1,
          ),
          BoardCircuitLoad(
            id: 'l2',
            phaseSystem: DistributionBoardPhaseSystem.singlePhase,
            connectedPowerW: 2300,
            designPowerW: 2300,
            designReactivePowerVar: 0,
            phase: DistributionBoardPhase.l2,
          ),
          BoardCircuitLoad(
            id: 'l3',
            phaseSystem: DistributionBoardPhaseSystem.singlePhase,
            connectedPowerW: 2300,
            designPowerW: 2300,
            designReactivePowerVar: 0,
            phase: DistributionBoardPhase.l3,
          ),
        ],
      ),
    );

    expect(result.connectedPowerW, 6900);
    expect(result.designPowerW, 6900);
    expect(
        result.phaseLoads.map((item) => item.designCurrentA), everyElement(10));
    expect(result.maxPhaseCurrentA, 10);
    expect(result.phaseCurrentImbalanceRatio, 0);
    expect(result.powerCapacityStatus, BoardCapacityStatus.pass);
    expect(result.currentCapacityStatus, BoardCapacityStatus.pass);
    expect(result.availablePowerReserveW, 3100);
  });

  test('phase imbalance and supply current limit are explicit', () {
    final result = DistributionBoardLoadEngine.calculate(
      DistributionBoardLoadRequest(
        phaseSystem: DistributionBoardPhaseSystem.threePhase,
        lineNeutralVoltageV: 230,
        lineLineVoltageV: 400,
        availablePowerW: 10000,
        supplyMaxCurrentA: 16,
        circuits: const [
          BoardCircuitLoad(
            id: 'heavy-l1',
            phaseSystem: DistributionBoardPhaseSystem.singlePhase,
            connectedPowerW: 4600,
            designPowerW: 4600,
            designReactivePowerVar: 0,
            phase: DistributionBoardPhase.l1,
          ),
          BoardCircuitLoad(
            id: 'l2',
            phaseSystem: DistributionBoardPhaseSystem.singlePhase,
            connectedPowerW: 2300,
            designPowerW: 2300,
            designReactivePowerVar: 0,
            phase: DistributionBoardPhase.l2,
          ),
        ],
      ),
    );

    expect(result.maxPhaseCurrentA, 20);
    expect(result.phaseCurrentImbalanceRatio, closeTo(2, 0.0001));
    expect(result.powerCapacityStatus, BoardCapacityStatus.pass);
    expect(result.currentCapacityStatus, BoardCapacityStatus.fail);
  });

  test('balanced three-phase circuit uses line-line voltage', () {
    final reactivePowerVar = 9000 * math.tan(math.acos(0.9));
    final result = DistributionBoardLoadEngine.calculate(
      DistributionBoardLoadRequest(
        phaseSystem: DistributionBoardPhaseSystem.threePhase,
        lineNeutralVoltageV: 230,
        lineLineVoltageV: 400,
        circuits: [
          BoardCircuitLoad(
            id: 'hob',
            phaseSystem: DistributionBoardPhaseSystem.threePhase,
            connectedPowerW: 9000,
            designPowerW: 9000,
            designReactivePowerVar: reactivePowerVar,
          ),
        ],
      ),
    );

    expect(result.designApparentPowerVa, closeTo(10000, 0.001));
    expect(result.maxPhaseCurrentA, closeTo(14.4338, 0.001));
    expect(result.phaseCurrentImbalanceRatio, 0);
    expect(result.powerCapacityStatus, BoardCapacityStatus.indeterminate);
    expect(result.currentCapacityStatus, BoardCapacityStatus.indeterminate);
  });

  test('single-phase board rejects L2/L3 and three-phase circuits', () {
    expect(
      () => DistributionBoardLoadRequest(
        phaseSystem: DistributionBoardPhaseSystem.singlePhase,
        lineNeutralVoltageV: 230,
        circuits: const [
          BoardCircuitLoad(
            id: 'invalid-l2',
            phaseSystem: DistributionBoardPhaseSystem.singlePhase,
            connectedPowerW: 1000,
            designPowerW: 1000,
            designReactivePowerVar: 0,
            phase: DistributionBoardPhase.l2,
          ),
        ],
      ),
      throwsArgumentError,
    );
  });
}
