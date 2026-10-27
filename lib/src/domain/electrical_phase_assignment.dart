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
    if (!lineNeutralVoltageV.isFinite || lineNeutralVoltageV <= 0) {
      throw ArgumentError.value(lineNeutralVoltageV, 'lineNeutralVoltageV');
    }
    if (boardPhaseSystem == DistributionBoardPhaseSystem.threePhase &&
        (lineLineVoltageV == null ||
            !lineLineVoltageV!.isFinite ||
            lineLineVoltageV! <= 0)) {
      throw ArgumentError('Three-phase board requires lineLineVoltageV.');
    }
    _validateCircuitVoltages(
      calculation: calculation,
      boardPhaseSystem: boardPhaseSystem,
      lineNeutralVoltageV: lineNeutralVoltageV,
      lineLineVoltageV: lineLineVoltageV,
    );
  }

  final ElectricalCircuitCalculationResult calculation;
  final DistributionBoardPhaseSystem boardPhaseSystem;
  final double lineNeutralVoltageV;
  final double? lineLineVoltageV;
}

final class PhaseAssignedElectricalCircuit {
  PhaseAssignedElectricalCircuit({
    required this.circuit,
    required this.phase,
  }) {
    final isSingle =
        circuit.phaseSystem == ElectricalLoadPhaseSystem.singlePhaseAc;
    if (isSingle && phase == null) {
      throw ArgumentError(
        'Single-phase circuit ${circuit.id} requires an assigned phase.',
      );
    }
    if (!isSingle && phase != null) {
      throw ArgumentError(
        'Balanced three-phase circuit ${circuit.id} must not target one phase.',
      );
    }
  }

  final CalculatedElectricalCircuit circuit;

  /// Null only for balanced three-phase circuits.
  final DistributionBoardPhase? phase;

  String get id => circuit.id;
}

final class ElectricalAssignedPhaseLoad {
  ElectricalAssignedPhaseLoad({
    required this.phase,
    required this.designPowerW,
    required this.designReactivePowerVar,
    required this.designCurrentA,
  }) {
    if (!designPowerW.isFinite || designPowerW < 0) {
      throw ArgumentError.value(designPowerW, 'designPowerW');
    }
    if (!designReactivePowerVar.isFinite) {
      throw ArgumentError.value(
        designReactivePowerVar,
        'designReactivePowerVar',
      );
    }
    if (!designCurrentA.isFinite || designCurrentA < 0) {
      throw ArgumentError.value(designCurrentA, 'designCurrentA');
    }
  }

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
    required this.boardPhaseSystem,
    required this.lineNeutralVoltageV,
    required this.lineLineVoltageV,
    required this.maxPhaseCurrentA,
    required this.phaseCurrentImbalanceRatio,
  })  : circuits = List.unmodifiable(circuits),
        phaseLoads = List.unmodifiable(phaseLoads) {
    if (!lineNeutralVoltageV.isFinite || lineNeutralVoltageV <= 0) {
      throw ArgumentError.value(lineNeutralVoltageV, 'lineNeutralVoltageV');
    }
    if (boardPhaseSystem == DistributionBoardPhaseSystem.threePhase &&
        (lineLineVoltageV == null ||
            !lineLineVoltageV!.isFinite ||
            lineLineVoltageV! <= 0)) {
      throw ArgumentError('Three-phase result requires lineLineVoltageV.');
    }
    final circuitIds = <String>{};
    for (final circuit in this.circuits) {
      if (!circuitIds.add(circuit.id)) {
        throw ArgumentError('Duplicate phase-assigned circuit ${circuit.id}.');
      }
      if (boardPhaseSystem == DistributionBoardPhaseSystem.singlePhase &&
          circuit.phase != null &&
          circuit.phase != DistributionBoardPhase.l1) {
        throw ArgumentError(
          'Single-phase board can assign circuits only to L1.',
        );
      }
    }
    _validateCircuitVoltages(
      calculation: ElectricalCircuitCalculationResult(
        circuits: [for (final assigned in this.circuits) assigned.circuit],
      ),
      boardPhaseSystem: boardPhaseSystem,
      lineNeutralVoltageV: lineNeutralVoltageV,
      lineLineVoltageV: lineLineVoltageV,
    );

    final phases = <DistributionBoardPhase>{};
    for (final phaseLoad in this.phaseLoads) {
      if (!phases.add(phaseLoad.phase)) {
        throw ArgumentError(
          'Duplicate phase-load result ${phaseLoad.phase.name}.',
        );
      }
    }
    final expectedPhases =
        boardPhaseSystem == DistributionBoardPhaseSystem.singlePhase
            ? const {DistributionBoardPhase.l1}
            : DistributionBoardPhase.values.toSet();
    if (phases.length != expectedPhases.length ||
        !phases.containsAll(expectedPhases)) {
      throw ArgumentError(
        'Phase-load results do not match the board phase system.',
      );
    }
    if (!maxPhaseCurrentA.isFinite ||
        maxPhaseCurrentA < 0 ||
        !phaseCurrentImbalanceRatio.isFinite ||
        phaseCurrentImbalanceRatio < 0) {
      throw ArgumentError('Phase-assignment metrics must be finite/non-negative.');
    }
  }

  final List<PhaseAssignedElectricalCircuit> circuits;
  final List<ElectricalAssignedPhaseLoad> phaseLoads;
  final DistributionBoardPhaseSystem boardPhaseSystem;
  final double lineNeutralVoltageV;
  final double? lineLineVoltageV;
  final double maxPhaseCurrentA;
  final double phaseCurrentImbalanceRatio;
}

void _validateCircuitVoltages({
  required ElectricalCircuitCalculationResult calculation,
  required DistributionBoardPhaseSystem boardPhaseSystem,
  required double lineNeutralVoltageV,
  required double? lineLineVoltageV,
}) {
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
