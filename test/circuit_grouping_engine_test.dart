import 'package:elecx/src/domain/electrical_circuit_synthesis.dart';
import 'package:elecx/src/domain/electrical_load_calculation.dart';
import 'package:elecx/src/engine/circuit_grouping_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P9.5-D circuit grouping engine', () {
    test('Q01 synthesis is deterministic across input order', () {
      final loads = [
        _load('socket-a', 1200, ElectricalCircuitLoadKind.generalSocket,
            'room-a'),
        _load(
            'socket-b', 900, ElectricalCircuitLoadKind.generalSocket, 'room-b'),
        _load('light-a', 300, ElectricalCircuitLoadKind.lighting, 'room-a'),
      ];

      final first = CircuitGroupingEngine.synthesize(_request(loads));
      final second = CircuitGroupingEngine.synthesize(
        _request(loads.reversed.toList()),
      );

      expect(_signature(first), _signature(second));
    });

    test('Q02 dedicated policy isolates matching appliance', () {
      final result = CircuitGroupingEngine.synthesize(
        _request(
          [
            _load(
              'oven',
              3500,
              ElectricalCircuitLoadKind.cookingAppliance,
              'kitchen',
            ),
            _load(
              'socket-a',
              1200,
              ElectricalCircuitLoadKind.generalSocket,
              'kitchen',
            ),
          ],
          dedicatedPolicy: _dedicatedPolicy(
            rules: [
              DedicatedCircuitRule(
                id: 'dedicated-cooking',
                loadKinds: const [ElectricalCircuitLoadKind.cookingAppliance],
                sourceId: 'project-circuit-policy',
                sourceRevision: 'r1',
              ),
            ],
          ),
        ),
      );

      final ovenCircuit = result.circuits.singleWhere(
        (circuit) => circuit.loadIds.contains('oven'),
      );
      expect(ovenCircuit.dedicated, isTrue);
      expect(ovenCircuit.loadIds, ['oven']);
      expect(ovenCircuit.dedicatedRuleId, 'dedicated-cooking');
      expect(ovenCircuit.dedicatedPolicyId, 'dedicated-policy');
    });

    test('Q03 grouped circuits respect count and connected-power limits', () {
      final result = CircuitGroupingEngine.synthesize(
        _request(
          [
            _load('a', 1700, ElectricalCircuitLoadKind.generalSocket, 'room-a'),
            _load('b', 1600, ElectricalCircuitLoadKind.generalSocket, 'room-a'),
            _load('c', 900, ElectricalCircuitLoadKind.generalSocket, 'room-a'),
            _load('d', 800, ElectricalCircuitLoadKind.generalSocket, 'room-a'),
          ],
          groupingPolicy: _groupingPolicy(
            maxLoads: 2,
            maxPowerW: 2500,
          ),
        ),
      );

      expect(result.circuits, hasLength(2));
      for (final circuit in result.circuits) {
        expect(circuit.loads.length, lessThanOrEqualTo(2));
        expect(circuit.connectedPowerW, lessThanOrEqualTo(2500));
      }
      expect(
        result.circuits.map((circuit) => circuit.loadIds).toList(),
        [
          ['a', 'd'],
          ['b', 'c'],
        ],
      );
    });

    test('Q04 engine has no hidden dedicated appliance defaults', () {
      final result = CircuitGroupingEngine.synthesize(
        _request(
          [
            _load(
              'oven',
              3000,
              ElectricalCircuitLoadKind.cookingAppliance,
              'kitchen',
            ),
            _load(
              'dishwasher',
              1000,
              ElectricalCircuitLoadKind.dishwasher,
              'kitchen',
            ),
          ],
          groupingPolicy: _groupingPolicy(
            maxLoads: 4,
            maxPowerW: 5000,
            separateByKind: false,
          ),
          dedicatedPolicy: _dedicatedPolicy(),
        ),
      );

      expect(result.circuits, hasLength(1));
      expect(result.circuits.single.dedicated, isFalse);
      expect(result.circuits.single.loadIds, ['dishwasher', 'oven']);
    });

    test('Q05 location separation is controlled only by policy', () {
      final loads = [
        _load(
            'socket-a', 500, ElectricalCircuitLoadKind.generalSocket, 'room-a'),
        _load(
            'socket-b', 500, ElectricalCircuitLoadKind.generalSocket, 'room-b'),
      ];

      final separated = CircuitGroupingEngine.synthesize(
        _request(
          loads,
          groupingPolicy: _groupingPolicy(separateByLocation: true),
        ),
      );
      final combined = CircuitGroupingEngine.synthesize(
        _request(
          loads,
          groupingPolicy: _groupingPolicy(separateByLocation: false),
        ),
      );

      expect(separated.circuits, hasLength(2));
      expect(combined.circuits, hasLength(1));
    });

    test('Q06 phase systems are never mixed in one circuit', () {
      final result = CircuitGroupingEngine.synthesize(
        _request(
          [
            _load('single', 1000, ElectricalCircuitLoadKind.other, 'plant'),
            _load(
              'three',
              1000,
              ElectricalCircuitLoadKind.other,
              'plant',
              phaseSystem: ElectricalLoadPhaseSystem.threePhaseAc,
            ),
          ],
          groupingPolicy: _groupingPolicy(separateByKind: false),
        ),
      );

      expect(result.circuits, hasLength(2));
      expect(
        result.circuits.map((circuit) => circuit.requiredPhaseSystem).toSet(),
        {
          ElectricalLoadPhaseSystem.singlePhaseAc,
          ElectricalLoadPhaseSystem.threePhaseAc,
        },
      );
    });

    test('Q07 unmatched oversized grouped load fails closed', () {
      expect(
        () => CircuitGroupingEngine.synthesize(
          _request(
            [
              _load(
                'large-load',
                6000,
                ElectricalCircuitLoadKind.fixedAppliance,
                'plant',
              ),
            ],
            groupingPolicy: _groupingPolicy(maxPowerW: 5000),
            dedicatedPolicy: _dedicatedPolicy(),
          ),
        ),
        throwsStateError,
      );
    });

    test('Q08 policy provenance is retained on every circuit', () {
      final result = CircuitGroupingEngine.synthesize(
        _request(
          [
            _load('a', 500, ElectricalCircuitLoadKind.lighting, 'room-a'),
          ],
        ),
      );

      final circuit = result.circuits.single;
      expect(circuit.groupingPolicyId, 'grouping-policy');
      expect(circuit.groupingPolicyRevision, 'r1');
      expect(circuit.dedicatedPolicyId, 'dedicated-policy');
      expect(circuit.dedicatedPolicyRevision, 'r1');
    });
  });
}

ElectricalCircuitSynthesisRequest _request(
  List<CircuitSynthesisLoad> loads, {
  CircuitGroupingPolicy? groupingPolicy,
  DedicatedCircuitPolicy? dedicatedPolicy,
}) =>
    ElectricalCircuitSynthesisRequest(
      loads: loads,
      groupingPolicy: groupingPolicy ?? _groupingPolicy(),
      dedicatedCircuitPolicy: dedicatedPolicy ?? _dedicatedPolicy(),
    );

CircuitGroupingPolicy _groupingPolicy({
  int maxLoads = 8,
  int maxPowerW = 5000,
  bool separateByLocation = false,
  bool separateByKind = true,
}) =>
    CircuitGroupingPolicy(
      id: 'grouping-policy',
      maxGroupedLoadsPerCircuit: maxLoads,
      maxGroupedConnectedPowerW: maxPowerW,
      separateByLocation: separateByLocation,
      separateByLoadKind: separateByKind,
      sourceId: 'project-circuit-policy',
      sourceRevision: 'r1',
    );

DedicatedCircuitPolicy _dedicatedPolicy({
  List<DedicatedCircuitRule> rules = const [],
}) =>
    DedicatedCircuitPolicy(
      id: 'dedicated-policy',
      rules: rules,
      sourceId: 'project-circuit-policy',
      sourceRevision: 'r1',
    );

CircuitSynthesisLoad _load(
  String id,
  int powerW,
  ElectricalCircuitLoadKind kind,
  String locationId, {
  ElectricalLoadPhaseSystem phaseSystem =
      ElectricalLoadPhaseSystem.singlePhaseAc,
}) =>
    CircuitSynthesisLoad(
      load: ElectricalLoadInput(
        id: id,
        ratedPowerW: powerW,
        quantity: 1,
        utilizationFactor: 1,
        powerFactor: 1,
        reactivePowerKind: ElectricalReactivePowerKind.lagging,
        sourceId: 'qualification-loads',
        sourceRevision: 'r1',
      ),
      kind: kind,
      locationId: locationId,
      requiredPhaseSystem: phaseSystem,
    );

List<String> _signature(ElectricalCircuitSynthesisResult result) => [
      for (final circuit in result.circuits)
        '${circuit.id}:${circuit.dedicated}:${circuit.requiredPhaseSystem.name}:'
            '${circuit.loadIds.join(',')}:${circuit.dedicatedRuleId ?? '-'}',
    ];
