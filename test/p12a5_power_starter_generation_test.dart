import 'package:elecx/src/domain/electrical_circuit_synthesis.dart';
import 'package:elecx/src/domain/electrical_load_calculation.dart';
import 'package:elecx/src/domain/power_starter_generation.dart';
import 'package:elecx/src/engine/power_starter_generation_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P12A.5 ID-free POWER starter generation', () {
    test(
        'produces dedicated and grouped circuits with explicit P/Q/S/I evidence',
        () {
      final candidate = PowerStarterGenerationEngine.generate(_request());

      expect(candidate.circuits, hasLength(2));
      expect(candidate.connectedPowerW, 8500);
      expect(candidate.designPowerW, closeTo(8500, 0.00001));
      expect(candidate.circuits.map((item) => item.generationKey).toSet(),
          hasLength(2));
      expect(
          candidate.circuits
              .every((item) => item.generationKey.startsWith('power:circuit:')),
          isTrue);
      expect(
        candidate.circuits
            .singleWhere((c) => c.calculated.circuit.dedicated)
            .loadIds,
        ['oven'],
      );
      expect(
        candidate.circuits
            .singleWhere((c) => !c.calculated.circuit.dedicated)
            .loadIds,
        ['socket-a', 'socket-b'],
      );
      final sumCurrent = candidate.circuits.fold<double>(
        0,
        (sum, item) => sum + item.calculated.calculation.designCurrentA,
      );
      expect(sumCurrent, closeTo(8500 / 230, 0.00001));
      expect(candidate.readyToApply, isFalse);
      expect(
        candidate.issues.map((issue) => issue.code),
        containsAll(PowerStarterIssueCode.values),
      );
      expect(candidate.issues, hasLength(4));
    });

    test('request order does not change identities or semantic fingerprint',
        () {
      final first = PowerStarterGenerationEngine.generate(_request());
      final reversed =
          PowerStarterGenerationEngine.generate(_request(reverse: true));
      expect(reversed.fingerprint, first.fingerprint);
      expect(
        reversed.circuits.map((item) => item.generationKey).toList(),
        first.circuits.map((item) => item.generationKey).toList(),
      );
    });

    test('catalog and policy revision changes invalidate evidence fingerprint',
        () {
      final original = PowerStarterGenerationEngine.generate(_request());
      final newCatalog = PowerStarterGenerationEngine.generate(
        _request(catalogSnapshotId: 'catalog-v2'),
      );
      final newPolicy = PowerStarterGenerationEngine.generate(
        _request(groupingRevision: 'v2'),
      );
      expect(newCatalog.fingerprint, isNot(original.fingerprint));
      expect(newPolicy.fingerprint, isNot(original.fingerprint));
      expect(
        newPolicy.circuits.map((item) => item.generationKey),
        original.circuits.map((item) => item.generationKey),
      );
    });

    test('incomplete identity and duplicate load IDs fail closed', () {
      expect(
        () => _request(boardGenerationKey: ' '),
        throwsArgumentError,
      );
      expect(
        () => _request(nominalVoltageV: 0),
        throwsArgumentError,
      );
      expect(
        () => _request(duplicateLoad: true),
        throwsArgumentError,
      );
    });
  });
}

PowerStarterGenerationRequest _request({
  bool reverse = false,
  bool duplicateLoad = false,
  String boardGenerationKey = 'power:board:unit-101',
  String catalogSnapshotId = 'catalog-v1',
  String groupingRevision = 'v1',
  double nominalVoltageV = 230,
}) {
  final loads = <CircuitSynthesisLoad>[
    _load('socket-a', 1000, ElectricalCircuitLoadKind.generalSocket),
    _load('socket-b', 1500, ElectricalCircuitLoadKind.generalSocket),
    _load('oven', 6000, ElectricalCircuitLoadKind.cookingAppliance),
  ];
  if (duplicateLoad) loads.add(loads.first);
  if (reverse) loads.reverse();

  return PowerStarterGenerationRequest(
    projectId: 'project-101',
    boardGenerationKey: boardGenerationKey,
    catalogSnapshotId: catalogSnapshotId,
    voltageEvidenceId: 'project-supply',
    voltageEvidenceRevision: 'supply-v1',
    nominalVoltageV: nominalVoltageV,
    loads: loads,
    groupingPolicy: CircuitGroupingPolicy(
      id: 'grouping-policy',
      maxGroupedLoadsPerCircuit: 2,
      maxGroupedConnectedPowerW: 3000,
      separateByLocation: false,
      separateByLoadKind: true,
      sourceId: 'engineering-profile',
      sourceRevision: groupingRevision,
    ),
    dedicatedCircuitPolicy: DedicatedCircuitPolicy(
      id: 'dedicated-policy',
      rules: [
        DedicatedCircuitRule(
          id: 'dedicated-oven',
          loadKinds: const [ElectricalCircuitLoadKind.cookingAppliance],
          sourceId: 'engineering-profile',
          sourceRevision: 'v1',
        ),
      ],
      sourceId: 'engineering-profile',
      sourceRevision: 'v1',
    ),
    diversityPolicy: const ElectricalDiversityPolicy(
      id: 'explicit-diversity',
      factor: 1,
      sourceId: 'engineering-profile',
      sourceRevision: 'v1',
    ),
    reservePolicy: ElectricalReservePolicy.none,
  );
}

CircuitSynthesisLoad _load(
  String id,
  int powerW,
  ElectricalCircuitLoadKind kind,
) =>
    CircuitSynthesisLoad(
      load: ElectricalLoadInput(
        id: id,
        ratedPowerW: powerW,
        quantity: 1,
        utilizationFactor: 1,
        powerFactor: 1,
        reactivePowerKind: ElectricalReactivePowerKind.lagging,
        sourceId: 'catalog-test-fixture',
        sourceRevision: 'v1',
      ),
      kind: kind,
      locationId: 'room-101',
      requiredPhaseSystem: ElectricalLoadPhaseSystem.singlePhaseAc,
    );
