import 'package:elecx/src/domain/canonical_engineering_graph.dart';
import 'package:elecx/src/domain/engineering_circuit_topology.dart';
import 'package:elecx/src/domain/engineering_dependency_projection.dart';
import 'package:elecx/src/domain/engineering_graph.dart';
import 'package:elecx/src/domain/engineering_project_state.dart';
import 'package:elecx/src/domain/engineering_project_state_semantics.dart';
import 'package:elecx/src/domain/engineering_supply_topology.dart';
import 'package:elecx/src/domain/impact_graph.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

EngineeringGraphComponent _component(String id) => EngineeringGraphComponent(
      id: ComponentId(id),
      componentTypeId: 'p11.$id',
      discipline: EngineeringDiscipline.power,
      systemClass: EngineeringSystemClass.powerAc,
      ports: [
        EngineeringPortSpec.identified(
          portId: PortId('p'),
          direction: EngineeringPortDirection.bidirectional,
          allowedConnections: {EngineeringConnectionType.acSinglePhase},
          media: {EngineeringMedia.acPower},
        ),
      ],
    );

EngineeringProjectState _state({
  required List<EngineeringConnectionId> loopOrder,
  EngineeringSupplyRoleKey? sourceRole,
  String vocabulary = 'p11.v1',
  Iterable<EngineeringDependencyRelationDefinition> dependencyRelations =
      const [],
}) {
  final a = _component('a');
  final b = _component('b');
  final circuitId = CircuitId('circuit');
  final ab = EngineeringGraphConnection(
    id: EngineeringConnectionId('ab'),
    fromComponentId: a.id,
    fromPortId: PortId('p'),
    toComponentId: b.id,
    toPortId: PortId('p'),
    connectionType: EngineeringConnectionType.acSinglePhase,
    systemClass: EngineeringSystemClass.powerAc,
    media: EngineeringMedia.acPower,
    circuitId: circuitId,
  );
  final ba = EngineeringGraphConnection(
    id: EngineeringConnectionId('ba'),
    fromComponentId: b.id,
    fromPortId: PortId('p'),
    toComponentId: a.id,
    toPortId: PortId('p'),
    connectionType: EngineeringConnectionType.acSinglePhase,
    systemClass: EngineeringSystemClass.powerAc,
    media: EngineeringMedia.acPower,
    circuitId: circuitId,
  );
  final graph = CanonicalEngineeringGraph(
    components: [a, b],
    connections: [ab, ba],
  );
  final circuit = EngineeringCircuit(
    id: circuitId,
    systemClass: EngineeringSystemClass.powerAc,
    media: EngineeringMedia.acPower,
    connectionIds: [ab.id, ba.id],
  );
  final loop = EngineeringLoop(
    id: LoopId('loop'),
    systemClass: EngineeringSystemClass.powerAc,
    media: EngineeringMedia.acPower,
    circuitId: circuitId,
    connectionIds: loopOrder,
  );
  final source = EngineeringSupplySource(
    id: EngineeringSupplySourceId('supply'),
    endpoint: EngineeringPortRef(componentId: a.id, portId: PortId('p')),
    systemClass: EngineeringSystemClass.powerAc,
    media: EngineeringMedia.acPower,
    role: sourceRole,
  );
  return EngineeringProjectState(
    graph: graph,
    circuits: [circuit],
    loops: [loop],
    sources: [source],
    circuitSupplies: [
      EngineeringCircuitSupply(circuitId: circuitId, sourceIds: [source.id]),
    ],
    dependencyRelations: dependencyRelations,
    classificationVocabularyVersion: vocabulary,
  );
}

List<EngineeringConnectionId> _forwardLoop() => [
      EngineeringConnectionId('ab'),
      EngineeringConnectionId('ba'),
    ];

void main() {
  test('P11.8 aggregate diff is empty for equivalent semantic state', () {
    final left = _state(loopOrder: _forwardLoop());
    final right = _state(loopOrder: _forwardLoop());

    expect(EngineeringProjectStateDiff.between(left, right).isEmpty, isTrue);
  });

  test('P11.8 aggregate diff observes ordered loop semantics', () {
    final before = _state(loopOrder: _forwardLoop());
    final after = _state(
      loopOrder: [
        EngineeringConnectionId('ba'),
        EngineeringConnectionId('ab'),
      ],
    );

    final diff = EngineeringProjectStateDiff.between(before, after);
    expect(diff.loops.changed, ['loop']);
    expect(diff.isEmpty, isFalse);
  });

  test('P11.8 aggregate diff observes source role and vocabulary changes', () {
    final before = _state(
      loopOrder: _forwardLoop(),
      sourceRole: EngineeringSupplyRoleKey.primary,
    );
    final after = _state(
      loopOrder: _forwardLoop(),
      sourceRole: EngineeringSupplyRoleKey.emergency,
      vocabulary: 'p11.v2',
    );

    final diff = EngineeringProjectStateDiff.between(before, after);
    expect(diff.sources.changed, ['supply']);
    expect(diff.classificationVocabularyChanged, isTrue);
  });

  test(
      'P11.8 dependency relation semantics participate in fingerprint and diff',
      () {
    const semanticTypeId = 'vendor.interlocks';
    final relationKey = ImpactDependencyRelationKey('vendor.interlocks');
    final directed = _state(
      loopOrder: _forwardLoop(),
      dependencyRelations: [
        EngineeringDependencyRelationDefinition(
          semanticTypeId: semanticTypeId,
          relationKey: relationKey,
        ),
      ],
    );
    final symmetric = _state(
      loopOrder: _forwardLoop(),
      dependencyRelations: [
        EngineeringDependencyRelationDefinition(
          semanticTypeId: semanticTypeId,
          relationKey: relationKey,
          symmetric: true,
        ),
      ],
    );

    expect(directed.fingerprint, isNot(symmetric.fingerprint));
    final diff = EngineeringProjectStateDiff.between(directed, symmetric);
    expect(diff.dependencyRelations.changed, [semanticTypeId]);
  });

  test('P11.8 project state rejects built-in dependency semantic override', () {
    expect(
      () => _state(
        loopOrder: _forwardLoop(),
        dependencyRelations: [
          EngineeringDependencyRelationDefinition(
            semanticTypeId: EngineeringDependencySemanticTypeId.controls,
            relationKey: ImpactDependencyRelationKey('vendor.controls'),
          ),
        ],
      ),
      throwsArgumentError,
    );
  });
}
