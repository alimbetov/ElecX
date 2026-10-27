import 'dart:math' as math;

import 'package:elecx/src/domain/distribution_board_load.dart';
import 'package:elecx/src/domain/electrical_circuit_calculation.dart';
import 'package:elecx/src/domain/electrical_circuit_synthesis.dart';
import 'package:elecx/src/domain/electrical_load_calculation.dart';
import 'package:elecx/src/domain/electrical_phase_assignment.dart';
import 'package:elecx/src/engine/distribution_board_load_engine.dart';
import 'package:elecx/src/engine/electrical_circuit_calculation_engine.dart';
import 'package:elecx/src/engine/phase_assignment_board_projection.dart';
import 'package:elecx/src/engine/phase_assignment_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P9.5-D2 circuit calculation', () {
    test('Q01 calculates circuit P/Q/S/Ib through authoritative load engine', () {
      final synthesis = _synthesis([
        _circuit(
          'circuit-001',
          ElectricalLoadPhaseSystem.singlePhaseAc,
          [
            _load('resistive', 1000),
            _load('motor', 1000, powerFactor: 0.8),
          ],
        ),
      ]);
      final result = ElectricalCircuitCalculationEngine.calculate(
        _calculationRequest(synthesis),
      );
      final calculation = result.circuits.single.calculation;

      expect(calculation.connectedPowerW, 2000);
      expect(calculation.designPowerW, closeTo(2000, 1e-9));
      expect(calculation.designReactivePowerVar, closeTo(750, 1e-9));
      expect(
        calculation.designApparentPowerVa,
        closeTo(math.sqrt(2000 * 2000 + 750 * 750), 1e-9),
      );
      expect(
        calculation.designCurrentA,
        closeTo(calculation.designApparentPowerVa / 230, 1e-9),
      );
    });

    test('Q02 each circuit requires an explicit calculation policy', () {
      final synthesis = _synthesis([
        _circuit(
          'circuit-001',
          ElectricalLoadPhaseSystem.singlePhaseAc,
          [_load('load-a', 1000)],
        ),
        _circuit(
          'circuit-002',
          ElectricalLoadPhaseSystem.singlePhaseAc,
          [_load('load-b', 1000)],
        ),
      ]);

      expect(
        () => ElectricalCircuitCalculationRequest(
          synthesis: synthesis,
          policies: [_policy('circuit-001')],
        ),
        throwsArgumentError,
      );
    });

    test('Q03 per-circuit diversity and reserve remain independent', () {
      final synthesis = _synthesis([
        _circuit(
          'circuit-001',
          ElectricalLoadPhaseSystem.singlePhaseAc,
          [_load('load-a', 2000)],
        ),
        _circuit(
          'circuit-002',
          ElectricalLoadPhaseSystem.singlePhaseAc,
          [_load('load-b', 2000)],
        ),
      ]);
      final result = ElectricalCircuitCalculationEngine.calculate(
        ElectricalCircuitCalculationRequest(
          synthesis: synthesis,
          policies: [
            _policy('circuit-001', diversity: 0.5, reserve: 0.2),
            _policy('circuit-002', diversity: 1, reserve: 0),
          ],
        ),
      );

      expect(result.circuits[0].calculation.designPowerW, closeTo(1200, 1e-9));
      expect(result.circuits[1].calculation.designPowerW, closeTo(2000, 1e-9));
      expect(result.circuits[0].calculation.diversityFactor, 0.5);
      expect(result.circuits[0].calculation.reserveRatio, 0.2);
    });

    test('Q04 three-phase current uses explicit line-line voltage', () {
      final synthesis = _synthesis([
        _circuit(
          'circuit-001',
          ElectricalLoadPhaseSystem.threePhaseAc,
          [_load('three-phase-load', 6900)],
        ),
      ]);
      final result = ElectricalCircuitCalculationEngine.calculate(
        ElectricalCircuitCalculationRequest(
          synthesis: synthesis,
          policies: [_policy('circuit-001', nominalVoltageV: 400)],
        ),
      );

      expect(
        result.circuits.single.calculation.designCurrentA,
        closeTo(6900 / (math.sqrt(3) * 400), 1e-9),
      );
    });
  });

  group('P9.5-D2 automatic phase assignment', () {
    test('Q05 equal single-phase circuits balance deterministically', () {
      final calculation = _calculateSinglePhaseCircuits([
        _load('a', 2300),
        _load('b', 2300),
        _load('c', 2300),
      ]);
      final result = PhaseAssignmentEngine.assign(
        ElectricalPhaseAssignmentRequest(
          calculation: calculation,
          boardPhaseSystem: DistributionBoardPhaseSystem.threePhase,
          lineNeutralVoltageV: 230,
          lineLineVoltageV: 400,
        ),
      );

      expect(_phaseOf(result, 'circuit-001'), DistributionBoardPhase.l1);
      expect(_phaseOf(result, 'circuit-002'), DistributionBoardPhase.l2);
      expect(_phaseOf(result, 'circuit-003'), DistributionBoardPhase.l3);
      expect(result.phaseCurrentImbalanceRatio, closeTo(0, 1e-12));
      expect(result.maxPhaseCurrentA, closeTo(10, 1e-9));
    });

    test('Q06 assignment uses reactive power vector, not watts only', () {
      final calculation = _calculateSinglePhaseCircuits([
        _load(
          'a',
          1000,
          powerFactor: 0.8,
          reactivePowerKind: ElectricalReactivePowerKind.leading,
        ),
        _load(
          'b',
          1000,
          powerFactor: 0.8,
          reactivePowerKind: ElectricalReactivePowerKind.leading,
        ),
        _load(
          'c',
          1000,
          powerFactor: 0.8,
          reactivePowerKind: ElectricalReactivePowerKind.lagging,
        ),
        _load(
          'd',
          1000,
          powerFactor: 0.8,
          reactivePowerKind: ElectricalReactivePowerKind.leading,
        ),
      ]);
      final result = PhaseAssignmentEngine.assign(
        ElectricalPhaseAssignmentRequest(
          calculation: calculation,
          boardPhaseSystem: DistributionBoardPhaseSystem.threePhase,
          lineNeutralVoltageV: 230,
          lineLineVoltageV: 400,
        ),
      );

      expect(_phaseOf(result, 'circuit-001'), DistributionBoardPhase.l1);
      expect(_phaseOf(result, 'circuit-002'), DistributionBoardPhase.l2);
      expect(_phaseOf(result, 'circuit-003'), DistributionBoardPhase.l3);
      expect(
        _phaseOf(result, 'circuit-004'),
        DistributionBoardPhase.l3,
        reason: 'Opposite Q on L3 lowers the resulting phase current.',
      );
    });

    test('Q07 balanced three-phase load participates as phase baseline', () {
      final synthesis = _synthesis([
        _circuit(
          'circuit-001',
          ElectricalLoadPhaseSystem.threePhaseAc,
          [_load('three-phase', 6900)],
        ),
        _circuit(
          'circuit-002',
          ElectricalLoadPhaseSystem.singlePhaseAc,
          [_load('single-phase', 2300)],
        ),
      ]);
      final calculation = ElectricalCircuitCalculationEngine.calculate(
        ElectricalCircuitCalculationRequest(
          synthesis: synthesis,
          policies: [
            _policy('circuit-001', nominalVoltageV: 400),
            _policy('circuit-002'),
          ],
        ),
      );
      final result = PhaseAssignmentEngine.assign(
        ElectricalPhaseAssignmentRequest(
          calculation: calculation,
          boardPhaseSystem: DistributionBoardPhaseSystem.threePhase,
          lineNeutralVoltageV: 230,
          lineLineVoltageV: 400,
        ),
      );

      expect(_phaseOf(result, 'circuit-001'), isNull);
      expect(_phaseOf(result, 'circuit-002'), DistributionBoardPhase.l1);
      expect(result.phaseLoads, hasLength(3));
      expect(
        result.phaseLoads[1].designCurrentA,
        closeTo(6900 / (math.sqrt(3) * 400), 1e-9),
      );
      expect(result.phaseLoads[0].designCurrentA, greaterThan(19));
    });

    test('Q08 assignment projects losslessly into board load engine', () {
      final calculation = _calculateSinglePhaseCircuits([
        _load('a', 2300),
        _load('b', 1840, powerFactor: 0.8),
        _load('c', 1150),
      ]);
      final assignment = PhaseAssignmentEngine.assign(
        ElectricalPhaseAssignmentRequest(
          calculation: calculation,
          boardPhaseSystem: DistributionBoardPhaseSystem.threePhase,
          lineNeutralVoltageV: 230,
          lineLineVoltageV: 400,
        ),
      );
      final board = DistributionBoardLoadEngine.calculate(
        PhaseAssignmentBoardProjection.toBoardRequest(
          assignment: assignment,
          boardPhaseSystem: DistributionBoardPhaseSystem.threePhase,
          lineNeutralVoltageV: 230,
          lineLineVoltageV: 400,
          availablePowerW: 15000,
          supplyMaxCurrentA: 32,
        ),
      );

      expect(board.maxPhaseCurrentA, closeTo(assignment.maxPhaseCurrentA, 1e-9));
      expect(
        board.phaseCurrentImbalanceRatio,
        closeTo(assignment.phaseCurrentImbalanceRatio, 1e-9),
      );
      expect(board.powerCapacityStatus, BoardCapacityStatus.pass);
      expect(board.currentCapacityStatus, BoardCapacityStatus.pass);
    });

    test('Q09 voltage mismatch and three-phase circuit on 1ph board fail closed', () {
      final single = _calculateSinglePhaseCircuits([_load('a', 1000)]);
      expect(
        () => ElectricalPhaseAssignmentRequest(
          calculation: single,
          boardPhaseSystem: DistributionBoardPhaseSystem.threePhase,
          lineNeutralVoltageV: 220,
          lineLineVoltageV: 380,
        ),
        throwsArgumentError,
      );

      final threePhaseSynthesis = _synthesis([
        _circuit(
          'circuit-001',
          ElectricalLoadPhaseSystem.threePhaseAc,
          [_load('three-phase', 3000)],
        ),
      ]);
      final threePhase = ElectricalCircuitCalculationEngine.calculate(
        ElectricalCircuitCalculationRequest(
          synthesis: threePhaseSynthesis,
          policies: [_policy('circuit-001', nominalVoltageV: 400)],
        ),
      );
      expect(
        () => ElectricalPhaseAssignmentRequest(
          calculation: threePhase,
          boardPhaseSystem: DistributionBoardPhaseSystem.singlePhase,
          lineNeutralVoltageV: 230,
        ),
        throwsArgumentError,
      );
    });
  });
}

ElectricalCircuitCalculationResult _calculateSinglePhaseCircuits(
  List<ElectricalLoadInput> loads,
) {
  final synthesis = _synthesis([
    for (var index = 0; index < loads.length; index++)
      _circuit(
        'circuit-${(index + 1).toString().padLeft(3, '0')}',
        ElectricalLoadPhaseSystem.singlePhaseAc,
        [loads[index]],
      ),
  ]);
  return ElectricalCircuitCalculationEngine.calculate(
    _calculationRequest(synthesis),
  );
}

ElectricalCircuitCalculationRequest _calculationRequest(
  ElectricalCircuitSynthesisResult synthesis,
) =>
    ElectricalCircuitCalculationRequest(
      synthesis: synthesis,
      policies: [
        for (final circuit in synthesis.circuits)
          _policy(
            circuit.id,
            nominalVoltageV:
                circuit.requiredPhaseSystem ==
                        ElectricalLoadPhaseSystem.singlePhaseAc
                    ? 230
                    : 400,
          ),
      ],
    );

ElectricalCircuitCalculationPolicy _policy(
  String circuitId, {
  double nominalVoltageV = 230,
  double diversity = 1,
  double reserve = 0,
}) =>
    ElectricalCircuitCalculationPolicy(
      circuitId: circuitId,
      nominalVoltageV: nominalVoltageV,
      diversityPolicy: ElectricalDiversityPolicy(
        id: 'diversity:$circuitId',
        factor: diversity,
        sourceId: 'qualification-policy',
        sourceRevision: 'r1',
      ),
      reservePolicy: ElectricalReservePolicy(
        id: 'reserve:$circuitId',
        reserveRatio: reserve,
        sourceId: 'qualification-policy',
        sourceRevision: 'r1',
      ),
      sourceId: 'qualification-circuit-policy',
      sourceRevision: 'r1',
    );

ElectricalCircuitSynthesisResult _synthesis(
  List<SynthesizedElectricalCircuit> circuits,
) =>
    ElectricalCircuitSynthesisResult(circuits: circuits);

SynthesizedElectricalCircuit _circuit(
  String id,
  ElectricalLoadPhaseSystem phaseSystem,
  List<ElectricalLoadInput> loads,
) =>
    SynthesizedElectricalCircuit(
      id: id,
      requiredPhaseSystem: phaseSystem,
      dedicated: false,
      loads: [
        for (final load in loads)
          CircuitSynthesisLoad(
            load: load,
            kind: ElectricalCircuitLoadKind.other,
            locationId: 'qualification',
            requiredPhaseSystem: phaseSystem,
          ),
      ],
      groupingPolicyId: 'grouping-policy',
      groupingPolicyRevision: 'r1',
      dedicatedPolicyId: 'dedicated-policy',
      dedicatedPolicyRevision: 'r1',
    );

ElectricalLoadInput _load(
  String id,
  int powerW, {
  double powerFactor = 1,
  ElectricalReactivePowerKind reactivePowerKind =
      ElectricalReactivePowerKind.lagging,
}) =>
    ElectricalLoadInput(
      id: id,
      ratedPowerW: powerW,
      quantity: 1,
      utilizationFactor: 1,
      powerFactor: powerFactor,
      reactivePowerKind: reactivePowerKind,
      sourceId: 'qualification-load',
      sourceRevision: 'r1',
    );

DistributionBoardPhase? _phaseOf(
  ElectricalPhaseAssignmentResult result,
  String circuitId,
) =>
    result.circuits.singleWhere((item) => item.id == circuitId).phase;
