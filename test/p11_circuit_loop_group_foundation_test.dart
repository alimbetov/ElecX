import 'package:elecx/src/domain/canonical_engineering_graph.dart';
import 'package:elecx/src/domain/engineering_circuit_topology.dart';
import 'package:elecx/src/domain/engineering_graph.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

EngineeringGraphComponent _component(String id) => EngineeringGraphComponent(
      id: ComponentId(id),
      componentTypeId: 'p11.fire-device',
      discipline: EngineeringDiscipline.fireAlarm,
      systemClass: EngineeringSystemClass.fireAlarm,
      ports: [
        EngineeringPortSpec.identified(
          portId: PortId('loop'),
          direction: EngineeringPortDirection.bidirectional,
          allowedConnections: {EngineeringConnectionType.fireLoop},
          media: {EngineeringMedia.fireLoop},
        ),
      ],
    );

EngineeringGraphConnection _connection(
  String id,
  String from,
  String to, {
  CircuitId? circuitId,
  EngineeringMedia? media,
  EngineeringSystemClass systemClass = EngineeringSystemClass.fireAlarm,
}) =>
    EngineeringGraphConnection(
      id: EngineeringConnectionId(id),
      fromComponentId: ComponentId(from),
      fromPortId: PortId('loop'),
      toComponentId: ComponentId(to),
      toPortId: PortId('loop'),
      connectionType: EngineeringConnectionType.fireLoop,
      systemClass: systemClass,
      media: media ?? EngineeringMedia.fireLoop,
      circuitId: circuitId,
    );

CanonicalEngineeringGraph _cycleGraph({CircuitId? circuitId}) =>
    CanonicalEngineeringGraph(
      components: [_component('a'), _component('b'), _component('c')],
      connections: [
        _connection('ab', 'a', 'b', circuitId: circuitId),
        _connection('bc', 'b', 'c', circuitId: circuitId),
        _connection('ca', 'c', 'a', circuitId: circuitId),
      ],
    );

void main() {
  test('P11.3 circuit membership is immutable and indexed', () {
    final circuitId = CircuitId('fire-circuit-1');
    final circuit = EngineeringCircuit(
      id: circuitId,
      systemClass: EngineeringSystemClass.fireAlarm,
      media: EngineeringMedia.fireLoop,
      connectionIds: [
        EngineeringConnectionId('ab'),
        EngineeringConnectionId('bc'),
        EngineeringConnectionId('ca'),
      ],
    );
    final topology = CanonicalEngineeringTopology(
      graph: _cycleGraph(circuitId: circuitId),
      circuits: [circuit],
    );

    expect(topology.circuit(circuitId), same(circuit));
    expect(
      topology.circuitForConnection(EngineeringConnectionId('bc'))?.id,
      circuitId,
    );
    expect(circuit.connectionIds.length, 3);
    expect(() => circuit.connectionIds.clear(), throwsUnsupportedError);
  });

  test('P11.3 one logical connection cannot belong to two circuits', () {
    final graph = _cycleGraph();
    final shared = EngineeringConnectionId('ab');

    expect(
      () => CanonicalEngineeringTopology(
        graph: graph,
        circuits: [
          EngineeringCircuit(
            id: CircuitId('circuit-a'),
            systemClass: EngineeringSystemClass.fireAlarm,
            connectionIds: [shared],
          ),
          EngineeringCircuit(
            id: CircuitId('circuit-b'),
            systemClass: EngineeringSystemClass.fireAlarm,
            connectionIds: [shared],
          ),
        ],
      ),
      throwsArgumentError,
    );
  });

  test('P11.3 circuit validation fails closed on media or legacy-id mismatch',
      () {
    final declaredId = CircuitId('declared');
    final graph = CanonicalEngineeringGraph(
      components: [_component('a'), _component('b')],
      connections: [
        _connection('ab', 'a', 'b', circuitId: declaredId),
      ],
    );

    expect(
      () => CanonicalEngineeringTopology(
        graph: graph,
        circuits: [
          EngineeringCircuit(
            id: CircuitId('other'),
            systemClass: EngineeringSystemClass.fireAlarm,
            connectionIds: [EngineeringConnectionId('ab')],
          ),
        ],
      ),
      throwsArgumentError,
    );

    expect(
      () => CanonicalEngineeringTopology(
        graph: _cycleGraph(),
        circuits: [
          EngineeringCircuit(
            id: CircuitId('media-mismatch'),
            systemClass: EngineeringSystemClass.fireAlarm,
            media: EngineeringMedia.rs485,
            connectionIds: [EngineeringConnectionId('ab')],
          ),
        ],
      ),
      throwsArgumentError,
    );
  });

  test('P11.3 loop requires ordered continuity and closure', () {
    final circuitId = CircuitId('loop-circuit');
    final circuit = EngineeringCircuit(
      id: circuitId,
      systemClass: EngineeringSystemClass.fireAlarm,
      media: EngineeringMedia.fireLoop,
      connectionIds: [
        EngineeringConnectionId('ab'),
        EngineeringConnectionId('bc'),
        EngineeringConnectionId('ca'),
      ],
    );
    final loop = EngineeringLoop(
      id: LoopId('loop-1'),
      systemClass: EngineeringSystemClass.fireAlarm,
      media: EngineeringMedia.fireLoop,
      circuitId: circuitId,
      connectionIds: [
        EngineeringConnectionId('ab'),
        EngineeringConnectionId('bc'),
        EngineeringConnectionId('ca'),
      ],
    );
    final topology = CanonicalEngineeringTopology(
      graph: _cycleGraph(circuitId: circuitId),
      circuits: [circuit],
      loops: [loop],
    );

    expect(topology.loop(loop.id), same(loop));
    expect(
      topology.loopsForConnection(EngineeringConnectionId('ca')).single.id,
      loop.id,
    );
    expect(() => loop.connectionIds.clear(), throwsUnsupportedError);

    expect(
      () => CanonicalEngineeringTopology(
        graph: _cycleGraph(circuitId: circuitId),
        circuits: [circuit],
        loops: [
          EngineeringLoop(
            id: LoopId('broken-loop'),
            systemClass: EngineeringSystemClass.fireAlarm,
            circuitId: circuitId,
            connectionIds: [
              EngineeringConnectionId('ab'),
              EngineeringConnectionId('ca'),
              EngineeringConnectionId('bc'),
            ],
          ),
        ],
      ),
      throwsArgumentError,
    );
  });

  test('P11.3 semantic groups reference canonical graph/topology members', () {
    final circuitId = CircuitId('fire-circuit');
    final loopId = LoopId('fire-loop');
    final circuit = EngineeringCircuit(
      id: circuitId,
      systemClass: EngineeringSystemClass.fireAlarm,
      connectionIds: [
        EngineeringConnectionId('ab'),
        EngineeringConnectionId('bc'),
        EngineeringConnectionId('ca'),
      ],
    );
    final loop = EngineeringLoop(
      id: loopId,
      systemClass: EngineeringSystemClass.fireAlarm,
      circuitId: circuitId,
      connectionIds: [
        EngineeringConnectionId('ab'),
        EngineeringConnectionId('bc'),
        EngineeringConnectionId('ca'),
      ],
    );
    final group = EngineeringGroup(
      id: EngineeringGroupId('floor-1-fire'),
      semanticTypeId: 'fire.zone',
      componentIds: [ComponentId('a')],
      connectionIds: [EngineeringConnectionId('ab')],
      circuitIds: [circuitId],
      loopIds: [loopId],
    );
    final topology = CanonicalEngineeringTopology(
      graph: _cycleGraph(),
      circuits: [circuit],
      loops: [loop],
      groups: [group],
    );

    expect(topology.group(group.id), same(group));
    expect(group.semanticTypeId, 'fire.zone');
    expect(() => group.componentIds.clear(), throwsUnsupportedError);
    expect(() => group.loopIds.clear(), throwsUnsupportedError);
  });

  test('P11.3 invalid ids and dangling group references fail closed', () {
    expect(() => LoopId('  '), throwsArgumentError);
    expect(() => EngineeringGroupId(''), throwsArgumentError);
    expect(
      () => EngineeringGroup(
        id: EngineeringGroupId('empty'),
        semanticTypeId: 'custom.group',
      ),
      throwsArgumentError,
    );

    expect(
      () => CanonicalEngineeringTopology(
        graph: _cycleGraph(),
        groups: [
          EngineeringGroup(
            id: EngineeringGroupId('dangling'),
            semanticTypeId: 'custom.group',
            circuitIds: [CircuitId('missing')],
          ),
        ],
      ),
      throwsArgumentError,
    );
  });
}
