enum DistributionBoardPhaseSystem { singlePhase, threePhase }

enum DistributionBoardPhase { l1, l2, l3 }

final class BoardCircuitLoad {
  const BoardCircuitLoad({
    required this.id,
    required this.phaseSystem,
    required this.connectedPowerW,
    required this.designPowerW,
    required this.designReactivePowerVar,
    this.phase,
  })  : assert(id != ''),
        assert(connectedPowerW >= 0),
        assert(designPowerW >= 0),
        assert(
          phaseSystem == DistributionBoardPhaseSystem.threePhase ||
              phase != null,
        ),
        assert(
          phaseSystem == DistributionBoardPhaseSystem.singlePhase ||
              phase == null,
        );

  final String id;
  final DistributionBoardPhaseSystem phaseSystem;
  final double connectedPowerW;
  final double designPowerW;
  final double designReactivePowerVar;
  final DistributionBoardPhase? phase;

  double get designApparentPowerVa =>
      (designPowerW * designPowerW +
              designReactivePowerVar * designReactivePowerVar)
          .sqrt();
}

extension _SquareRoot on double {
  double sqrt() {
    if (this == 0) return 0;
    var estimate = this > 1 ? this : 1.0;
    for (var i = 0; i < 24; i++) {
      estimate = 0.5 * (estimate + this / estimate);
    }
    return estimate;
  }
}

final class DistributionBoardLoadRequest {
  DistributionBoardLoadRequest({
    required this.phaseSystem,
    required this.lineNeutralVoltageV,
    required Iterable<BoardCircuitLoad> circuits,
    this.lineLineVoltageV,
    this.availablePowerW,
    this.supplyMaxCurrentA,
  }) : circuits = List.unmodifiable(circuits) {
    if (lineNeutralVoltageV <= 0) {
      throw ArgumentError.value(lineNeutralVoltageV, 'lineNeutralVoltageV');
    }
    if (phaseSystem == DistributionBoardPhaseSystem.threePhase &&
        (lineLineVoltageV == null || lineLineVoltageV! <= 0)) {
      throw ArgumentError('Three-phase board requires lineLineVoltageV.');
    }
    if (availablePowerW != null && availablePowerW! <= 0) {
      throw ArgumentError.value(availablePowerW, 'availablePowerW');
    }
    if (supplyMaxCurrentA != null && supplyMaxCurrentA! <= 0) {
      throw ArgumentError.value(supplyMaxCurrentA, 'supplyMaxCurrentA');
    }
    if (this.circuits.isEmpty) {
      throw ArgumentError('At least one circuit load is required.');
    }
    final ids = <String>{};
    for (final circuit in this.circuits) {
      if (!ids.add(circuit.id)) {
        throw ArgumentError('Duplicate circuit id ${circuit.id}.');
      }
      if (phaseSystem == DistributionBoardPhaseSystem.singlePhase &&
          (circuit.phaseSystem == DistributionBoardPhaseSystem.threePhase ||
              circuit.phase != DistributionBoardPhase.l1)) {
        throw ArgumentError(
          'Single-phase board accepts only L1 single-phase circuits.',
        );
      }
    }
  }

  final DistributionBoardPhaseSystem phaseSystem;
  final double lineNeutralVoltageV;
  final double? lineLineVoltageV;
  final List<BoardCircuitLoad> circuits;
  final double? availablePowerW;
  final double? supplyMaxCurrentA;
}

enum BoardCapacityStatus { pass, fail, indeterminate }

final class BoardPhaseLoadResult {
  const BoardPhaseLoadResult({
    required this.phase,
    required this.designPowerW,
    required this.designReactivePowerVar,
    required this.designApparentPowerVa,
    required this.designCurrentA,
  });

  final DistributionBoardPhase phase;
  final double designPowerW;
  final double designReactivePowerVar;
  final double designApparentPowerVa;
  final double designCurrentA;
}

final class DistributionBoardLoadResult {
  const DistributionBoardLoadResult({
    required this.connectedPowerW,
    required this.designPowerW,
    required this.designReactivePowerVar,
    required this.designApparentPowerVa,
    required this.phaseLoads,
    required this.maxPhaseCurrentA,
    required this.phaseCurrentImbalanceRatio,
    required this.powerCapacityStatus,
    required this.currentCapacityStatus,
    required this.availablePowerReserveW,
  });

  final double connectedPowerW;
  final double designPowerW;
  final double designReactivePowerVar;
  final double designApparentPowerVa;
  final List<BoardPhaseLoadResult> phaseLoads;
  final double maxPhaseCurrentA;
  final double phaseCurrentImbalanceRatio;
  final BoardCapacityStatus powerCapacityStatus;
  final BoardCapacityStatus currentCapacityStatus;
  final double? availablePowerReserveW;
}
