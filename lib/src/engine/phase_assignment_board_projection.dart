import '../domain/distribution_board_load.dart';
import '../domain/electrical_load_calculation.dart';
import '../domain/electrical_phase_assignment.dart';

/// Converts calculated/assigned circuits into the existing board-load contract.
///
/// Board phase system and voltages are taken from the assignment result itself,
/// preventing downstream callers from silently projecting the same assignments
/// against a different supply system.
abstract final class PhaseAssignmentBoardProjection {
  static DistributionBoardLoadRequest toBoardRequest({
    required ElectricalPhaseAssignmentResult assignment,
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
          designReactivePowerVar: calculated.calculation.designReactivePowerVar,
          phase: assigned.phase,
        ),
      );
    }

    return DistributionBoardLoadRequest(
      phaseSystem: assignment.boardPhaseSystem,
      lineNeutralVoltageV: assignment.lineNeutralVoltageV,
      lineLineVoltageV: assignment.lineLineVoltageV,
      circuits: circuits,
      availablePowerW: availablePowerW,
      supplyMaxCurrentA: supplyMaxCurrentA,
    );
  }
}
