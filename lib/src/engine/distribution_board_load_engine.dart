import 'dart:math' as math;

import '../domain/distribution_board_load.dart';

const String distributionBoardLoadCalculationVersion =
    'electrical.board-load-calculation.v1';

abstract final class DistributionBoardLoadEngine {
  static DistributionBoardLoadResult calculate(
    DistributionBoardLoadRequest request,
  ) {
    final phases = request.phaseSystem == DistributionBoardPhaseSystem.singlePhase
        ? const [DistributionBoardPhase.l1]
        : DistributionBoardPhase.values;
    final state = <DistributionBoardPhase, _PhaseAccumulator>{
      for (final phase in phases) phase: _PhaseAccumulator(),
    };

    var connectedPowerW = 0.0;
    var designPowerW = 0.0;
    var designReactivePowerVar = 0.0;

    for (final circuit in request.circuits) {
      connectedPowerW += circuit.connectedPowerW;
      designPowerW += circuit.designPowerW;
      designReactivePowerVar += circuit.designReactivePowerVar;

      if (circuit.phaseSystem == DistributionBoardPhaseSystem.singlePhase) {
        final phase = circuit.phase!;
        final accumulator = state[phase];
        if (accumulator == null) {
          throw ArgumentError(
            'Circuit ${circuit.id} targets unavailable phase ${phase.name}.',
          );
        }
        accumulator.addSinglePhase(
          powerW: circuit.designPowerW,
          reactivePowerVar: circuit.designReactivePowerVar,
          voltageV: request.lineNeutralVoltageV,
        );
      } else {
        final voltageV = request.lineLineVoltageV;
        if (voltageV == null) {
          throw StateError('Three-phase circuit requires line-line voltage.');
        }
        for (final accumulator in state.values) {
          accumulator.addBalancedThreePhase(
            totalPowerW: circuit.designPowerW,
            totalReactivePowerVar: circuit.designReactivePowerVar,
            lineLineVoltageV: voltageV,
          );
        }
      }
    }

    final phaseLoads = <BoardPhaseLoadResult>[
      for (final phase in phases)
        state[phase]!.toResult(phase: phase),
    ];
    final currents = phaseLoads.map((item) => item.designCurrentA).toList();
    final maxCurrent = currents.reduce(math.max);
    final imbalance = request.phaseSystem == DistributionBoardPhaseSystem.singlePhase
        ? 0.0
        : _imbalanceRatio(currents);
    final apparentPowerVa = math.sqrt(
      designPowerW * designPowerW +
          designReactivePowerVar * designReactivePowerVar,
    );
    final availablePower = request.availablePowerW;
    final powerStatus = availablePower == null
        ? BoardCapacityStatus.indeterminate
        : designPowerW <= availablePower
            ? BoardCapacityStatus.pass
            : BoardCapacityStatus.fail;
    final maxSupplyCurrent = request.supplyMaxCurrentA;
    final currentStatus = maxSupplyCurrent == null
        ? BoardCapacityStatus.indeterminate
        : maxCurrent <= maxSupplyCurrent
            ? BoardCapacityStatus.pass
            : BoardCapacityStatus.fail;

    return DistributionBoardLoadResult(
      connectedPowerW: connectedPowerW,
      designPowerW: designPowerW,
      designReactivePowerVar: designReactivePowerVar,
      designApparentPowerVa: apparentPowerVa,
      phaseLoads: List.unmodifiable(phaseLoads),
      maxPhaseCurrentA: maxCurrent,
      phaseCurrentImbalanceRatio: imbalance,
      powerCapacityStatus: powerStatus,
      currentCapacityStatus: currentStatus,
      availablePowerReserveW:
          availablePower == null ? null : availablePower - designPowerW,
    );
  }

  static double _imbalanceRatio(List<double> currents) {
    final average = currents.reduce((left, right) => left + right) /
        currents.length;
    if (average == 0) return 0;
    final maximum = currents.reduce(math.max);
    final minimum = currents.reduce(math.min);
    return (maximum - minimum) / average;
  }
}

final class _PhaseAccumulator {
  double powerW = 0;
  double reactivePowerVar = 0;
  double activeCurrentA = 0;
  double reactiveCurrentA = 0;

  void addSinglePhase({
    required double powerW,
    required double reactivePowerVar,
    required double voltageV,
  }) {
    this.powerW += powerW;
    this.reactivePowerVar += reactivePowerVar;
    activeCurrentA += powerW / voltageV;
    reactiveCurrentA += reactivePowerVar / voltageV;
  }

  void addBalancedThreePhase({
    required double totalPowerW,
    required double totalReactivePowerVar,
    required double lineLineVoltageV,
  }) {
    powerW += totalPowerW / 3;
    reactivePowerVar += totalReactivePowerVar / 3;
    activeCurrentA += totalPowerW / (math.sqrt(3) * lineLineVoltageV);
    reactiveCurrentA +=
        totalReactivePowerVar / (math.sqrt(3) * lineLineVoltageV);
  }

  BoardPhaseLoadResult toResult({required DistributionBoardPhase phase}) {
    final apparentPowerVa = math.sqrt(
      powerW * powerW + reactivePowerVar * reactivePowerVar,
    );
    final currentA = math.sqrt(
      activeCurrentA * activeCurrentA +
          reactiveCurrentA * reactiveCurrentA,
    );
    return BoardPhaseLoadResult(
      phase: phase,
      designPowerW: powerW,
      designReactivePowerVar: reactivePowerVar,
      designApparentPowerVa: apparentPowerVa,
      designCurrentA: currentA,
    );
  }
}
