import 'package:elecx/src/domain/component_catalog_engineering_metadata.dart';
import 'package:elecx/src/domain/component_catalog_v2.dart';
import 'package:elecx/src/domain/component_placement.dart';
import 'package:elecx/src/domain/electrical_circuit_synthesis.dart';
import 'package:elecx/src/domain/electrical_load_calculation.dart';
import 'package:elecx/src/domain/engineering_graph.dart';
import 'package:elecx/src/domain/power_board_catalog_qualification.dart';
import 'package:elecx/src/domain/power_starter_generation.dart';
import 'package:elecx/src/engine/power_starter_board_catalog_engine.dart';
import 'package:elecx/src/engine/power_starter_generation_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P12A.6 source-pinned board catalog qualification', () {
    test('qualified board type resolves catalog selection but not electrical ratings',
        () {
      final candidate = _candidate();
      final result = _qualify(candidate, _registry());

      expect(result.status, PowerBoardCatalogStatus.qualifiedForPreview);
      expect(result.hasQualifiedBoardType, isTrue);
      expect(result.record?.entry.id, 'power.distribution-board.general');
      expect(result.record?.metadata.source?.model, 'DB-TEST');
      expect(
        result.remainingStarterIssues
            .any((issue) =>
                issue.code ==
                PowerStarterIssueCode.boardCatalogSelectionRequired),
        isFalse,
      );
      expect(result.remainingStarterIssues, hasLength(3));
      expect(result.engineeringIssues, [
        PowerBoardEngineeringIssue.boardElectricalRatingsNotProven,
      ]);
      expect(result.readyToApply, isFalse);
      expect(candidate.readyToApply, isFalse);
    });

    test('catalog snapshot mismatch never binds a stale record', () {
      final result = _qualify(
        _candidate(),
        _registry(),
        catalogSnapshotId: 'catalog-old',
      );
      expect(result.status, PowerBoardCatalogStatus.snapshotMismatch);
      expect(result.record, isNull);
      expect(result.remainingStarterIssues, hasLength(4));
      expect(
        result.engineeringIssues,
        contains(PowerBoardEngineeringIssue.catalogBoardNotQualified),
      );
    });

    test('unknown component, wrong host, wrong media and socket fail closed',
        () {
      final candidate = _candidate();
      expect(
        _qualify(candidate, _registry(), componentTypeId: 'missing').status,
        PowerBoardCatalogStatus.componentMissing,
      );
      expect(
        _qualify(
          candidate,
          _registry(),
          hostKind: ComponentHostKind.site,
        ).status,
        PowerBoardCatalogStatus.incompatible,
      );
      expect(
        _qualify(
          candidate,
          _registry(),
          connectionType: EngineeringConnectionType.poe,
        ).status,
        PowerBoardCatalogStatus.incompatible,
      );
      final sockets = ComponentCatalogEngineeringRegistry([
        _record(componentTypeId: 'power.socket.general'),
      ]);
      expect(
        _qualify(
          candidate,
          sockets,
          componentTypeId: 'power.socket.general',
        ).status,
        PowerBoardCatalogStatus.incompatible,
      );
      // Junction boxes also expose AC input/output, but are not boards.
      final junctions = ComponentCatalogEngineeringRegistry([
        _record(componentTypeId: 'power.junction-box.general'),
      ]);
      expect(
        _qualify(
          candidate,
          junctions,
          componentTypeId: 'power.junction-box.general',
        ).status,
        PowerBoardCatalogStatus.incompatible,
      );
    });

    test('missing source or envelope facts prevents auto-qualified catalog type',
        () {
      final candidate = _candidate();
      for (final unverified in [
        _registry(sourceReady: false),
        _registry(envelopeReady: false),
      ]) {
        final result = _qualify(candidate, unverified);
        expect(result.status, PowerBoardCatalogStatus.missingSourceFacts);
        expect(result.record, isNull);
        expect(result.readyToApply, isFalse);
      }
    });

    test('source revision changes catalog qualification fingerprint', () {
      final candidate = _candidate();
      final before = _qualify(candidate, _registry(sourceRevision: 'r1'));
      final after = _qualify(candidate, _registry(sourceRevision: 'r2'));
      expect(before.status, PowerBoardCatalogStatus.qualifiedForPreview);
      expect(after.status, PowerBoardCatalogStatus.qualifiedForPreview);
      expect(after.fingerprint, isNot(before.fingerprint));
      expect(after.candidate.fingerprint, before.candidate.fingerprint);
    });
  });
}

PowerBoardCatalogQualification _qualify(
  PowerStarterCandidate candidate,
  ComponentCatalogEngineeringRegistry registry, {
  String catalogSnapshotId = 'catalog-v1',
  String componentTypeId = 'power.distribution-board.general',
  EngineeringConnectionType connectionType =
      EngineeringConnectionType.acSinglePhase,
  ComponentHostKind hostKind = ComponentHostKind.roomSurface,
}) =>
    PowerStarterBoardCatalogEngine.qualify(
      candidate: candidate,
      catalogSnapshotId: catalogSnapshotId,
      registry: registry,
      componentTypeId: componentTypeId,
      connectionType: connectionType,
      hostKind: hostKind,
    );

ComponentCatalogEngineeringRegistry _registry({
  String sourceRevision = 'r1',
  bool sourceReady = true,
  bool envelopeReady = true,
}) =>
    ComponentCatalogEngineeringRegistry([
      _record(
        sourceRevision: sourceRevision,
        sourceReady: sourceReady,
        envelopeReady: envelopeReady,
      ),
    ]);

ComponentCatalogEngineeringRecord _record({
  String componentTypeId = 'power.distribution-board.general',
  String sourceRevision = 'r1',
  bool sourceReady = true,
  bool envelopeReady = true,
}) {
  final entry = ComponentCatalogV2.require(componentTypeId);
  return ComponentCatalogEngineeringRecord(
    entry: entry,
    metadata: ComponentCatalogEngineeringMetadata(
      componentTypeId: entry.id,
      compatibility: ComponentCompatibilityProfile(
        systems: const {EngineeringSystemClass.powerAc},
        connections: const {
          EngineeringConnectionType.acSinglePhase,
          EngineeringConnectionType.acThreePhase,
        },
        hostKinds: const {ComponentHostKind.roomSurface},
      ),
      physicalEnvelope: envelopeReady
          ? ComponentPhysicalEnvelopeMm(
              widthMm: 400,
              heightMm: 300,
              depthMm: 150,
            )
          : null,
      source: sourceReady
          ? ComponentCatalogSourceMetadata(
              manufacturer: 'Test Fixture',
              model: 'DB-TEST',
              revision: sourceRevision,
            )
          : null,
    ),
  );
}

PowerStarterCandidate _candidate() {
  final request = PowerStarterGenerationRequest(
    projectId: 'project-100',
    boardGenerationKey: 'power:board:unit-100',
    catalogSnapshotId: 'catalog-v1',
    voltageEvidenceId: 'site-supply',
    voltageEvidenceRevision: 'v1',
    nominalVoltageV: 230,
    loads: const [
      CircuitSynthesisLoad(
        load: ElectricalLoadInput(
          id: 'socket-1',
          ratedPowerW: 1500,
          quantity: 1,
          utilizationFactor: 1,
          powerFactor: 1,
          reactivePowerKind: ElectricalReactivePowerKind.lagging,
          sourceId: 'catalog-fixture',
          sourceRevision: 'r1',
        ),
        kind: ElectricalCircuitLoadKind.generalSocket,
        locationId: 'room-100',
        requiredPhaseSystem: ElectricalLoadPhaseSystem.singlePhaseAc,
      ),
    ],
    groupingPolicy: CircuitGroupingPolicy(
      id: 'g1',
      maxGroupedLoadsPerCircuit: 3,
      maxGroupedConnectedPowerW: 3000,
      separateByLocation: false,
      separateByLoadKind: true,
      sourceId: 'profile',
      sourceRevision: 'r1',
    ),
    dedicatedCircuitPolicy: DedicatedCircuitPolicy(
      id: 'd1',
      rules: const [],
      sourceId: 'profile',
      sourceRevision: 'r1',
    ),
    diversityPolicy: const ElectricalDiversityPolicy(
      id: 'diversity',
      factor: 1,
      sourceId: 'profile',
      sourceRevision: 'r1',
    ),
    reservePolicy: ElectricalReservePolicy.none,
  );
  return PowerStarterGenerationEngine.generate(request);
}
