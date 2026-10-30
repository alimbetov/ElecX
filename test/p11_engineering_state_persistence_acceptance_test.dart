import 'dart:convert';
import 'dart:io';

import 'package:elecx/src/application/project/project_snapshot.dart';
import 'package:elecx/src/domain/canonical_engineering_graph.dart';
import 'package:elecx/src/domain/engineering_circuit_topology.dart';
import 'package:elecx/src/domain/engineering_graph.dart';
import 'package:elecx/src/domain/engineering_project_state.dart';
import 'package:elecx/src/domain/engineering_project_state_semantics.dart';
import 'package:elecx/src/domain/engineering_supply_topology.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_orientation.dart';
import 'package:elecx/src/infrastructure/project/json_project_repository.dart';
import 'package:elecx/src/serialization/project/engineering_state_aware_canonical_project_document_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'production repository persists and reopens canonical P11 engineering state',
    () async {
      final root =
          await Directory.systemTemp.createTemp('elecx-p11-persistence-');
      addTearDown(() async {
        if (await root.exists()) {
          await root.delete(recursive: true);
        }
      });

      final snapshot = _snapshot();
      final before = snapshot.aggregate.engineeringMetadata.engineeringState;
      expect(before.isEmpty, isFalse);

      final writer = JsonProjectRepository(
        rootDirectory: root,
        codec: const EngineeringStateAwareCanonicalProjectDocumentCodec(),
      );
      await writer.save(snapshot);

      final projectFile = await root
          .list()
          .where(
            (entity) =>
                entity is File && entity.path.endsWith('.elecx.project.json'),
          )
          .cast<File>()
          .single;
      final envelope =
          jsonDecode(await projectFile.readAsString()) as Map<String, dynamic>;
      expect(
        envelope['schemaVersion'],
        EngineeringStateAwareCanonicalProjectDocumentCodec.schemaVersion,
      );
      expect(envelope['schemaVersion'], 20);

      final reopenedRepository = JsonProjectRepository(
        rootDirectory: root,
        codec: const EngineeringStateAwareCanonicalProjectDocumentCodec(),
      );
      final reopened = await reopenedRepository.load(snapshot.aggregate.id);

      expect(reopened, isNotNull);
      final after = reopened!.aggregate.engineeringMetadata.engineeringState;
      expect(after.fingerprint, before.fingerprint);
      expect(
        EngineeringProjectStateDiff.between(before, after).isEmpty,
        isTrue,
      );
    },
  );
}

ProjectSnapshot _snapshot() {
  final projectId = ProjectId('p11-persistence-project');
  final siteId = SiteId('p11-persistence-site');
  final state = _engineeringState();
  return ProjectSnapshot(
    aggregate: ProjectAggregateRoot(
      id: projectId,
      siteId: siteId,
      version: LocalProjectVersion(11),
      engineeringMetadata: ProjectEngineeringMetadata(
        engineeringState: state,
      ),
      stores: ProjectEntityStores(
        sites: {
          siteId: ProjectSiteEntity(
            id: siteId,
            name: 'P11 persistence site',
            buildingIds: const [],
          ),
        },
      ),
    ),
    name: 'P11 persistence acceptance',
    createdAt: DateTime.utc(2026, 10, 30, 6),
    updatedAt: DateTime.utc(2026, 10, 30, 7),
  );
}

EngineeringProjectState _engineeringState() {
  final sourceId = ComponentId('source');
  final loadId = ComponentId('load');
  final connectionId = EngineeringConnectionId('feed');
  final circuitId = CircuitId('circuit');

  final source = EngineeringGraphComponent(
    id: sourceId,
    componentTypeId: 'catalog.source',
    discipline: EngineeringDiscipline.power,
    systemClass: EngineeringSystemClass.powerAc,
    ratedPowerW: 0,
    voltageV: 230,
    ports: [
      EngineeringPortSpec.identified(
        portId: PortId('out'),
        direction: EngineeringPortDirection.output,
        allowedConnections: {
          EngineeringConnectionType.acSinglePhase,
        },
        media: {EngineeringMedia.acPower},
      ),
    ],
  );
  final load = EngineeringGraphComponent(
    id: loadId,
    componentTypeId: 'catalog.load',
    discipline: EngineeringDiscipline.power,
    systemClass: EngineeringSystemClass.powerAc,
    ratedPowerW: 1200,
    voltageV: 230,
    ports: [
      EngineeringPortSpec.identified(
        portId: PortId('in'),
        direction: EngineeringPortDirection.input,
        allowedConnections: {
          EngineeringConnectionType.acSinglePhase,
        },
        media: {EngineeringMedia.acPower},
      ),
    ],
  );
  final connection = EngineeringGraphConnection(
    id: connectionId,
    fromComponentId: sourceId,
    fromPortId: PortId('out'),
    toComponentId: loadId,
    toPortId: PortId('in'),
    connectionType: EngineeringConnectionType.acSinglePhase,
    systemClass: EngineeringSystemClass.powerAc,
    media: EngineeringMedia.acPower,
    circuitId: circuitId,
  );
  final graph = CanonicalEngineeringGraph(
    components: [source, load],
    connections: [connection],
  );
  final circuit = EngineeringCircuit(
    id: circuitId,
    systemClass: EngineeringSystemClass.powerAc,
    media: EngineeringMedia.acPower,
    connectionIds: [connectionId],
  );
  final supplySource = EngineeringSupplySource(
    id: EngineeringSupplySourceId('source-id'),
    endpoint: EngineeringPortRef(
      componentId: sourceId,
      portId: PortId('out'),
    ),
    systemClass: EngineeringSystemClass.powerAc,
    media: EngineeringMedia.acPower,
  );

  return EngineeringProjectState(
    graph: graph,
    circuits: [circuit],
    sources: [supplySource],
    circuitSupplies: [
      EngineeringCircuitSupply(
        circuitId: circuitId,
        sourceIds: [supplySource.id],
      ),
    ],
  );
}
