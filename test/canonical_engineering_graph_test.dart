import 'package:elecx/src/domain/canonical_engineering_graph.dart';
import 'package:elecx/src/domain/engineering_graph.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:flutter_test/flutter_test.dart';

EngineeringGraphComponent component({
  required String id,
  required String portId,
  required EngineeringPortDirection direction,
}) =>
    EngineeringGraphComponent(
      id: ComponentId(id),
      componentTypeId: '$id-type',
      discipline: EngineeringDiscipline.lowVoltage,
      systemClass: EngineeringSystemClass.poeNetwork,
      ports: [
        EngineeringPortSpec(
          id: portId,
          direction: direction,
          allowedConnections: {EngineeringConnectionType.poe},
        ),
      ],
    );

void main() {
  test('canonical graph uses typed ids and validates directed connectivity', () {
    final source = component(
      id: 'switch-1',
      portId: 'poe-out',
      direction: EngineeringPortDirection.output,
    );
    final target = component(
      id: 'camera-1',
      portId: 'poe-in',
      direction: EngineeringPortDirection.input,
    );
    final graph = CanonicalEngineeringGraph(
      components: [source, target],
      connections: [
        EngineeringGraphConnection(
          id: EngineeringConnectionId('connection-1'),
          fromComponentId: source.id,
          fromPortId: PortId('poe-out'),
          toComponentId: target.id,
          toPortId: PortId('poe-in'),
          connectionType: EngineeringConnectionType.poe,
          systemClass: EngineeringSystemClass.poeNetwork,
          routeId: RouteId('route-1'),
          circuitId: CircuitId('circuit-1'),
        ),
      ],
    );

    expect(graph.hasDirectedPath(source.id, target.id), isTrue);
    expect(graph.downstreamComponentIds(source.id), {target.id});
  });

  test('canonical graph fails closed for dangling endpoints', () {
    final source = component(
      id: 'switch-1',
      portId: 'poe-out',
      direction: EngineeringPortDirection.output,
    );

    expect(
      () => CanonicalEngineeringGraph(
        components: [source],
        connections: [
          EngineeringGraphConnection(
            id: EngineeringConnectionId('connection-1'),
            fromComponentId: source.id,
            fromPortId: PortId('poe-out'),
            toComponentId: ComponentId('missing-camera'),
            toPortId: PortId('poe-in'),
            connectionType: EngineeringConnectionType.poe,
            systemClass: EngineeringSystemClass.poeNetwork,
          ),
        ],
      ),
      throwsArgumentError,
    );
  });

  test('canonical graph rejects incompatible endpoint direction', () {
    final source = component(
      id: 'source',
      portId: 'in-a',
      direction: EngineeringPortDirection.input,
    );
    final target = component(
      id: 'target',
      portId: 'in-b',
      direction: EngineeringPortDirection.input,
    );

    expect(
      () => CanonicalEngineeringGraph(
        components: [source, target],
        connections: [
          EngineeringGraphConnection(
            id: EngineeringConnectionId('connection-1'),
            fromComponentId: source.id,
            fromPortId: PortId('in-a'),
            toComponentId: target.id,
            toPortId: PortId('in-b'),
            connectionType: EngineeringConnectionType.poe,
            systemClass: EngineeringSystemClass.poeNetwork,
          ),
        ],
      ),
      throwsArgumentError,
    );
  });

  test('legacy node adapter drops physical placement from canonical graph', () {
    final legacy = EngineeringNode(
      id: 'legacy-camera',
      componentTypeId: 'cctv.camera.poe',
      discipline: EngineeringDiscipline.cctv,
      systemClass: EngineeringSystemClass.cctv,
      surface: RoomSurfaceRef.wall('room-1', 0),
      position: const SurfacePointMm(1000, 1200),
      ports: [
        EngineeringPortSpec(
          id: 'poe-in',
          direction: EngineeringPortDirection.input,
          allowedConnections: {EngineeringConnectionType.poe},
        ),
      ],
    );

    final canonical = legacy.toCanonicalEngineeringComponent();

    expect(canonical.id, ComponentId('legacy-camera'));
    expect(canonical.componentTypeId, 'cctv.camera.poe');
    expect(canonical.port(PortId('poe-in')), isNotNull);
  });
}
