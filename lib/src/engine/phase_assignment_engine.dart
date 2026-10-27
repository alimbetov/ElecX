import 'dart:math' as math;

import '../domain/distribution_board_load.dart';
import '../domain/electrical_circuit_calculation.dart';
import '../domain/electrical_load_calculation.dart';
import '../domain/electrical_phase_assignment.dart';

const String electricalPhaseAssignmentVersion =
    'electrical.phase-assignment.v1';

/// Deterministically assigns single-phase circuits to board phases.
///
/// Objective order:
/// 1. minimize resulting phase-current imbalance;
/// 2. minimize resulting maximum phase current;
/// 3. deterministic phase order L1 -> L2 -> L3.
///
/// Active/reactive current components are accumulated separately, so balancing
/// is based on P/Q vectors rather than active watts alone.
abstract final class PhaseAssignmentEngine {
  static ElectricalPhaseAssignmentResult assign(
    ElectricalPhaseAssignmentRequest request,
  ) {
    final phases =
        request.boardPhaseSystem == DistributionBoardPhaseSystem.singlePhase
            ? const [DistributionBoardPhase.l1]
            : DistributionBoardPhase.values;
    final state = <DistributionBoardPhase, _PhaseAccumulator>{
      for (final phase in phases) phase: _PhaseAccumulator(),
    };
    final assignments = <PhaseAssignedElectricalCircuit>[];
    final singlePhase = <_SinglePhaseCandidate>[];

    for (final circuit in request.calculation.circuits) {
      if (circuit.phaseSystem == ElectricalLoadPhaseSystem.threePhaseAc) {
        final lineLineVoltageV = request.lineLineVoltageV!;
        for (final accumulator in state.values) {
          accumulator.addThreePhaseBaseline(
            powerW: circuit.calculation.designPowerW,
            reactivePowerVar: circuit.calculation.designReactivePowerVar,
            lineLineVoltageV: lineLineVoltageV,
          );
        }
        assignments.add(
          PhaseAssignedElectricalCircuit(circuit: circuit, phase: null),
        );
      } else {
        singlePhase.add(
          _SinglePhaseCandidate(
            circuit: circuit,
            activeCurrentA:
                circuit.calculation.designPowerW / request.lineNeutralVoltageV,
            reactiveCurrentA: circuit.calculation.designReactivePowerVar /
                request.lineNeutralVoltageV,
          ),
        );
      }
    }

    singlePhase.sort((left, right) {
      final byApparent =
          right.apparentCurrentA.compareTo(left.apparentCurrentA);
      if (byApparent != 0) return byApparent;
      return left.circuit.id.compareTo(right.circuit.id);
    });

    for (final candidate in singlePhase) {
      DistributionBoardPhase? bestPhase;
      _AssignmentScore? bestScore;
      for (final phase in phases) {
        final score = _scorePlacement(
          state: state,
          targetPhase: phase,
          candidate: candidate,
        );
        if (bestScore == null || score.compareTo(bestScore) < 0) {
          bestPhase = phase;
          bestScore = score;
        }
      }
      final selectedPhase = bestPhase!;
      state[selectedPhase]!.addSinglePhase(
        powerW: candidate.circuit.calculation.designPowerW,
        reactivePowerVar: candidate.circuit.calculation.designReactivePowerVar,
        voltageV: request.lineNeutralVoltageV,
      );
      assignments.add(
        PhaseAssignedElectricalCircuit(
          circuit: candidate.circuit,
          phase: selectedPhase,
        ),
      );
    }

    assignments.sort((left, right) => left.id.compareTo(right.id));
    final phaseLoads = <ElectricalAssignedPhaseLoad>[
      for (final phase in phases) state[phase]!.toResult(phase),
    ];
    final currents = phaseLoads.map((item) => item.designCurrentA).toList();

    return ElectricalPhaseAssignmentResult(
      circuits: assignments,
      phaseLoads: phaseLoads,
      boardPhaseSystem: request.boardPhaseSystem,
      lineNeutralVoltageV: request.lineNeutralVoltageV,
      lineLineVoltageV: request.lineLineVoltageV,
      maxPhaseCurrentA: _maximum(currents),
      phaseCurrentImbalanceRatio:
          request.boardPhaseSystem == DistributionBoardPhaseSystem.singlePhase
              ? 0
              : _imbalanceRatio(currents),
    );
  }

  static _AssignmentScore _scorePlacement({
    required Map<DistributionBoardPhase, _PhaseAccumulator> state,
    required DistributionBoardPhase targetPhase,
    required _SinglePhaseCandidate candidate,
  }) {
    final currents = <double>[];
    for (final phase in state.keys) {
      final accumulator = state[phase]!;
      final active = accumulator.activeCurrentA +
          (phase == targetPhase ? candidate.activeCurrentA : 0);
      final reactive = accumulator.reactiveCurrentA +
          (phase == targetPhase ? candidate.reactiveCurrentA : 0);
      currents.add(math.sqrt(active * active + reactive * reactive));
    }
    return _AssignmentScore(
      imbalanceRatio: currents.length == 1 ? 0 : _imbalanceRatio(currents),
      maxCurrentA: _maximum(currents),
      phaseOrdinal: targetPhase.index,
    );
  }

  static double _imbalanceRatio(List<double> currents) {
    final average =
        currents.reduce((left, right) => left + right) / currents.length;
    if (average == 0) return 0;
    return (_maximum(currents) - _minimum(currents)) / average;
  }

  static double _maximum(List<double> values) {
    var result = values.first;
    for (final value in values.skip(1)) {
      if (value > result) result = value;
    }
    return result;
  }

  static double _minimum(List<double> values) {
    var result = values.first;
    for (final value in values.skip(1)) {
      if (value < result) result = value;
    }
    return result;
  }
}

final class _SinglePhaseCandidate {
  const _SinglePhaseCandidate({
    required this.circuit,
    required this.activeCurrentA,
    required this.reactiveCurrentA,
  });

  final CalculatedElectricalCircuit circuit;
  final double activeCurrentA;
  final double reactiveCurrentA;

  double get apparentCurrentA => math.sqrt(
        activeCurrentA * activeCurrentA + reactiveCurrentA * reactiveCurrentA,
      );
}

final class _AssignmentScore implements Comparable<_AssignmentScore> {
  const _AssignmentScore({
    required this.imbalanceRatio,
    required this.maxCurrentA,
    required this.phaseOrdinal,
  });

  final double imbalanceRatio;
  final double maxCurrentA;
  final int phaseOrdinal;

  @override
  int compareTo(_AssignmentScore other) {
    final byImbalance = imbalanceRatio.compareTo(other.imbalanceRatio);
    if (byImbalance != 0) return byImbalance;
    final byMaxCurrent = maxCurrentA.compareTo(other.maxCurrentA);
    if (byMaxCurrent != 0) return byMaxCurrent;
    return phaseOrdinal.compareTo(other.phaseOrdinal);
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

  void addThreePhaseBaseline({
    required double powerW,
    required double reactivePowerVar,
    required double lineLineVoltageV,
  }) {
    this.powerW += powerW / 3;
    this.reactivePowerVar += reactivePowerVar / 3;
    activeCurrentA += powerW / (math.sqrt(3) * lineLineVoltageV);
    reactiveCurrentA += reactivePowerVar / (math.sqrt(3) * lineLineVoltageV);
  }

  ElectricalAssignedPhaseLoad toResult(DistributionBoardPhase phase) {
    final currentA = math.sqrt(
      activeCurrentA * activeCurrentA + reactiveCurrentA * reactiveCurrentA,
    );
    return ElectricalAssignedPhaseLoad(
      phase: phase,
      designPowerW: powerW,
      designReactivePowerVar: reactivePowerVar,
      designCurrentA: currentA,
    );
  }
}
