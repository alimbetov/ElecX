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
  group('P11.10 adversarial production persistence qualification', () {
    test('rejects truncated project JSON instead of reopening partial state',
        () async {
      final saved = await _saveFixture();
      addTearDown(saved.dispose);

      await saved.projectFile.writeAsString(
        '{"schemaVersion":20,"payload":',
        flush: true,
      );

      await expectLater(
        _repository(saved.root).load(saved.snapshot.aggregate.id),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects dangling engineering component references', () async {
      final saved = await _saveFixture();
      addTearDown(saved.dispose);

      final envelope = await _readEnvelope(saved.projectFile);
      final graph = _engineeringState(envelope)['graph'] as Map<String, dynamic>;
      final connections = graph['connections'] as List<dynamic>;
      final connection = connections.single as Map<String, dynamic>;
      connection['toComponentId'] = 'missing-component';
      await _writeEnvelope(saved.projectFile, envelope);

      await expectLater(
        _repository(saved.root).load(saved.snapshot.aggregate.id),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects duplicate canonical engineering identities', () async {
      final saved = await _saveFixture();
      addTearDown(saved.dispose);

      final envelope = await _readEnvelope(saved.projectFile);
      final graph = _engineeringState(envelope)['graph'] as Map<String, dynamic>;
      final components = graph['components'] as List<dynamic>;
      components.add(_cloneMap(components.first as Map<String, dynamic>));
      await _writeEnvelope(saved.projectFile, envelope);

      await expectLater(
        _repository(saved.root).load(saved.snapshot.aggregate.id),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects invalid circuit topology membership', () async {
      final saved = await _saveFixture();
      addTearDown(saved.dispose);

      final envelope = await _readEnvelope(saved.projectFile);
      final circuits = _engineeringState(envelope)['circuits'] as List<dynamic>;
      final circuit = circuits.single as Map<String, dynamic>;
      circuit['connectionIds'] = <Object?>['missing-connection'];
      await _writeEnvelope(saved.projectFile, envelope);

      await expectLater(
        _repository(saved.root).load(saved.snapshot.aggregate.id),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects envelope and engineering aggregate schema tampering',
        () async {
      final saved = await _saveFixture();
      addTearDown(saved.dispose);
      final canonicalBytes = await saved.projectFile.readAsString();

      final envelope = await _readEnvelope(saved.projectFile);
      envelope['schemaVersion'] =
          EngineeringStateAwareCanonicalProjectDocumentCodec.schemaVersion + 1;
      await _writeEnvelope(saved.projectFile, envelope);

      await expectLater(
        _repository(saved.root).load(saved.snapshot.aggregate.id),
        throwsA(isA<FormatException>()),
      );

      await saved.projectFile.writeAsString(canonicalBytes, flush: true);
      final aggregateTamper = await _readEnvelope(saved.projectFile);
      _engineeringState(aggregateTamper)['schemaVersion'] = 2;
      await _writeEnvelope(saved.projectFile, aggregateTamper);

      await expectLater(
        _repository(saved.root).load(saved.snapshot.aggregate.id),
        throwsA(isA<FormatException>()),
      );
    });

    test('normalizes collection order without semantic or byte drift',
        () async {
      final saved = await _saveFixture();
      addTearDown(saved.dispose);
      final canonicalBytes = await saved.projectFile.readAsString();
      final before =
          saved.snapshot.aggregate.engineeringMetadata.engineeringState;

      final envelope = await _readEnvelope(saved.projectFile);
      final graph = _engineeringState(envelope)['graph'] as Map<String, dynamic>;
      final components = graph['components'] as List<dynamic>;
      graph['components'] = components.reversed.toList();
      await _writeEnvelope(saved.projectFile, envelope);

      final reopened =
          await _repository(saved.root).load(saved.snapshot.aggregate.id);
      expect(reopened, isNotNull);
      final after = reopened!.aggregate.engineeringMetadata.engineeringState;
      expect(after.fingerprint, before.fingerprint);
      expect(EngineeringProjectStateDiff.between(before, after).isEmpty, isTrue);

      await _repository(saved.root).save(reopened);
      expect(await saved.projectFile.readAsString(), canonicalBytes);
    });

    test('repeated save and fresh-repository reopen remains drift free',
        () async {
      final saved = await _saveFixture();
      addTearDown(saved.dispose);
      final before =
          saved.snapshot.aggregate.engineeringMetadata.engineeringState;
      final canonicalBytes = await saved.projectFile.readAsString();

      for (var cycle = 1; cycle <= 5; cycle++) {
        final reopened =
            await _repository(saved.root).load(saved.snapshot.aggregate.id);
        expect(reopened, isNotNull, reason: 'reopen cycle $cycle');

        final after = reopened!.aggregate.engineeringMetadata.engineeringState;
        expect(
          after.fingerprint,
          before.fingerprint,
          reason: 'fingerprint cycle $cycle',
        );
        expect(
          EngineeringProjectStateDiff.between(before, after).isEmpty,
          isTrue,
          reason: 'semantic diff cycle $cycle',
        );

        final envelope = await _readEnvelope(saved.projectFile);
        expect(
          envelope['schemaVersion'],
          EngineeringStateAwareCanonicalProjectDocumentCodec.schemaVersion,
          reason: 'schema cycle $cycle',
        );
        expect(envelope['schemaVersion'], 20, reason: 'schema cycle $cycle');

        // Use another repository instance for the write so every cycle proves
        // the durable contract rather than relying on repository object state.
        await _repository(saved.root).save(reopened);
        expect(
          await saved.projectFile.readAsString(),
          canonicalBytes,
          reason: 'canonical bytes cycle $cycle',
        );
      }
    });
  });
}

JsonProjectRepository _repository(Directory root) => JsonProjectRepository(
      rootDirectory: root,
      codec: const EngineeringStateAwareCanonicalProjectDocumentCodec(),
    );

Future<_SavedFixture> _saveFixture() async {
  final root = await Directory.systemTemp.createTemp('elecx-p11-adversarial-');
  final snapshot = _snapshot();
  await _repository(root).save(snapshot);
  final projectFile = await root
      .list()
      .where(
        (entity) => entity is File && entity.path.endsWith('.elecx.project.json'),
      )
      .cast<File>()
      .single;
  return _SavedFixture(root: root, snapshot: snapshot, projectFile: projectFile);
}

Future<Map<String, dynamic>> _readEnvelope(File file) async =>
    jsonDecode(await file.readAsString()) as Map<String, dynamic>;

Future<void> _writeEnvelope(
  File file,
  Map<String, dynamic> envelope,
) =>
    file.writeAsString(jsonEncode(envelope), flush: true);

Map<String, dynamic> _engineeringState(Map<String, dynamic> envelope) {
  final payload = envelope['payload'] as Map<String, dynamic>;
  return payload['engineeringState'] as Map<String, dynamic>;
}

Map<String, dynamic> _cloneMap(Map<String, dynamic> value) =>
    jsonDecode(jsonEncode(value)) as Map<String, dynamic>;

final class _SavedFixture {
  const _SavedFixture({
    required this.root,
    required this.snapshot,
    required this.projectFile,
  });

  final Directory root;
  final ProjectSnapshot snapshot;
  final File projectFile;

  Future<void> dispose() async {
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  }
}

ProjectSnapshot _snapshot() {
  final projectId = ProjectId('p11-adversarial-project');
  final siteId = SiteId('p11-adversarial-site');
  return ProjectSnapshot(
    aggregate: ProjectAggregateRoot(
      id: projectId,
      siteId: siteId,
      version: LocalProjectVersion(11),
      engineeringMetadata: ProjectEngineeringMetadata(
        engineeringState: _engineeringStateFixture(),
      ),
      stores: ProjectEntityStores(
        sites: {
          siteId: ProjectSiteEntity(
            id: siteId,
            name: 'P11 adversarial site',
            buildingIds: const [],
          ),
        },
      ),
    ),
    name: 'P11 adversarial qualification',
    createdAt: DateTime.utc(2026, 10, 30, 8),
    updatedAt: DateTime.utc(2026, 10, 30, 9),
  );
}

EngineeringProjectState _engineeringStateFixture() {
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
        allowedConnections: {EngineeringConnectionType.acSinglePhase},
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
        allowedConnections: {EngineeringConnectionType.acSinglePhase},
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
