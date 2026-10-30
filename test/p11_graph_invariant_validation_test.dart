import 'package:elecx/src/domain/canonical_engineering_graph.dart';
import 'package:elecx/src/domain/engineering_circuit_topology.dart';
import 'package:elecx/src/domain/engineering_graph.dart';
import 'package:elecx/src/domain/engineering_graph_validation.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

EngineeringGraphComponent _component(
  String id, {
  required EngineeringSystemClass systemClass,
  required EngineeringPortDirection direction,
  required EngineeringConnectionType connectionType,
  EngineeringMedia? media,
}) =>
    EngineeringGraphComponent(
      id: ComponentId(id),
      componentTypeId: 'p11.validation.$id',
      discipline: EngineeringDiscipline.data,
      systemClass: systemClass,
      ports: [
        EngineeringPortSpec.identified(
          portId: PortId('link'),
          direction: direction,
          allowedConnections: {connectionType},
          media: media == null ? const {} : {media},
        ),
      ],
    );

EngineeringGraphConnection _connection({
  required String id,
  required String from,
  required String to,
  required EngineeringSystemClass systemClass,
  required EngineeringConnectionType connectionType,
  EngineeringMedia? media,
  CircuitId? circuitId,
}) =>
    EngineeringGraphConnection(
      id: EngineeringConnectionId(id),
      fromComponentId: ComponentId(from),
      fromPortId: PortId('link'),
      toComponentId: ComponentId(to),
      toPortId: PortId('link'),
      connectionType: connectionType,
      systemClass: systemClass,
      media: media,
      circuitId: circuitId,
    );

EngineeringConnectionCompatibilityRule _poeRule({
  String id = 'poe-camera',
}) =>
    EngineeringConnectionCompatibilityRule(
      id: id,
      fromSystemClass: EngineeringSystemClass.structuredCabling,
      toSystemClass: EngineeringSystemClass.cctv,
      connectionSystemClass: EngineeringSystemClass.poeNetwork,
      connectionType: EngineeringConnectionType.poe,
      media: EngineeringMedia.poe,
    );

void main() {
  test('P11.4 exact compatibility profile accepts an allowed transition', () {
    final source = _component(
      'switch',
      systemClass: EngineeringSystemClass.structuredCabling,
      direction: EngineeringPortDirection.output,
      connectionType: EngineeringConnectionType.poe,
      media: EngineeringMedia.poe,
    );
    final camera = _component(
      'camera',
      systemClass: EngineeringSystemClass.cctv,
      direction: EngineeringPortDirection.input,
      connectionType: EngineeringConnectionType.poe,
      media: EngineeringMedia.poe,
    );
    final graph = CanonicalEngineeringGraph(
      components: [source, camera],
      connections: [
        _connection(
          id: 'switch-camera',
          from: 'switch',
          to: 'camera',
          systemClass: EngineeringSystemClass.poeNetwork,
          connectionType: EngineeringConnectionType.poe,
          media: EngineeringMedia.poe,
        ),
      ],
    );
    final profile = EngineeringCompatibilityProfile(
      id: 'project-profile',
      revision: '1',
      rules: [_poeRule()],
    );

    final report = EngineeringGraphInvariantValidator.validate(
      graph: graph,
      compatibilityProfile: profile,
      options: const EngineeringGraphValidationOptions(
        requireCompatibilityRule: true,
        requireExplicitMedia: true,
      ),
    );

    expect(report.isValid, isTrue);
    expect(report.issues, isEmpty);
    expect(report.requireValid, returnsNormally);
  });

  test('P11.4 reversed or unsupported system transition fails closed', () {
    final camera = _component(
      'camera',
      systemClass: EngineeringSystemClass.cctv,
      direction: EngineeringPortDirection.output,
      connectionType: EngineeringConnectionType.poe,
      media: EngineeringMedia.poe,
    );
    final switchNode = _component(
      'switch',
      systemClass: EngineeringSystemClass.structuredCabling,
      direction: EngineeringPortDirection.input,
      connectionType: EngineeringConnectionType.poe,
      media: EngineeringMedia.poe,
    );
    final graph = CanonicalEngineeringGraph(
      components: [camera, switchNode],
      connections: [
        _connection(
          id: 'camera-switch',
          from: 'camera',
          to: 'switch',
          systemClass: EngineeringSystemClass.poeNetwork,
          connectionType: EngineeringConnectionType.poe,
          media: EngineeringMedia.poe,
        ),
      ],
    );
    final profile = EngineeringCompatibilityProfile(
      id: 'project-profile',
      revision: '1',
      rules: [_poeRule()],
    );

    final report = EngineeringGraphInvariantValidator.validate(
      graph: graph,
      compatibilityProfile: profile,
      options: const EngineeringGraphValidationOptions(
        requireCompatibilityRule: true,
      ),
    );

    expect(report.isValid, isFalse);
    expect(
      report.issues.single.code,
      EngineeringGraphValidationIssueCode.compatibilityRuleMissing,
    );
    expect(report.requireValid, throwsStateError);
  });

  test('P11.4 custom media compatibility does not require enum extension', () {
    final customMedia = EngineeringMedia('vendor.secure-bus');
    final source = _component(
      'source',
      systemClass: EngineeringSystemClass.custom,
      direction: EngineeringPortDirection.output,
      connectionType: EngineeringConnectionType.custom,
      media: customMedia,
    );
    final sink = _component(
      'sink',
      systemClass: EngineeringSystemClass.custom,
      direction: EngineeringPortDirection.input,
      connectionType: EngineeringConnectionType.custom,
      media: customMedia,
    );
    final graph = CanonicalEngineeringGraph(
      components: [source, sink],
      connections: [
        _connection(
          id: 'custom-link',
          from: 'source',
          to: 'sink',
          systemClass: EngineeringSystemClass.custom,
          connectionType: EngineeringConnectionType.custom,
          media: customMedia,
        ),
      ],
    );
    final profile = EngineeringCompatibilityProfile(
      id: 'vendor-profile',
      revision: '2026.10',
      rules: [
        EngineeringConnectionCompatibilityRule(
          id: 'vendor-secure-bus',
          fromSystemClass: EngineeringSystemClass.custom,
          toSystemClass: EngineeringSystemClass.custom,
          connectionSystemClass: EngineeringSystemClass.custom,
          connectionType: EngineeringConnectionType.custom,
          media: customMedia,
        ),
      ],
    );

    final report = EngineeringGraphInvariantValidator.validate(
      graph: graph,
      compatibilityProfile: profile,
      options: const EngineeringGraphValidationOptions(
        requireCompatibilityRule: true,
        requireExplicitMedia: true,
      ),
    );

    expect(report.isValid, isTrue);
  });

  test('P11.4 explicit-media gate catches legacy null media', () {
    final source = _component(
      'source',
      systemClass: EngineeringSystemClass.custom,
      direction: EngineeringPortDirection.output,
      connectionType: EngineeringConnectionType.custom,
    );
    final sink = _component(
      'sink',
      systemClass: EngineeringSystemClass.custom,
      direction: EngineeringPortDirection.input,
      connectionType: EngineeringConnectionType.custom,
    );
    final graph = CanonicalEngineeringGraph(
      components: [source, sink],
      connections: [
        _connection(
          id: 'legacy-link',
          from: 'source',
          to: 'sink',
          systemClass: EngineeringSystemClass.custom,
          connectionType: EngineeringConnectionType.custom,
        ),
      ],
    );

    final report = EngineeringGraphInvariantValidator.validate(
      graph: graph,
      options: const EngineeringGraphValidationOptions(
        requireExplicitMedia: true,
      ),
    );

    expect(report.isValid, isFalse);
    expect(
      report.issues.single.code,
      EngineeringGraphValidationIssueCode.explicitMediaRequired,
    );
  });

  test('P11.4 legacy null media can be explicitly allowed by a profile rule', () {
    final source = _component(
      'source',
      systemClass: EngineeringSystemClass.custom,
      direction: EngineeringPortDirection.output,
      connectionType: EngineeringConnectionType.custom,
    );
    final sink = _component(
      'sink',
      systemClass: EngineeringSystemClass.custom,
      direction: EngineeringPortDirection.input,
      connectionType: EngineeringConnectionType.custom,
    );
    final graph = CanonicalEngineeringGraph(
      components: [source, sink],
      connections: [
        _connection(
          id: 'legacy-link',
          from: 'source',
          to: 'sink',
          systemClass: EngineeringSystemClass.custom,
          connectionType: EngineeringConnectionType.custom,
        ),
      ],
    );
    final profile = EngineeringCompatibilityProfile(
      id: 'migration-profile',
      revision: '1',
      rules: [
        EngineeringConnectionCompatibilityRule(
          id: 'legacy-custom',
          fromSystemClass: EngineeringSystemClass.custom,
          toSystemClass: EngineeringSystemClass.custom,
          connectionSystemClass: EngineeringSystemClass.custom,
          connectionType: EngineeringConnectionType.custom,
          media: EngineeringMedia('vendor.future-media'),
          allowUnspecifiedMedia: true,
        ),
      ],
    );

    final report = EngineeringGraphInvariantValidator.validate(
      graph: graph,
      compatibilityProfile: profile,
      options: const EngineeringGraphValidationOptions(
        requireCompatibilityRule: true,
      ),
    );

    expect(report.isValid, isTrue);
  });

  test('P11.4 strict circuit resolution requires canonical topology evidence',
      () {
    final circuitId = CircuitId('circuit-1');
    final source = _component(
      'source',
      systemClass: EngineeringSystemClass.custom,
      direction: EngineeringPortDirection.output,
      connectionType: EngineeringConnectionType.custom,
    );
    final sink = _component(
      'sink',
      systemClass: EngineeringSystemClass.custom,
      direction: EngineeringPortDirection.input,
      connectionType: EngineeringConnectionType.custom,
    );
    final connection = _connection(
      id: 'edge',
      from: 'source',
      to: 'sink',
      systemClass: EngineeringSystemClass.custom,
      connectionType: EngineeringConnectionType.custom,
      circuitId: circuitId,
    );
    final graph = CanonicalEngineeringGraph(
      components: [source, sink],
      connections: [connection],
    );

    final unresolved = EngineeringGraphInvariantValidator.validate(
      graph: graph,
      options: const EngineeringGraphValidationOptions(
        requireResolvedCircuitIds: true,
      ),
    );
    expect(
      unresolved.issues.single.code,
      EngineeringGraphValidationIssueCode.unresolvedCircuit,
    );

    final circuit = EngineeringCircuit(
      id: circuitId,
      systemClass: EngineeringSystemClass.custom,
      connectionIds: [connection.id],
    );
    final topology = CanonicalEngineeringTopology(
      graph: graph,
      circuits: [circuit],
    );
    final resolved = EngineeringGraphInvariantValidator.validate(
      graph: graph,
      topology: topology,
      options: const EngineeringGraphValidationOptions(
        requireResolvedCircuitIds: true,
      ),
    );
    expect(resolved.isValid, isTrue);
  });

  test('P11.4 validator rejects topology from another graph instance', () {
    CanonicalEngineeringGraph graph(String suffix) =>
        CanonicalEngineeringGraph(
          components: [
            _component(
              'source-$suffix',
              systemClass: EngineeringSystemClass.custom,
              direction: EngineeringPortDirection.output,
              connectionType: EngineeringConnectionType.custom,
            ),
            _component(
              'sink-$suffix',
              systemClass: EngineeringSystemClass.custom,
              direction: EngineeringPortDirection.input,
              connectionType: EngineeringConnectionType.custom,
            ),
          ],
        );

    final authoritative = graph('a');
    final foreign = graph('b');
    final topology = CanonicalEngineeringTopology(graph: foreign);
    final report = EngineeringGraphInvariantValidator.validate(
      graph: authoritative,
      topology: topology,
    );

    expect(
      report.issues.single.code,
      EngineeringGraphValidationIssueCode.topologyGraphMismatch,
    );
  });

  test('P11.4 compatibility profile is immutable and unambiguous', () {
    final rules = <EngineeringConnectionCompatibilityRule>[_poeRule()];
    final profile = EngineeringCompatibilityProfile(
      id: 'profile',
      revision: '1',
      rules: rules,
    );
    rules.clear();

    expect(profile.rules, hasLength(1));
    expect(() => profile.rules.clear(), throwsUnsupportedError);
    expect(
      () => EngineeringCompatibilityProfile(
        id: 'profile',
        revision: '1',
        rules: [_poeRule(id: 'first'), _poeRule(id: 'second')],
      ),
      throwsArgumentError,
    );
    expect(
      () => EngineeringCompatibilityProfile(
        id: 'profile',
        revision: '1',
        rules: [_poeRule(), _poeRule()],
      ),
      throwsArgumentError,
    );
    expect(
      () => EngineeringCompatibilityProfile(
        id: 'legacy-ambiguous',
        revision: '1',
        rules: [
          EngineeringConnectionCompatibilityRule(
            id: 'ethernet-fallback',
            fromSystemClass: EngineeringSystemClass.custom,
            toSystemClass: EngineeringSystemClass.custom,
            connectionSystemClass: EngineeringSystemClass.custom,
            connectionType: EngineeringConnectionType.custom,
            media: EngineeringMedia.ethernet,
            allowUnspecifiedMedia: true,
          ),
          EngineeringConnectionCompatibilityRule(
            id: 'poe-fallback',
            fromSystemClass: EngineeringSystemClass.custom,
            toSystemClass: EngineeringSystemClass.custom,
            connectionSystemClass: EngineeringSystemClass.custom,
            connectionType: EngineeringConnectionType.custom,
            media: EngineeringMedia.poe,
            allowUnspecifiedMedia: true,
          ),
        ],
      ),
      throwsArgumentError,
    );
    expect(
      () => EngineeringConnectionCompatibilityRule(
        id: 'invalid',
        fromSystemClass: EngineeringSystemClass.custom,
        toSystemClass: EngineeringSystemClass.custom,
        connectionSystemClass: EngineeringSystemClass.custom,
        connectionType: EngineeringConnectionType.custom,
        allowUnspecifiedMedia: true,
      ),
      throwsArgumentError,
    );
  });
}
