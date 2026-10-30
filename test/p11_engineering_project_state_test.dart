import 'package:elecx/src/domain/canonical_engineering_graph.dart';
import 'package:elecx/src/domain/engineering_circuit_topology.dart';
import 'package:elecx/src/domain/engineering_graph.dart';
import 'package:elecx/src/domain/engineering_project_state.dart';
import 'package:elecx/src/domain/engineering_supply_topology.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_orientation.dart';
import 'package:flutter_test/flutter_test.dart';

EngineeringGraphComponent _source() => EngineeringGraphComponent(
      id: ComponentId('source'),
      componentTypeId: 'p11.source',
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

EngineeringProjectState _state({
  EngineeringSupplyRoleKey? role,
  ServiceEntryId? serviceEntryId,
}) {
  final circuitId = CircuitId('circuit');
  final connection = EngineeringGraphConnection(
    id: EngineeringConnectionId('feed'),
    fromComponentId: ComponentId('source'),
    fromPortId: PortId('out'),
    toComponentId: ComponentId('load'),
    toPortId: PortId('in'),
    connectionType: EngineeringConnectionType.acSinglePhase,
    systemClass: EngineeringSystemClass.powerAc,
    media: EngineeringMedia.acPower,
    circuitId: circuitId,
  );
  final graph = CanonicalEngineeringGraph(
    components: [_load(), _source()],
    connections: [connection],
  );
  final circuit = EngineeringCircuit(
    id: circuitId,
    systemClass: EngineeringSystemClass.powerAc,
    media: EngineeringMedia.acPower,
    connectionIds: [connection.id],
  );
  final source = EngineeringSupplySource(
    id: EngineeringSupplySourceId('source-id'),
    endpoint: EngineeringPortRef(
      componentId: ComponentId('source'),
      portId: PortId('out'),
    ),
    systemClass: EngineeringSystemClass.powerAc,
    media: EngineeringMedia.acPower,
    role: role,
    serviceEntryId: serviceEntryId,
  );
  return EngineeringProjectState(
    graph: graph,
    circuits: [circuit],
    sources: [source],
    circuitSupplies: [
      EngineeringCircuitSupply(
        circuitId: circuitId,
        sourceIds: [source.id],
      ),
    ],
  );
}

void main() {
  test('P11.8 metadata owns one semantic empty engineering state by default',
      () {
    const metadata = ProjectEngineeringMetadata();

    expect(metadata.engineeringState.isEmpty, isTrue);
    expect(metadata.copyWith().engineeringState.isEmpty, isTrue);
  });

  test('P11.8 metadata preserves the project-owned engineering state', () {
    final state = _state();
    final metadata = const ProjectEngineeringMetadata().withEngineeringState(
      state,
    );

    expect(identical(metadata.engineeringState, state), isTrue);
    expect(identical(metadata.copyWith().engineeringState, state), isTrue);
  });

  test('P11.8 aggregate fingerprint includes supply role semantics', () {
    final primary = _state(role: EngineeringSupplyRoleKey.primary);
    final emergency = _state(role: EngineeringSupplyRoleKey.emergency);

    expect(primary.fingerprint, isNot(emergency.fingerprint));
    expect(primary.sameAs(emergency), isFalse);
  });

  test('P11.8 service-entry references are checked against project ownership',
      () {
    final entryId = ServiceEntryId('entry-a');
    final state = _state(serviceEntryId: entryId);

    expect(
      () => state.requireKnownServiceEntries(const []),
      throwsArgumentError,
    );
    expect(
      () => state.requireKnownServiceEntries([entryId]),
      returnsNormally,
    );
  });

  test('P11.8 equivalent states have stable semantic equality in metadata', () {
    final left = const ProjectEngineeringMetadata().withEngineeringState(
      _state(),
    );
    final right = const ProjectEngineeringMetadata().withEngineeringState(
      _state(),
    );

    expect(left, right);
    expect(left.hashCode, right.hashCode);
  });
}
