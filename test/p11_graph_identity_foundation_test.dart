import 'dart:math';

import 'package:elecx/src/domain/canonical_engineering_graph.dart';
import 'package:elecx/src/domain/engineering_graph.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:flutter_test/flutter_test.dart';

EngineeringGraphComponent _component(String id, {String port = 'link'}) =>
    EngineeringGraphComponent(
        id: ComponentId(id),
        componentTypeId: 'network.device',
        discipline: EngineeringDiscipline.data,
        systemClass: EngineeringSystemClass.structuredCabling,
        ports: [
          EngineeringPortSpec.identified(
              portId: PortId(port),
              direction: EngineeringPortDirection.bidirectional,
              allowedConnections: {EngineeringConnectionType.ethernetCopper})
        ]);

EngineeringGraphConnection _edge(String id, String from, String to,
        {String toPort = 'link', RouteId? route}) =>
    EngineeringGraphConnection(
        id: EngineeringConnectionId(id),
        fromComponentId: ComponentId(from),
        fromPortId: PortId('link'),
        toComponentId: ComponentId(to),
        toPortId: PortId(toPort),
        connectionType: EngineeringConnectionType.ethernetCopper,
        systemClass: EngineeringSystemClass.structuredCabling,
        routeId: route);

void main() {
  test('P11.1 endpoint equality preserves opaque values and owner scope', () {
    final first = EngineeringPortRef(
        componentId: ComponentId('building:a'), portId: PortId('b:c'));
    final other = EngineeringPortRef(
        componentId: ComponentId('building:a:b'), portId: PortId('c'));
    expect(first, isNot(other)); // A delimiter-joined identity would collide.
    expect(
        first,
        EngineeringPortRef(
            componentId: ComponentId('building:a'), portId: PortId('b:c')));
    expect({first, other}, hasLength(2));
    final factory = SecureRandomEntityIdFactory(random: Random(1101));
    final node = factory.newComponentId();
    final port = factory.newPortId();
    final edge = factory.newEngineeringConnectionId();
    expect(ComponentId(node.value), node);
    expect(PortId(port.value), port);
    expect(EngineeringConnectionId(edge.value), edge);
    expect(ComponentId('same'), isNot(EngineeringConnectionId('same')));
    expect(() => PortId('  '), throwsArgumentError);
    expect(
        () => EngineeringPortSpec(
            id: '  ',
            direction: EngineeringPortDirection.input,
            allowedConnections: {EngineeringConnectionType.poe}),
        throwsArgumentError);
  });

  test('P11.1 repeated catalog keys resolve through their component owner', () {
    final a = _component('a');
    final b = _component('b');
    final edge = _edge('edge', 'a', 'b');
    final graph =
        CanonicalEngineeringGraph(components: [a, b], connections: [edge]);
    expect(identical(graph.port(edge.fromEndpoint), a.ports.single), isTrue);
    expect(identical(graph.port(edge.toEndpoint), b.ports.single), isTrue);
    expect(identical(graph.connection(edge.id), edge), isTrue);
    expect(edge.fromEndpoint, isNot(edge.toEndpoint));
    expect(graph.outgoingConnections(a.id), [edge]);
    expect(graph.incomingConnections(b.id), [edge]);
    expect(graph.connection(EngineeringConnectionId('missing')), isNull);
  });

  test('P11.1 graph capability snapshots survive source collection mutation',
      () {
    final allowed = {EngineeringConnectionType.ethernetCopper};
    final spec = EngineeringPortSpec(
        id: 'link',
        direction: EngineeringPortDirection.bidirectional,
        allowedConnections: allowed);
    final ports = [spec];
    final capability = EngineeringComponentCapability(
        componentTypeId: 'network.device',
        discipline: EngineeringDiscipline.data,
        systemClass: EngineeringSystemClass.structuredCabling,
        calculationKind: EngineeringCalculationKind.copperLinkLength,
        ports: ports);
    final a = EngineeringGraphComponent(
        id: ComponentId('a'),
        componentTypeId: capability.componentTypeId,
        discipline: capability.discipline,
        systemClass: capability.systemClass,
        ports: capability.ports);
    final components = [a, _component('b')];
    final connections = [_edge('edge', 'a', 'b')];
    final graph = CanonicalEngineeringGraph(
        components: components, connections: connections);
    allowed.clear();
    ports.clear();
    components.clear();
    connections.clear();
    expect(graph.hasDirectedPath(ComponentId('a'), ComponentId('b')), isTrue);
    expect(
        graph
            .requirePort(
                EngineeringPortRef(componentId: a.id, portId: PortId('link')))
            .accepts(EngineeringConnectionType.ethernetCopper),
        isTrue);
    expect(capability.ports, hasLength(1));
    expect(() => spec.allowedConnections.clear(), throwsUnsupportedError);
    expect(() => capability.ports.clear(), throwsUnsupportedError);
    expect(() => a.ports.clear(), throwsUnsupportedError);
    expect(() => graph.connections.clear(), throwsUnsupportedError);
    expect(() => graph.components.clear(), throwsUnsupportedError);
    expect(
        () => graph.outgoingConnections(a.id).clear(), throwsUnsupportedError);
    expect(() => graph.incomingConnections(ComponentId('b')).clear(),
        throwsUnsupportedError);
  });

  test('P11.1 a port on another component cannot satisfy a dangling endpoint',
      () {
    final a = _component('a');
    final b = _component('b', port: 'different');
    final graph = CanonicalEngineeringGraph(components: [a, b]);
    final foreign =
        EngineeringPortRef(componentId: b.id, portId: PortId('link'));
    expect(graph.port(foreign), isNull);
    expect(() => graph.requirePort(foreign), throwsArgumentError);
    expect(
        () => CanonicalEngineeringGraph(
            components: [a, b], connections: [_edge('edge', 'a', 'b')]),
        throwsArgumentError);
    expect(() => graph.incomingConnections(ComponentId('unknown')),
        throwsArgumentError);
    expect(() => graph.outgoingConnections(ComponentId('unknown')),
        throwsArgumentError);
  });

  test('P11.1 duplicate node edge and local port identities fail closed', () {
    final a = _component('a');
    final b = _component('b');
    expect(() => CanonicalEngineeringGraph(components: [a, a]),
        throwsArgumentError);
    expect(
        () => CanonicalEngineeringGraph(
            components: [a, b],
            connections: [_edge('same', 'a', 'b'), _edge('same', 'b', 'a')]),
        throwsArgumentError);
    expect(
        () => EngineeringGraphComponent(
                id: a.id,
                componentTypeId: a.componentTypeId,
                discipline: a.discipline,
                systemClass: a.systemClass,
                ports: [
                  a.ports.single,
                  EngineeringPortSpec(
                      id: 'link',
                      direction: EngineeringPortDirection.bidirectional,
                      allowedConnections: {
                        EngineeringConnectionType.ethernetCopper
                      })
                ]),
        throwsArgumentError);
  });

  test('P11.1 indexed traversal handles cycles branches and isolated nodes',
      () {
    final graph = CanonicalEngineeringGraph(components: [
      for (final id in ['a', 'b', 'c', 'd', 'isolated']) _component(id)
    ], connections: [
      _edge('ab', 'a', 'b'),
      _edge('bc', 'b', 'c'),
      _edge('ca', 'c', 'a'),
      _edge('ad', 'a', 'd'),
      _edge('dc', 'd', 'c')
    ]);
    expect(graph.downstreamComponentIds(ComponentId('a')),
        {ComponentId('b'), ComponentId('c'), ComponentId('d')});
    expect(graph.hasDirectedPath(ComponentId('c'), ComponentId('d')), isTrue);
    expect(graph.hasDirectedPath(ComponentId('isolated'), ComponentId('a')),
        isFalse);
    expect(graph.hasDirectedPath(ComponentId('a'), ComponentId('a')), isTrue);
    expect(graph.incomingConnections(ComponentId('c')).map((e) => e.id),
        [EngineeringConnectionId('bc'), EngineeringConnectionId('dc')]);
    expect(graph.outgoingConnections(ComponentId('isolated')), isEmpty);
    expect(
        () => graph
            .outgoingConnections(ComponentId('isolated'))
            .add(_edge('x', 'a', 'b')),
        throwsUnsupportedError);
  });

  test('P11.1 placement and rerouting preserve logical endpoint identities',
      () {
    EngineeringNode placed(int x, int y) => EngineeringNode(
        id: 'a',
        componentTypeId: 'network.device',
        discipline: EngineeringDiscipline.data,
        systemClass: EngineeringSystemClass.structuredCabling,
        surface: RoomSurfaceRef.wall('room', 0),
        position: SurfacePointMm(x, y),
        ports: _component('a').ports);
    final before = placed(100, 200).toCanonicalEngineeringComponent();
    final after = placed(3000, 1800).toCanonicalEngineeringComponent();
    final original = _edge('edge', 'a', 'b');
    final rerouted = _edge('edge', 'a', 'b', route: RouteId('physical-route'));
    final graph = CanonicalEngineeringGraph(
        components: [after, _component('b')], connections: [rerouted]);
    expect(after.id, before.id);
    expect(after.ports.single.portId, before.ports.single.portId);
    expect(after.ports.single.id, 'link');
    expect(rerouted.id, original.id);
    expect(rerouted.fromEndpoint, original.fromEndpoint);
    expect(rerouted.toEndpoint, original.toEndpoint);
    expect(graph.hasDirectedPath(before.id, ComponentId('b')), isTrue);
  });
}
