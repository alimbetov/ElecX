import 'package:elecx/src/domain/canonical_engineering_graph.dart';
import 'package:elecx/src/domain/engineering_graph.dart';
import 'package:elecx/src/domain/engineering_graph_semantics.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

EngineeringGraphComponent _component(
  String id, {
  int quantity = 1,
  Iterable<EngineeringPortSpec>? ports,
}) =>
    EngineeringGraphComponent(
      id: ComponentId(id),
      componentTypeId: 'network.device',
      discipline: EngineeringDiscipline.data,
      systemClass: EngineeringSystemClass.structuredCabling,
      ports: ports ??
          [
            EngineeringPortSpec.identified(
              portId: PortId('link'),
              direction: EngineeringPortDirection.bidirectional,
              allowedConnections: {
                EngineeringConnectionType.ethernetCopper,
                EngineeringConnectionType.poe,
              },
              media: {EngineeringMedia.ethernet, EngineeringMedia.poe},
              capabilities: {
                EngineeringPortCapability('profile.z'),
                EngineeringPortCapability('profile.a'),
              },
            ),
          ],
      quantity: quantity,
    );

EngineeringGraphConnection _edge(String id, String from, String to) =>
    EngineeringGraphConnection(
      id: EngineeringConnectionId(id),
      fromComponentId: ComponentId(from),
      fromPortId: PortId('link'),
      toComponentId: ComponentId(to),
      toPortId: PortId('link'),
      connectionType: EngineeringConnectionType.ethernetCopper,
      systemClass: EngineeringSystemClass.structuredCabling,
      media: EngineeringMedia.ethernet,
      semanticTypeId: 'network.primary-link',
      routeId: RouteId('route-$id'),
      circuitId: CircuitId('circuit-$id'),
    );

void main() {
  test('P11.8 fingerprint is independent from source collection ordering', () {
    final a = _component('a');
    final b = _component('b');
    final c = _component('c');
    final ab = _edge('ab', 'a', 'b');
    final bc = _edge('bc', 'b', 'c');

    final first = CanonicalEngineeringGraph(
      components: [c, a, b],
      connections: [bc, ab],
    );
    final reordered = CanonicalEngineeringGraph(
      components: [b, c, a],
      connections: [ab, bc],
    );

    expect(engineeringGraphFingerprint(first),
        engineeringGraphFingerprint(reordered));
    expect(EngineeringGraphDiff.between(first, reordered).isEmpty, isTrue);
  });

  test('P11.8 fingerprint canonicalizes port set and port-list ordering', () {
    EngineeringPortSpec port(String id, List<String> capabilities) =>
        EngineeringPortSpec.identified(
          portId: PortId(id),
          direction: EngineeringPortDirection.bidirectional,
          allowedConnections: {
            EngineeringConnectionType.poe,
            EngineeringConnectionType.ethernetCopper,
          },
          media: {EngineeringMedia.poe, EngineeringMedia.ethernet},
          capabilities: {
            for (final value in capabilities) EngineeringPortCapability(value),
          },
        );

    final first = CanonicalEngineeringGraph(components: [
      _component('a', ports: [
        port('z', ['b', 'a']),
        port('a', ['d', 'c'])
      ]),
    ]);
    final reordered = CanonicalEngineeringGraph(components: [
      _component('a', ports: [
        port('a', ['c', 'd']),
        port('z', ['a', 'b'])
      ]),
    ]);

    expect(engineeringGraphFingerprint(first),
        engineeringGraphFingerprint(reordered));
    expect(EngineeringGraphDiff.between(first, reordered).isEmpty, isTrue);
  });

  test('P11.8 diff reports deterministic sorted add remove and change ids', () {
    final before = CanonicalEngineeringGraph(
      components: [
        _component('z-remove'),
        _component('b-change'),
        _component('a-stable')
      ],
      connections: [_edge('z-remove-edge', 'a-stable', 'z-remove')],
    );
    final after = CanonicalEngineeringGraph(
      components: [
        _component('c-add'),
        _component('a-stable'),
        _component('b-change', quantity: 2)
      ],
      connections: [_edge('a-add-edge', 'a-stable', 'c-add')],
    );

    final diff = EngineeringGraphDiff.between(before, after);
    expect(diff.addedComponents.map((id) => id.value), ['c-add']);
    expect(diff.removedComponents.map((id) => id.value), ['z-remove']);
    expect(diff.changedComponents.map((id) => id.value), ['b-change']);
    expect(diff.addedConnections.map((id) => id.value), ['a-add-edge']);
    expect(diff.removedConnections.map((id) => id.value), ['z-remove-edge']);
    expect(diff.changedConnections, isEmpty);
    expect(diff.isEmpty, isFalse);
  });

  test('P11.8 semantic graph mutation changes the fingerprint', () {
    final before = CanonicalEngineeringGraph(components: [_component('a')]);
    final after =
        CanonicalEngineeringGraph(components: [_component('a', quantity: 2)]);

    expect(engineeringGraphFingerprint(before),
        isNot(engineeringGraphFingerprint(after)));
    expect(
      EngineeringGraphDiff.between(before, after).changedComponents,
      [ComponentId('a')],
    );
  });
}
