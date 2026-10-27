import '../domain/distribution_board_load.dart';
import '../domain/electrical_load_calculation.dart';
import '../domain/electrical_phase_assignment.dart';

/// Converts calculated/assigned circuits into the existing board-load contract.
///
/// This is intentionally a projection only. Board capacity and imbalance remain
/// owned by [DistributionBoardLoadEngine].
abstract final class PhaseAssignmentBoardProjection {
  static DistributionBoardLoadRequest toBoardRequest({
    required ElectricalPhaseAssignmentResult assignment,
    required DistributionBoardPhaseSystem boardPhaseSystem,
    required double lineNeutralVoltageV,
    double? lineLineVoltageV,
    double? availablePowerW,
    double? supplyMaxCurrentA,
  }) {
    final circuits = <BoardCircuitLoad>[];
    for (final assigned in assignment.circuits) {
      final calculated = assigned.circuit;
      final phaseSystem = switch (calculated.phaseSystem) {
        ElectricalLoadPhaseSystem.singlePhaseAc =>
          DistributionBoardPhaseSystem.singlePhase,
        ElectricalLoadPhaseSystem.threePhaseAc =>
          DistributionBoardPhaseSystem.threePhase,
      };
      circuits.add(
        BoardCircuitLoad(
          id: calculated.id,
          phaseSystem: phaseSystem,
          connectedPowerW: calculated.calculation.connectedPowerW.toDouble(),
          designPowerW: calculated.calculation.designPowerW,
          designReactivePowerVar:
              calculated.calculation.designReactivePowerVar,
          phase: assigned.phase,
        ),
      );
    }

    return DistributionBoardLoadRequest(
      phaseSystem: boardPhaseSystem,
      lineNeutralVoltageV: lineNeutralVoltageV,
      lineLineVoltageV: lineLineVoltageV,
      circuits: circuits,
      availablePowerW: availablePowerW,
      supplyMaxCurrentA: supplyMaxCurrentA,
    );
  }
}
