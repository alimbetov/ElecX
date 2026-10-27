import 'dart:math' as math;

import 'distribution_board_load.dart';
import 'electrical_circuit_calculation.dart';
import 'electrical_load_calculation.dart';

final class ElectricalPhaseAssignmentRequest {
  ElectricalPhaseAssignmentRequest({
    required this.calculation,
    required this.boardPhaseSystem,
    required this.lineNeutralVoltageV,
    this.lineLineVoltageV,
  }) {
    if (lineNeutralVoltageV <= 0) {
      throw ArgumentError.value(lineNeutralVoltageV, 'lineNeutralVoltageV');
    }
    if (boardPhaseSystem == DistributionBoardPhaseSystem.threePhase &&
        (lineLineVoltageV == null || lineLineVoltageV! <= 0)) {
      throw ArgumentError('Three-phase board requires lineLineVoltageV.');
    }
    for (final circuit in calculation.circuits) {
      switch (circuit.phaseSystem) {
        case ElectricalLoadPhaseSystem.singlePhaseAc:
          if (circuit.calculation.nominalVoltageV != lineNeutralVoltageV) {
            throw ArgumentError(
              'Circuit ${circuit.id} nominal voltage does not match board '
              'line-neutral voltage.',
            );
          }
        case ElectricalLoadPhaseSystem.threePhaseAc:
          if (boardPhaseSystem == DistributionBoardPhaseSystem.singlePhase) {
            throw ArgumentError(
              'Single-phase board cannot accept three-phase circuit '
              '${circuit.id}.',
            );
          }
          if (circuit.calculation.nominalVoltageV != lineLineVoltageV) {
            throw ArgumentError(
              'Circuit ${circuit.id} nominal voltage does not match board '
              'line-line voltage.',
            );
          }
      }
    }
  }

  final ElectricalCircuitCalculationResult calculation;
  final DistributionBoardPhaseSystem boardPhaseSystem;
  final double lineNeutralVoltageV;
  final double? lineLineVoltageV;
}

final class PhaseAssignedElectricalCircuit {
  const PhaseAssignedElectricalCircuit({
    required this.circuit,
    required this.phase,
  });

  final CalculatedElectricalCircuit circuit;

  /// Null only for balanced three-phase circuits.
  final DistributionBoardPhase? phase;

  String get id => circuit.id;
}

final class ElectricalAssignedPhaseLoad {
  const ElectricalAssignedPhaseLoad({
    required this.phase,
    required this.designPowerW,
    required this.designReactivePowerVar,
    required this.designCurrentA,
  });

  final DistributionBoardPhase phase;
  final double designPowerW;
  final double designReactivePowerVar;
  final double designCurrentA;

  double get designApparentPowerVa => math.sqrt(
        designPowerW * designPowerW +
            designReactivePowerVar * designReactivePowerVar,
      );
}

final class ElectricalPhaseAssignmentResult {
  ElectricalPhaseAssignmentResult({
    required Iterable<PhaseAssignedElectricalCircuit> circuits,
    required Iterable<ElectricalAssignedPhaseLoad> phaseLoads,
    required this.maxPhaseCurrentA,
    required this.phaseCurrentImbalanceRatio,
  })  : circuits = List.unmodifiable(circuits),
        phaseLoads = List.unmodifiable(phaseLoads);

  final List<PhaseAssignedElectricalCircuit> circuits;
  final List<ElectricalAssignedPhaseLoad> phaseLoads;
  final double maxPhaseCurrentA;
  final double phaseCurrentImbalanceRatio;
}
