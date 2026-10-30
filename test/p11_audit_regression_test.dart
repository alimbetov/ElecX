import 'package:elecx/src/domain/canonical_engineering_graph.dart';
import 'package:elecx/src/domain/engineering_circuit_topology.dart';
import 'package:elecx/src/domain/engineering_classification.dart';
import 'package:elecx/src/domain/engineering_dependency_projection.dart';
import 'package:elecx/src/domain/engineering_graph.dart';
import 'package:elecx/src/domain/engineering_graph_validation.dart';
import 'package:elecx/src/domain/engineering_supply_topology.dart';
import 'package:elecx/src/domain/impact_graph.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

EngineeringGraphComponent _node(String id) => EngineeringGraphComponent(
      id: ComponentId(id),
      componentTypeId: 'audit.device',
      discipline: EngineeringDiscipline.power,
      systemClass: EngineeringSystemClass.powerAc,
      ports: [
        for (final port in ['a', 'b'])
          EngineeringPortSpec(
            id: port,
            direction: EngineeringPortDirection.bidirectional,
            allowedConnections: {EngineeringConnectionType.custom},
            media: {EngineeringMedia.acPower, EngineeringMedia.dcPower},
          ),
      ],
    );

EngineeringGraphConnection _edge(
  String id,
  String from,
  String to, {
  String fromPort = 'a',
  EngineeringMedia? media = EngineeringMedia.acPower,
  String? semantic,
  EngineeringSystemClass system = EngineeringSystemClass.powerAc,
}) =>
    EngineeringGraphConnection(
      id: EngineeringConnectionId(id),
      fromComponentId: ComponentId(from),
      fromPortId: PortId(fromPort),
      toComponentId: ComponentId(to),
      toPortId: PortId('b'),
      connectionType: EngineeringConnectionType.custom,
      systemClass: system,
      systemKey: EngineeringSystemKey.powerAc,
      media: media,
      semanticTypeId: semantic,
    );

CanonicalEngineeringTopology _topology(
  List<EngineeringGraphConnection> edges, {
  EngineeringMedia? circuitMedia = EngineeringMedia.acPower,
}) =>
    CanonicalEngineeringTopology(
      graph: CanonicalEngineeringGraph(
        components: [
          for (final id in ['source', 'board', 'bridge', 'load']) _node(id),
        ],
        connections: edges,
      ),
      circuits: [
        EngineeringCircuit(
          id: CircuitId('c'),
          systemClass: EngineeringSystemClass.powerAc,
          media: circuitMedia,
          connectionIds: [EngineeringConnectionId('target')],
        ),
      ],
    );

CanonicalEngineeringSupplyTopology _supply(
  CanonicalEngineeringTopology topology, {
  EngineeringMedia? sourceMedia = EngineeringMedia.acPower,
}) =>
    CanonicalEngineeringSupplyTopology(
      topology: topology,
      sources: [
        EngineeringSupplySource(
          id: EngineeringSupplySourceId('s'),
          endpoint: EngineeringPortRef(
            componentId: ComponentId('source'),
            portId: PortId('a'),
          ),
          systemClass: EngineeringSystemClass.powerAc,
          media: sourceMedia,
        ),
      ],
      circuitSupplies: [
        EngineeringCircuitSupply(
          circuitId: CircuitId('c'),
          sourceIds: [EngineeringSupplySourceId('s')],
        ),
      ],
    );

void main() {
  test(
    'audit supply cannot start from a different port on the source component',
    () {
      final topology = _topology([
        _edge('feed', 'source', 'board'),
        _edge('target', 'source', 'load', fromPort: 'b'),
      ]);
      expect(() => _supply(topology), throwsArgumentError);
      // The same circuit is reachable when its edge uses the declared endpoint.
      expect(
        _supply(_topology([_edge('target', 'source', 'load')]))
            .sourcesForCircuit(CircuitId('c')),
        hasLength(1),
      );
    },
  );

  test(
    'audit supply checks every traversed medium including the circuit edge',
    () {
      for (final wrongMedia in [EngineeringMedia.dcPower, null]) {
        for (final inferFromTarget in [false, true]) {
          final topology = _topology([
            _edge('feed', 'source', 'board'),
            _edge('gap', 'board', 'bridge', media: wrongMedia),
            _edge('target', 'bridge', 'load'),
          ], circuitMedia: inferFromTarget ? null : EngineeringMedia.acPower);
          expect(
            () => _supply(
              topology,
              sourceMedia: inferFromTarget ? null : EngineeringMedia.acPower,
            ),
            throwsArgumentError,
          );
        }
      }
      expect(
        () => _supply(
          _topology([
            _edge('feed', 'source', 'board'),
            _edge('target', 'board', 'load', media: EngineeringMedia.dcPower),
          ], circuitMedia: null),
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'audit supply does not cross a conflicting legacy system with the same key',
    () {
      expect(
        () => _supply(
          _topology([
            _edge('feed', 'source', 'board'),
            _edge(
              'gap',
              'board',
              'bridge',
              system: EngineeringSystemClass.powerDc,
            ),
            _edge('target', 'bridge', 'load'),
          ]),
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'audit supply remains cycle safe and supports branched and legacy paths',
    () {
      final supply = _supply(
        _topology([
          _edge('feed', 'source', 'board'),
          _edge('branch', 'board', 'bridge'),
          _edge('cycle', 'bridge', 'board'),
          _edge('target', 'bridge', 'load'),
        ]),
      );
      expect(supply.sourcesForCircuit(CircuitId('c')), hasLength(1));
      expect(
        _supply(
          _topology([
            _edge('feed', 'source', 'board', media: null),
            _edge('target', 'board', 'load', media: null),
          ], circuitMedia: null),
          sourceMedia: null,
        ).sources,
        hasLength(1),
      );
    },
  );

  test(
      'audit changed semantic connection invalidates its dependent with relation filtering',
      () {
    final topology = _topology([
      _edge(
        'target',
        'source',
        'load',
        semantic: EngineeringDependencySemanticTypeId.controls,
      ),
    ]);
    final impact =
        EngineeringImpactDependencyProjector(topology: topology).project();
    final changed = ImpactEntityRef.engineeringConnection(
      EngineeringConnectionId('target'),
    );
    expect(
      impact.directDependentsOf(
        changed,
        relations: {ImpactDependencyRelationKey.controls},
      ),
      {ImpactEntityRef.component(ComponentId('load'))},
    );
    expect(
      impact.transitiveDependentsOf(changed),
      isNot(contains(ImpactEntityRef.component(ComponentId('bridge')))),
    );
  });

  test(
      'audit internal component link projects without a forbidden impact self edge',
      () {
    final graph = CanonicalEngineeringGraph(
      components: [_node('source')],
      connections: [
        _edge(
          'internal',
          'source',
          'source',
          semantic: EngineeringDependencySemanticTypeId.communicatesWith,
        ),
      ],
    );
    final impact = EngineeringImpactDependencyProjector(
      topology: CanonicalEngineeringTopology(graph: graph),
    ).project();
    final source = ImpactEntityRef.component(ComponentId('source'));
    final connection = ImpactEntityRef.engineeringConnection(
      EngineeringConnectionId('internal'),
    );
    expect(
      impact.directDependentsOf(
        connection,
        relations: {ImpactDependencyRelationKey.communicatesWith},
      ),
      {source},
    );
    expect(
      impact.dependencies.every((edge) => edge.dependency != edge.dependent),
      isTrue,
    );
    expect(impact.transitiveDependentsOf(source), {connection});
  });

  test(
      'audit changed plain feeder and supply source both invalidate the supplied circuit',
      () {
    final topology = _topology([
      _edge('feed', 'source', 'board'),
      _edge('target', 'board', 'load'),
    ]);
    final impact = EngineeringImpactDependencyProjector(
      topology: topology,
      supplyTopology: _supply(topology),
    ).project();
    final circuit = ImpactEntityRef.circuit(CircuitId('c'));
    expect(
      impact.transitiveDependentsOf(
        ImpactEntityRef.engineeringConnection(EngineeringConnectionId('feed')),
      ),
      contains(circuit),
    );
    expect(
      impact.directDependentsOf(
        ImpactEntityRef.supplySource(EngineeringSupplySourceId('s')),
        relations: {ImpactDependencyRelationKey.suppliedBy},
      ),
      {circuit},
    );
  });

  test(
      'audit loop and group membership remain reachable from canonical member changes',
      () {
    final graph = CanonicalEngineeringGraph(
      components: [_node('source'), _node('board')],
      connections: [
        _edge('ab', 'source', 'board'),
        _edge('ba', 'board', 'source'),
      ],
    );
    final circuit = EngineeringCircuit(
      id: CircuitId('c'),
      systemClass: EngineeringSystemClass.powerAc,
      connectionIds: [
        EngineeringConnectionId('ab'),
        EngineeringConnectionId('ba'),
      ],
    );
    final loop = EngineeringLoop(
      id: LoopId('loop'),
      systemClass: EngineeringSystemClass.powerAc,
      circuitId: circuit.id,
      connectionIds: circuit.connectionIds,
    );
    final group = EngineeringGroup(
      id: EngineeringGroupId('group'),
      semanticTypeId: 'audit.group',
      componentIds: [ComponentId('board')],
      connectionIds: [EngineeringConnectionId('ab')],
      circuitIds: [circuit.id],
      loopIds: [loop.id],
    );
    final impact = EngineeringImpactDependencyProjector(
      topology: CanonicalEngineeringTopology(
        graph: graph,
        circuits: [circuit],
        loops: [loop],
        groups: [group],
      ),
    ).project();
    final groupRef = ImpactEntityRef.engineeringGroup(group.id);
    expect(
      impact.transitiveDependentsOf(
        ImpactEntityRef.engineeringConnection(EngineeringConnectionId('ab')),
        relations: {ImpactDependencyRelationKey.memberOf},
      ),
      containsAll([
        ImpactEntityRef.loop(loop.id),
        ImpactEntityRef.circuit(circuit.id),
        groupRef,
      ]),
    );
    expect(
      impact.directDependentsOf(
        ImpactEntityRef.component(ComponentId('board')),
        relations: {ImpactDependencyRelationKey.memberOf},
      ),
      {groupRef},
    );
    expect(
      impact.directDependentsOf(
        ImpactEntityRef.loop(loop.id),
        relations: {ImpactDependencyRelationKey.memberOf},
      ),
      {ImpactEntityRef.circuit(circuit.id), groupRef},
    );
  });

  EngineeringConnectionCompatibilityRule rule(
    String id,
    EngineeringMedia? media, {
    String from = 'a',
    String to = 'b',
  }) =>
      EngineeringConnectionCompatibilityRule(
        id: id,
        fromSystemClass: EngineeringSystemClass.custom,
        toSystemClass: EngineeringSystemClass.custom,
        connectionSystemClass: EngineeringSystemClass.custom,
        connectionType: EngineeringConnectionType.custom,
        fromSystemKey: EngineeringSystemKey(from),
        toSystemKey: EngineeringSystemKey(to),
        media: media,
      );

  test(
      'audit explicit opaque medium cannot collide with unspecified-media sentinel',
      () {
    final absent = rule('absent', null);
    final explicit = rule('explicit', EngineeringMedia('<unspecified>'));
    expect(absent.compatibilityKey, isNot(explicit.compatibilityKey));
    expect(
      EngineeringCompatibilityProfile(
        id: 'p',
        revision: '1',
        rules: [absent, explicit],
      ).rules,
      hasLength(2),
    );
  });

  test(
    'audit opaque system keys cannot collide across separator boundaries',
    () {
      final first = rule('first', null, from: 'a\u0000custom\u0000b', to: 'c');
      final second = rule(
        'second',
        null,
        from: 'a',
        to: 'b\u0000custom\u0000c',
      );
      expect(first.compatibilityKey, isNot(second.compatibilityKey));
      expect(
        first.unspecifiedMediaCompatibilityKey,
        isNot(second.unspecifiedMediaCompatibilityKey),
      );
      expect(
        EngineeringCompatibilityProfile(
          id: 'p',
          revision: '1',
          rules: [first, second],
        ).rules,
        hasLength(2),
      );
      expect(
        () => EngineeringCompatibilityProfile(
          id: 'p',
          revision: '1',
          rules: [
            first,
            rule('duplicate', null, from: 'a\u0000custom\u0000b', to: 'c'),
          ],
        ),
        throwsArgumentError,
      );
    },
  );
}
