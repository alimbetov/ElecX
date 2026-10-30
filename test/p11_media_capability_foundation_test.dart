import 'package:elecx/src/domain/canonical_engineering_graph.dart';
import 'package:elecx/src/domain/engineering_graph.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

EngineeringGraphComponent _component(
  String id, {
  required EngineeringPortDirection direction,
  required Set<EngineeringMedia> media,
  Set<EngineeringPortCapability> capabilities = const {},
}) =>
    EngineeringGraphComponent(
      id: ComponentId(id),
      componentTypeId: 'p11.media.device',
      discipline: EngineeringDiscipline.data,
      systemClass: EngineeringSystemClass.custom,
      ports: [
        EngineeringPortSpec.identified(
          portId: PortId('link'),
          direction: direction,
          allowedConnections: {EngineeringConnectionType.custom},
          media: media,
          capabilities: capabilities,
        ),
      ],
    );

EngineeringGraphConnection _connection(
  String id,
  String from,
  String to, {
  EngineeringMedia? media,
}) =>
    EngineeringGraphConnection(
      id: EngineeringConnectionId(id),
      fromComponentId: ComponentId(from),
      fromPortId: PortId('link'),
      toComponentId: ComponentId(to),
      toPortId: PortId('link'),
      connectionType: EngineeringConnectionType.custom,
      systemClass: EngineeringSystemClass.custom,
      media: media,
    );

void main() {
  test('P11.2 media and capability ids are extensible value objects', () {
    final customMedia = EngineeringMedia('vendor.bus-x');
    final capability = EngineeringPortCapability('profile.vendor.fast-mode');

    expect(customMedia, EngineeringMedia('vendor.bus-x'));
    expect(customMedia, isNot(EngineeringMedia('vendor.BUS-X')));
    expect(customMedia.toString(), 'vendor.bus-x');
    expect(capability, EngineeringPortCapability('profile.vendor.fast-mode'));
    expect(capability.toString(), 'profile.vendor.fast-mode');
    expect(() => EngineeringMedia('  '), throwsArgumentError);
    expect(() => EngineeringPortCapability(''), throwsArgumentError);

    expect(EngineeringMedia.acPower.id, 'power.ac');
    expect(EngineeringMedia.dcPower.id, 'power.dc');
    expect(EngineeringMedia.ethernet.id, 'data.ethernet');
    expect(EngineeringMedia.poe.id, 'data.poe');
    expect(EngineeringMedia.opticalFiber.id, 'data.optical-fiber');
    expect(EngineeringMedia.coax.id, 'data.coax');
    expect(EngineeringMedia.rs485.id, 'bus.rs485');
    expect(EngineeringMedia.fireLoop.id, 'life-safety.fire-loop');
  });

  test('P11.2 port media and capability collections are immutable snapshots',
      () {
    final media = <EngineeringMedia>{EngineeringMedia.ethernet};
    final capability = EngineeringPortCapability('poe.profile.8023at');
    final capabilities = <EngineeringPortCapability>{capability};
    final port = EngineeringPortSpec.identified(
      portId: PortId('uplink'),
      direction: EngineeringPortDirection.bidirectional,
      allowedConnections: {EngineeringConnectionType.ethernetCopper},
      media: media,
      capabilities: capabilities,
    );

    media.clear();
    capabilities.clear();

    expect(port.supportsMedia(EngineeringMedia.ethernet), isTrue);
    expect(port.hasCapability(capability), isTrue);
    expect(() => port.media.clear(), throwsUnsupportedError);
    expect(() => port.capabilities.clear(), throwsUnsupportedError);
  });

  test('P11.2 explicit media succeeds only when both endpoints declare it', () {
    final customMedia = EngineeringMedia('vendor.bus-x');
    final source = _component(
      'source',
      direction: EngineeringPortDirection.output,
      media: {customMedia},
    );
    final sink = _component(
      'sink',
      direction: EngineeringPortDirection.input,
      media: {customMedia},
    );
    final connection =
        _connection('source-sink', 'source', 'sink', media: customMedia);

    final graph = CanonicalEngineeringGraph(
      components: [source, sink],
      connections: [connection],
    );

    expect(graph.connection(connection.id)?.media, customMedia);
    expect(graph.hasDirectedPath(source.id, sink.id), isTrue);
  });

  test('P11.2 explicit unsupported media fails closed without inference', () {
    final source = _component(
      'source',
      direction: EngineeringPortDirection.output,
      media: {EngineeringMedia.ethernet, EngineeringMedia.poe},
    );
    final sink = _component(
      'sink',
      direction: EngineeringPortDirection.input,
      media: {EngineeringMedia.ethernet},
    );

    expect(
      () => CanonicalEngineeringGraph(
        components: [source, sink],
        connections: [
          _connection(
            'invalid-poe',
            'source',
            'sink',
            media: EngineeringMedia.poe,
          ),
        ],
      ),
      throwsArgumentError,
    );

    expect(
      CanonicalEngineeringGraphValidator.canConnect(
        from: source,
        fromPortId: PortId('link'),
        to: sink,
        toPortId: PortId('link'),
        type: EngineeringConnectionType.custom,
        media: EngineeringMedia.poe,
      ),
      isFalse,
    );
  });

  test('P11.2 legacy connections remain valid when media is not explicit', () {
    final source = _component(
      'source',
      direction: EngineeringPortDirection.output,
      media: const {},
    );
    final sink = _component(
      'sink',
      direction: EngineeringPortDirection.input,
      media: const {},
    );
    final legacy = _connection('legacy', 'source', 'sink');

    final graph = CanonicalEngineeringGraph(
      components: [source, sink],
      connections: [legacy],
    );

    expect(graph.connection(legacy.id)?.media, isNull);
    expect(graph.hasDirectedPath(source.id, sink.id), isTrue);
  });

  test('P11.2 direction validation still applies to media-aware edges', () {
    final source = _component(
      'source',
      direction: EngineeringPortDirection.input,
      media: {EngineeringMedia.ethernet},
    );
    final sink = _component(
      'sink',
      direction: EngineeringPortDirection.input,
      media: {EngineeringMedia.ethernet},
    );

    expect(
      () => CanonicalEngineeringGraph(
        components: [source, sink],
        connections: [
          _connection(
            'wrong-direction',
            'source',
            'sink',
            media: EngineeringMedia.ethernet,
          ),
        ],
      ),
      throwsArgumentError,
    );
  });

  test('P11.2 legacy adapter preserves explicit media evidence', () {
    final media = EngineeringMedia('vendor.bus-x');
    final legacy = EngineeringEdge(
      id: 'edge',
      fromNodeId: 'a',
      fromPortId: 'out',
      toNodeId: 'b',
      toPortId: 'in',
      connectionType: EngineeringConnectionType.custom,
      systemClass: EngineeringSystemClass.custom,
      media: media,
    );

    final canonical = legacy.toCanonicalEngineeringConnection();
    expect(canonical.media, media);
    expect(canonical.id, EngineeringConnectionId('edge'));
    expect(canonical.fromPortId, PortId('out'));
    expect(canonical.toPortId, PortId('in'));
  });
}
