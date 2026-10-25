import 'package:elecx/src/domain/canonical_engineering_graph.dart';
import 'package:elecx/src/domain/engineering_graph.dart';
import 'package:elecx/src/domain/engineering_impact_projection.dart';
import 'package:elecx/src/domain/impact_graph.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

EngineeringGraphComponent component({
  required String id,
  required String portId,
  required EngineeringPortDirection direction,
}) =>
    EngineeringGraphComponent(
      id: ComponentId(id),
      componentTypeId: '$id-type',
      discipline: EngineeringDiscipline.power,
      systemClass: EngineeringSystemClass.powerAc,
      ports: [
        EngineeringPortSpec(
          id: portId,
          direction: direction,
          allowedConnections: {EngineeringConnectionType.acSinglePhase},
        ),
      ],
    );

void main() {
  test('component impact propagates through route into circuit', () {
    final source = component(
      id: 'board',
      portId: 'power-out',
      direction: EngineeringPortDirection.output,
    );
    final load = component(
      id: 'socket',
      portId: 'power-in',
      direction: EngineeringPortDirection.input,
    );
    final graph = CanonicalEngineeringGraph(
      components: [source, load],
      connections: [
        EngineeringGraphConnection(
          id: EngineeringConnectionId('connection-1'),
          fromComponentId: source.id,
          fromPortId: PortId('power-out'),
          toComponentId: load.id,
          toPortId: PortId('power-in'),
          connectionType: EngineeringConnectionType.acSinglePhase,
          systemClass: EngineeringSystemClass.powerAc,
          routeId: RouteId('route-1'),
          circuitId: CircuitId('circuit-1'),
        ),
      ],
    );

    final impact = EngineeringImpactProjection.fromGraph(graph);
    final impacted = impact.transitiveDependentsOf(
      ImpactEntityRef.component(source.id),
    );

    expect(
      impacted,
      containsAll({
        ImpactEntityRef.engineeringConnection(
          EngineeringConnectionId('connection-1'),
        ),
        ImpactEntityRef.route(RouteId('route-1')),
        ImpactEntityRef.circuit(CircuitId('circuit-1')),
      }),
    );
  });

  test('circuit depends directly on connection when route is absent', () {
    final source = component(
      id: 'board',
      portId: 'power-out',
      direction: EngineeringPortDirection.output,
    );
    final load = component(
      id: 'socket',
      portId: 'power-in',
      direction: EngineeringPortDirection.input,
    );
    final connectionId = EngineeringConnectionId('connection-1');
    final circuitId = CircuitId('circuit-1');
    final graph = CanonicalEngineeringGraph(
      components: [source, load],
      connections: [
        EngineeringGraphConnection(
          id: connectionId,
          fromComponentId: source.id,
          fromPortId: PortId('power-out'),
          toComponentId: load.id,
          toPortId: PortId('power-in'),
          connectionType: EngineeringConnectionType.acSinglePhase,
          systemClass: EngineeringSystemClass.powerAc,
          circuitId: circuitId,
        ),
      ],
    );

    final impact = EngineeringImpactProjection.fromGraph(graph);

    expect(
      impact.directDependentsOf(
        ImpactEntityRef.engineeringConnection(connectionId),
      ),
      {ImpactEntityRef.circuit(circuitId)},
    );
  });
}
