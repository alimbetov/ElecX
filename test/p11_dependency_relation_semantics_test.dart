import 'package:elecx/src/domain/canonical_engineering_graph.dart';
import 'package:elecx/src/domain/engineering_circuit_topology.dart';
import 'package:elecx/src/domain/engineering_dependency_projection.dart';
import 'package:elecx/src/domain/engineering_graph.dart';
import 'package:elecx/src/domain/engineering_supply_topology.dart';
import 'package:elecx/src/domain/impact_graph.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

EngineeringPortSpec _port(
  String id,
  EngineeringPortDirection direction,
) =>
    EngineeringPortSpec.identified(
      portId: PortId(id),
      direction: direction,
      allowedConnections: {EngineeringConnectionType.acSinglePhase},
      media: {EngineeringMedia.acPower},
    );

EngineeringGraphComponent _source() => EngineeringGraphComponent(
      id: ComponentId('source'),
      componentTypeId: 'p11.source',
      discipline: EngineeringDiscipline.power,
      systemClass: EngineeringSystemClass.powerAc,
      ports: [_port('out', EngineeringPortDirection.output)],
    );

EngineeringGraphComponent _board() => EngineeringGraphComponent(
      id: ComponentId('board'),
      componentTypeId: 'p11.board',
      discipline: EngineeringDiscipline.power,
      systemClass: EngineeringSystemClass.powerAc,
      ports: [
        _port('in', EngineeringPortDirection.input),
        _port('out', EngineeringPortDirection.output),
      ],
    );

EngineeringGraphComponent _load() => EngineeringGraphComponent(
      id: ComponentId('load'),
      componentTypeId: 'p11.load',
      discipline: EngineeringDiscipline.power,
      systemClass: EngineeringSystemClass.powerAc,
      ports: [_port('in', EngineeringPortDirection.input)],
    );

EngineeringGraphConnection _connection({
  required String id,
  required String from,
  required String fromPort,
  required String to,
  required String toPort,
  String? semanticTypeId,
  CircuitId? circuitId,
  RouteId? routeId,
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
      semanticTypeId: semanticTypeId,
      circuitId: circuitId,
      routeId: routeId,
    );

({
  CanonicalEngineeringTopology topology,
  CanonicalEngineeringSupplyTopology supply,
  EngineeringCircuit circuit,
}) _fixture() {
  final circuitId = CircuitId('circuit-load');
  final graph = CanonicalEngineeringGraph(
    components: [_source(), _board(), _load()],
    connections: [
      _connection(
        id: 'source-board',
        from: 'source',
        fromPort: 'out',
        to: 'board',
        toPort: 'in',
        semanticTypeId: EngineeringDependencySemanticTypeId.suppliedBy,
        routeId: RouteId('route-source-board'),
      ),
      _connection(
        id: 'board-load',
        from: 'board',
        fromPort: 'out',
        to: 'load',
        toPort: 'in',
        semanticTypeId: EngineeringDependencySemanticTypeId.protects,
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
  final topology = CanonicalEngineeringTopology(
    graph: graph,
    circuits: [circuit],
  );
  final source = EngineeringSupplySource(
    id: EngineeringSupplySourceId('utility-source'),
    endpoint: EngineeringPortRef(
      componentId: ComponentId('source'),
      portId: PortId('out'),
    ),
    systemClass: EngineeringSystemClass.powerAc,
    media: EngineeringMedia.acPower,
  );
  final supply = CanonicalEngineeringSupplyTopology(
    topology: topology,
    sources: [source],
    circuitSupplies: [
      EngineeringCircuitSupply(
        circuitId: circuitId,
        sourceIds: [source.id],
      ),
    ],
  );
  return (topology: topology, supply: supply, circuit: circuit);
}

void main() {
  test('P11.7 relation keys preserve legacy compatibility and custom extension',
      () {
    final dependency = ImpactDependency(
      dependency: ImpactEntityRef.component(ComponentId('a')),
      dependent: ImpactEntityRef.component(ComponentId('b')),
      kind: ImpactDependencyKind.controls,
    );
    expect(dependency.relationKey, ImpactDependencyRelationKey.controls);

    final customRelation = ImpactDependencyRelationKey('vendor.interlocks');
    final custom = ImpactDependency.typed(
      dependency: ImpactEntityRef.component(ComponentId('a')),
      dependent: ImpactEntityRef.component(ComponentId('b')),
      relationKey: customRelation,
    );
    expect(custom.kind, ImpactDependencyKind.custom);
    expect(custom.relationKey, customRelation);
    expect(() => ImpactDependencyRelationKey('  '), throwsArgumentError);
  });

  test('P11.7 conflicting or incomplete relation declarations fail closed', () {
    final a = ImpactEntityRef.component(ComponentId('a'));
    final b = ImpactEntityRef.component(ComponentId('b'));

    expect(
      () => ImpactGraph(
        dependencies: [
          ImpactDependency(
            dependency: a,
            dependent: b,
            kind: ImpactDependencyKind.controls,
            relationKey: ImpactDependencyRelationKey.protects,
          ),
        ],
      ),
      throwsArgumentError,
    );
    expect(
      () => ImpactGraph(
        dependencies: [
          ImpactDependency(
            dependency: a,
            dependent: b,
            kind: ImpactDependencyKind.custom,
          ),
        ],
      ),
      throwsArgumentError,
    );
  });

  test('P11.7 projector derives connectivity route circuit and supply impact',
      () {
    final fixture = _fixture();
    final impact = EngineeringImpactDependencyProjector(
      topology: fixture.topology,
      supplyTopology: fixture.supply,
    ).project();

    final source = ImpactEntityRef.component(ComponentId('source'));
    final board = ImpactEntityRef.component(ComponentId('board'));
    final load = ImpactEntityRef.component(ComponentId('load'));
    final boardLoad = ImpactEntityRef.engineeringConnection(
      EngineeringConnectionId('board-load'),
    );
    final circuit = ImpactEntityRef.circuit(fixture.circuit.id);
    final route = ImpactEntityRef.route(RouteId('route-source-board'));

    expect(
      impact.directDependentsOf(
        source,
        relations: {ImpactDependencyRelationKey.suppliedBy},
      ),
      {board, circuit},
    );
    expect(
      impact.directDependentsOf(
        load,
        relations: {ImpactDependencyRelationKey.connectivity},
      ),
      {boardLoad},
    );
    expect(
      impact.directDependentsOf(
        boardLoad,
        relations: {ImpactDependencyRelationKey.memberOf},
      ),
      {circuit},
    );
    expect(
      impact.transitiveDependentsOf(load),
      containsAll({boardLoad, circuit}),
    );
    expect(
      impact.transitiveDependentsOf(source),
      contains(route),
    );
  });

  test('P11.7 relation-filtered traversal follows only declared semantics', () {
    final a = ImpactEntityRef.component(ComponentId('a'));
    final b = ImpactEntityRef.component(ComponentId('b'));
    final c = ImpactEntityRef.component(ComponentId('c'));
    final graph = ImpactGraph(
      dependencies: [
        ImpactDependency.typed(
          dependency: a,
          dependent: b,
          relationKey: ImpactDependencyRelationKey.controls,
        ),
        ImpactDependency.typed(
          dependency: b,
          dependent: c,
          relationKey: ImpactDependencyRelationKey.connectivity,
        ),
      ],
    );

    expect(
      graph.transitiveDependentsOf(
        a,
        relations: {ImpactDependencyRelationKey.controls},
      ),
      {b},
    );
    expect(graph.transitiveDependentsOf(a), {b, c});
  });

  test('P11.7 communicates-with relation is projected symmetrically', () {
    final graph = CanonicalEngineeringGraph(
      components: [_source(), _board()],
      connections: [
        _connection(
          id: 'peer-link',
          from: 'source',
          fromPort: 'out',
          to: 'board',
          toPort: 'in',
          semanticTypeId: EngineeringDependencySemanticTypeId.communicatesWith,
        ),
      ],
    );
    final impact = EngineeringImpactDependencyProjector(
      topology: CanonicalEngineeringTopology(graph: graph),
    ).project();
    final source = ImpactEntityRef.component(ComponentId('source'));
    final board = ImpactEntityRef.component(ComponentId('board'));

    expect(
      impact.directDependentsOf(
        source,
        relations: {ImpactDependencyRelationKey.communicatesWith},
      ),
      {board},
    );
    expect(
      impact.directDependentsOf(
        board,
        relations: {ImpactDependencyRelationKey.communicatesWith},
      ),
      {source},
    );
  });

  test('P11.7 unknown semantic ids require explicit extension definition', () {
    const semanticTypeId = 'vendor.interlocks';
    final graph = CanonicalEngineeringGraph(
      components: [_source(), _board()],
      connections: [
        _connection(
          id: 'custom-link',
          from: 'source',
          fromPort: 'out',
          to: 'board',
          toPort: 'in',
          semanticTypeId: semanticTypeId,
        ),
      ],
    );
    final topology = CanonicalEngineeringTopology(graph: graph);

    expect(
      () => EngineeringImpactDependencyProjector(topology: topology).project(),
      throwsArgumentError,
    );

    final customRelation = ImpactDependencyRelationKey('vendor.interlocks');
    final impact = EngineeringImpactDependencyProjector(
      topology: topology,
      extensionRelations: [
        EngineeringDependencyRelationDefinition(
          semanticTypeId: semanticTypeId,
          relationKey: customRelation,
          symmetric: true,
        ),
      ],
    ).project();
    final source = ImpactEntityRef.component(ComponentId('source'));
    final board = ImpactEntityRef.component(ComponentId('board'));

    expect(
      impact.directDependentsOf(source, relations: {customRelation}),
      {board},
    );
    expect(
      impact.directDependentsOf(board, relations: {customRelation}),
      {source},
    );
    expect(
      () => EngineeringImpactDependencyProjector(
        topology: topology,
        extensionRelations: [
          EngineeringDependencyRelationDefinition(
            semanticTypeId: EngineeringDependencySemanticTypeId.controls,
            relationKey: customRelation,
          ),
        ],
      ),
      throwsArgumentError,
    );
  });

  test('P11.7 supply projector rejects a foreign topology view', () {
    final fixture = _fixture();
    final foreignTopology = CanonicalEngineeringTopology(
      graph: fixture.topology.graph,
      circuits: [fixture.circuit],
    );

    expect(
      () => EngineeringImpactDependencyProjector(
        topology: foreignTopology,
        supplyTopology: fixture.supply,
      ),
      throwsArgumentError,
    );
  });
}
