import 'package:elecx/src/domain/canonical_engineering_graph.dart';
import 'package:elecx/src/domain/engineering_circuit_topology.dart';
import 'package:elecx/src/domain/engineering_graph.dart';
import 'package:elecx/src/domain/engineering_supply_topology.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

EngineeringGraphComponent _sourceComponent(String id) =>
    EngineeringGraphComponent(
      id: ComponentId(id),
      componentTypeId: 'p11.supply-source',
      discipline: EngineeringDiscipline.power,
      systemClass: EngineeringSystemClass.powerAc,
      ports: [
        EngineeringPortSpec.identified(
          portId: PortId('out'),
          direction: EngineeringPortDirection.output,
          allowedConnections: {EngineeringConnectionType.acSinglePhase},
          media: {EngineeringMedia.acPower},
        ),
      ],
    );

EngineeringGraphComponent _board() => EngineeringGraphComponent(
      id: ComponentId('board'),
      componentTypeId: 'p11.distribution-node',
      discipline: EngineeringDiscipline.power,
      systemClass: EngineeringSystemClass.powerAc,
      ports: [
        EngineeringPortSpec.identified(
          portId: PortId('in'),
          direction: EngineeringPortDirection.input,
          allowedConnections: {EngineeringConnectionType.acSinglePhase},
          media: {EngineeringMedia.acPower},
        ),
        EngineeringPortSpec.identified(
          portId: PortId('out'),
          direction: EngineeringPortDirection.output,
          allowedConnections: {EngineeringConnectionType.acSinglePhase},
          media: {EngineeringMedia.acPower},
        ),
      ],
    );

EngineeringGraphComponent _load() => EngineeringGraphComponent(
      id: ComponentId('load'),
      componentTypeId: 'p11.load',
      discipline: EngineeringDiscipline.power,
      systemClass: EngineeringSystemClass.powerAc,
      ports: [
        EngineeringPortSpec.identified(
          portId: PortId('in'),
          direction: EngineeringPortDirection.input,
          allowedConnections: {EngineeringConnectionType.acSinglePhase},
          media: {EngineeringMedia.acPower},
        ),
      ],
    );

EngineeringGraphConnection _connection(
  String id,
  String from,
  String fromPort,
  String to,
  String toPort, {
  CircuitId? circuitId,
}) =>
    EngineeringGraphConnection(
      id: EngineeringConnectionId(id),
      fromComponentId: ComponentId(from),
      fromPortId: PortId(fromPort),
      toComponentId: ComponentId(to),
      toPortId: PortId(toPort),
      connectionType: EngineeringConnectionType.acSinglePhase,
      systemClass: EngineeringSystemClass.powerAc,
      media: EngineeringMedia.acPower,
      circuitId: circuitId,
    );

({CanonicalEngineeringTopology topology, EngineeringCircuit circuit})
    _fixture() {
  final circuitId = CircuitId('circuit-main');
  final graph = CanonicalEngineeringGraph(
    components: [
      _sourceComponent('source-a'),
      _sourceComponent('source-b'),
      _board(),
      _load(),
    ],
    connections: [
      _connection('a-board', 'source-a', 'out', 'board', 'in'),
      _connection('b-board', 'source-b', 'out', 'board', 'in'),
      _connection(
        'board-load',
        'board',
        'out',
        'load',
        'in',
        circuitId: circuitId,
      ),
    ],
  );
  final circuit = EngineeringCircuit(
    id: circuitId,
    systemClass: EngineeringSystemClass.powerAc,
    media: EngineeringMedia.acPower,
    connectionIds: [EngineeringConnectionId('board-load')],
  );
  return (
    topology: CanonicalEngineeringTopology(
      graph: graph,
      circuits: [circuit],
    ),
    circuit: circuit,
  );
}

EngineeringSupplySource _source(
  String id,
  String componentId, {
  EngineeringSupplyRoleKey? role,
  ServiceEntryId? serviceEntryId,
}) =>
    EngineeringSupplySource(
      id: EngineeringSupplySourceId(id),
      endpoint: EngineeringPortRef(
        componentId: ComponentId(componentId),
        portId: PortId('out'),
      ),
      systemClass: EngineeringSystemClass.powerAc,
      media: EngineeringMedia.acPower,
      role: role,
      serviceEntryId: serviceEntryId,
    );

void main() {
  test('P11.6 one circuit accepts multiple canonical supply sources', () {
    final fixture = _fixture();
    final entryA = ServiceEntryId('entry-a');
    final entryB = ServiceEntryId('entry-b');
    final sourceA = _source(
      'source-a-id',
      'source-a',
      serviceEntryId: entryA,
    );
    final sourceB = _source(
      'source-b-id',
      'source-b',
      role: EngineeringSupplyRoleKey.alternate,
      serviceEntryId: entryB,
    );

    final supply = CanonicalEngineeringSupplyTopology(
      topology: fixture.topology,
      sources: [sourceB, sourceA],
      knownServiceEntryIds: [entryA, entryB],
      circuitSupplies: [
        EngineeringCircuitSupply(
          circuitId: fixture.circuit.id,
          sourceIds: [sourceB.id, sourceA.id],
        ),
      ],
    );

    expect(
      supply
          .sourcesForCircuit(fixture.circuit.id)
          .map((value) => value.id.value),
      ['source-a-id', 'source-b-id'],
    );
    expect(supply.circuitsForSource(sourceA.id).single.id, fixture.circuit.id);
    expect(supply.source(sourceB.id)?.role, EngineeringSupplyRoleKey.alternate);
    expect(supply.source(sourceA.id)?.serviceEntryId, entryA);
  });

  test('P11.6 source roles remain extensible and immutable by identity', () {
    final customRole = EngineeringSupplyRoleKey('vendor.dual-uplink');
    expect(customRole.id, 'vendor.dual-uplink');
    expect(
      EngineeringSupplyRoleKey('core.primary'),
      EngineeringSupplyRoleKey.primary,
    );
    expect(() => EngineeringSupplyRoleKey('  '), throwsArgumentError);
    expect(() => EngineeringSupplySourceId(''), throwsArgumentError);
  });

  test('P11.6 duplicate source and circuit declarations fail closed', () {
    final fixture = _fixture();
    final source = _source('source-id', 'source-a');

    expect(
      () => CanonicalEngineeringSupplyTopology(
        topology: fixture.topology,
        sources: [source, source],
      ),
      throwsArgumentError,
    );
    expect(
      () => EngineeringCircuitSupply(
        circuitId: fixture.circuit.id,
        sourceIds: [source.id, source.id],
      ),
      throwsArgumentError,
    );
    expect(
      () => EngineeringCircuitSupply(
        circuitId: fixture.circuit.id,
        sourceIds: const [],
      ),
      throwsArgumentError,
    );
  });

  test('P11.6 dangling circuit/source/service-entry references fail closed',
      () {
    final fixture = _fixture();
    final source = _source(
      'source-id',
      'source-a',
      serviceEntryId: ServiceEntryId('missing-entry'),
    );

    expect(
      () => CanonicalEngineeringSupplyTopology(
        topology: fixture.topology,
        sources: [source],
      ),
      throwsArgumentError,
    );

    final validSource = _source('valid-source', 'source-a');
    expect(
      () => CanonicalEngineeringSupplyTopology(
        topology: fixture.topology,
        sources: [validSource],
        circuitSupplies: [
          EngineeringCircuitSupply(
            circuitId: CircuitId('missing-circuit'),
            sourceIds: [validSource.id],
          ),
        ],
      ),
      throwsArgumentError,
    );
    expect(
      () => CanonicalEngineeringSupplyTopology(
        topology: fixture.topology,
        sources: [validSource],
        circuitSupplies: [
          EngineeringCircuitSupply(
            circuitId: fixture.circuit.id,
            sourceIds: [EngineeringSupplySourceId('missing-source')],
          ),
        ],
      ),
      throwsArgumentError,
    );
  });

  test('P11.6 source endpoint must inject into the declared system', () {
    final fixture = _fixture();
    final invalid = EngineeringSupplySource(
      id: EngineeringSupplySourceId('input-source'),
      endpoint: EngineeringPortRef(
        componentId: ComponentId('board'),
        portId: PortId('in'),
      ),
      systemClass: EngineeringSystemClass.powerAc,
      media: EngineeringMedia.acPower,
    );

    expect(
      () => CanonicalEngineeringSupplyTopology(
        topology: fixture.topology,
        sources: [invalid],
      ),
      throwsArgumentError,
    );
  });

  test('P11.6 a source must reach every circuit edge through the same system',
      () {
    final fixture = _fixture();
    final foreignGraph = CanonicalEngineeringGraph(
      components: [
        ...fixture.topology.graph.components,
        _sourceComponent('isolated-source'),
        EngineeringGraphComponent(
          id: ComponentId('isolated-load'),
          componentTypeId: 'p11.isolated-load',
          discipline: EngineeringDiscipline.power,
          systemClass: EngineeringSystemClass.powerAc,
          ports: [
            EngineeringPortSpec.identified(
              portId: PortId('in'),
              direction: EngineeringPortDirection.input,
              allowedConnections: {EngineeringConnectionType.acSinglePhase},
              media: {EngineeringMedia.acPower},
            ),
          ],
        ),
      ],
      connections: [
        ...fixture.topology.graph.connections,
        _connection(
          'isolated-edge',
          'isolated-source',
          'out',
          'isolated-load',
          'in',
        ),
      ],
    );
    final topology = CanonicalEngineeringTopology(
      graph: foreignGraph,
      circuits: [fixture.circuit],
    );
    final source = _source('isolated-id', 'isolated-source');

    expect(
      () => CanonicalEngineeringSupplyTopology(
        topology: topology,
        sources: [source],
        circuitSupplies: [
          EngineeringCircuitSupply(
            circuitId: fixture.circuit.id,
            sourceIds: [source.id],
          ),
        ],
      ),
      throwsArgumentError,
    );
  });
}
