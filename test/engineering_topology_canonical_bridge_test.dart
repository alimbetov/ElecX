import 'package:elecx/src/domain/engineering_graph.dart';
import 'package:elecx/src/domain/engineering_topology.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:flutter_test/flutter_test.dart';

EngineeringNode node({
  required String id,
  required String portId,
  required EngineeringPortDirection direction,
}) =>
    EngineeringNode(
      id: id,
      componentTypeId: '$id-type',
      discipline: EngineeringDiscipline.lowVoltage,
      systemClass: EngineeringSystemClass.poeNetwork,
      surface: RoomSurfaceRef.wall('room-1', 0),
      position: const SurfacePointMm(100, 100),
      ports: [
        EngineeringPortSpec(
          id: portId,
          direction: direction,
          allowedConnections: {EngineeringConnectionType.poe},
        ),
      ],
    );

void main() {
  test('legacy topology projects to typed graph without geometry identity', () {
    final source = node(
      id: 'switch',
      portId: 'poe-out',
      direction: EngineeringPortDirection.output,
    );
    final target = node(
      id: 'camera',
      portId: 'poe-in',
      direction: EngineeringPortDirection.input,
    );
    final topology = EngineeringTopology(nodes: [source, target]);
    topology.connect(
      id: 'edge-1',
      fromNodeId: source.id,
      fromPortId: 'poe-out',
      toNodeId: target.id,
      toPortId: 'poe-in',
      connectionType: EngineeringConnectionType.poe,
      systemClass: EngineeringSystemClass.poeNetwork,
      routeId: 'route-1',
      circuitId: 'circuit-1',
    );

    final canonical = topology.toCanonicalGraph();

    expect(canonical.components.map((item) => item.id).toSet(), {
      ComponentId('switch'),
      ComponentId('camera'),
    });
    expect(canonical.connections.single.id, EngineeringConnectionId('edge-1'));
    expect(canonical.connections.single.routeId, RouteId('route-1'));
    expect(canonical.connections.single.circuitId, CircuitId('circuit-1'));
    expect(
      canonical.hasDirectedPath(ComponentId('switch'), ComponentId('camera')),
      isTrue,
    );
  });
}
