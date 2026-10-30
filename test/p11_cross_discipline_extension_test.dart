import 'package:elecx/src/domain/canonical_engineering_graph.dart';
import 'package:elecx/src/domain/engineering_circuit_topology.dart';
import 'package:elecx/src/domain/engineering_classification.dart';
import 'package:elecx/src/domain/engineering_extension.dart';
import 'package:elecx/src/domain/engineering_graph.dart';
import 'package:elecx/src/domain/engineering_graph_validation.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

final _hvacDiscipline = EngineeringDisciplineKey('hvac');
final _bacnetSystem = EngineeringSystemKey('hvac.bacnet-mstp');
final _bacnetMedia = EngineeringMedia('bus.bacnet-mstp');
final _bacnetCapability = EngineeringPortCapability('protocol.bacnet-mstp');

EngineeringExtensionContract _hvacContract() => EngineeringExtensionContract(
      id: 'hvac-core',
      version: '1.0.0',
      disciplines: [
        EngineeringExtensionDisciplineDefinition(
          key: _hvacDiscipline,
          legacyFamily: EngineeringDiscipline.automation,
        ),
      ],
      systems: [
        EngineeringExtensionSystemDefinition(
          key: _bacnetSystem,
          disciplineKey: _hvacDiscipline,
          legacySystemFamily: EngineeringSystemClass.automationBus,
          media: [_bacnetMedia],
          portCapabilities: [_bacnetCapability],
        ),
      ],
    );

EngineeringGraphComponent _hvacComponent(String id) =>
    EngineeringGraphComponent(
      id: ComponentId(id),
      componentTypeId: 'hvac.$id',
      discipline: EngineeringDiscipline.automation,
      disciplineKey: _hvacDiscipline,
      systemClass: EngineeringSystemClass.automationBus,
      systemKey: _bacnetSystem,
      ports: [
        EngineeringPortSpec.identified(
          portId: PortId('bus'),
          direction: EngineeringPortDirection.bidirectional,
          allowedConnections: {EngineeringConnectionType.rs485},
          media: {_bacnetMedia},
          capabilities: {_bacnetCapability},
        ),
      ],
    );

EngineeringGraphConnection _bacnetConnection({
  String id = 'bacnet-edge',
  String from = 'controller',
  String to = 'sensor',
  EngineeringSystemKey? systemKey,
}) =>
    EngineeringGraphConnection(
      id: EngineeringConnectionId(id),
      fromComponentId: ComponentId(from),
      fromPortId: PortId('bus'),
      toComponentId: ComponentId(to),
      toPortId: PortId('bus'),
      connectionType: EngineeringConnectionType.rs485,
      systemClass: EngineeringSystemClass.automationBus,
      systemKey: systemKey ?? _bacnetSystem,
      media: _bacnetMedia,
    );

void main() {
  test('P11.5 legacy graph entities receive deterministic built-in keys', () {
    final component = EngineeringGraphComponent(
      id: ComponentId('camera'),
      componentTypeId: 'camera',
      discipline: EngineeringDiscipline.cctv,
      systemClass: EngineeringSystemClass.cctv,
      ports: [
        EngineeringPortSpec.identified(
          portId: PortId('poe'),
          direction: EngineeringPortDirection.input,
          allowedConnections: {EngineeringConnectionType.poe},
        ),
      ],
    );
    final connection = EngineeringGraphConnection(
      id: EngineeringConnectionId('edge'),
      fromComponentId: ComponentId('a'),
      fromPortId: PortId('x'),
      toComponentId: ComponentId('b'),
      toPortId: PortId('x'),
      connectionType: EngineeringConnectionType.poe,
      systemClass: EngineeringSystemClass.poeNetwork,
    );

    expect(component.disciplineKey, EngineeringDisciplineKey.cctv);
    expect(component.systemKey, EngineeringSystemKey.cctv);
    expect(connection.systemKey, EngineeringSystemKey.poeNetwork);
    expect(EngineeringDisciplineKey.cctv.isBuiltIn, isTrue);
    expect(EngineeringSystemKey.poeNetwork.isBuiltIn, isTrue);
  });

  test('P11.5 custom discipline and system coexist in the canonical graph', () {
    final controller = _hvacComponent('controller');
    final sensor = _hvacComponent('sensor');
    final edge = _bacnetConnection();
    final graph = CanonicalEngineeringGraph(
      components: [controller, sensor],
      connections: [edge],
    );
    final registry = EngineeringExtensionRegistry([_hvacContract()]);

    final report = registry.validateGraph(graph);

    expect(report.isValid, isTrue);
    expect(report.requireValid, returnsNormally);
    expect(graph.component(controller.id)?.systemKey, _bacnetSystem);
    expect(graph.connection(edge.id)?.systemKey, _bacnetSystem);
    expect(graph.hasDirectedPath(controller.id, sensor.id), isTrue);
  });

  test('P11.5 unknown or legacy-mismatched extension keys fail closed', () {
    final unknown = EngineeringGraphComponent(
      id: ComponentId('unknown'),
      componentTypeId: 'unknown',
      discipline: EngineeringDiscipline.automation,
      disciplineKey: EngineeringDisciplineKey('vendor.unknown'),
      systemClass: EngineeringSystemClass.automationBus,
      systemKey: EngineeringSystemKey('vendor.unknown-system'),
      ports: [
        EngineeringPortSpec.identified(
          portId: PortId('bus'),
          direction: EngineeringPortDirection.bidirectional,
          allowedConnections: {EngineeringConnectionType.rs485},
        ),
      ],
    );
    final unknownGraph = CanonicalEngineeringGraph(components: [unknown]);
    final registry = EngineeringExtensionRegistry([_hvacContract()]);
    final unknownReport = registry.validateGraph(unknownGraph);

    expect(
      unknownReport.issues.map((issue) => issue.code),
      containsAll([
        EngineeringExtensionIssueCode.unknownDisciplineKey,
        EngineeringExtensionIssueCode.unknownSystemKey,
      ]),
    );

    final mismatch = EngineeringGraphComponent(
      id: ComponentId('mismatch'),
      componentTypeId: 'hvac.mismatch',
      discipline: EngineeringDiscipline.automation,
      disciplineKey: _hvacDiscipline,
      systemClass: EngineeringSystemClass.custom,
      systemKey: _bacnetSystem,
      ports: [
        EngineeringPortSpec.identified(
          portId: PortId('bus'),
          direction: EngineeringPortDirection.bidirectional,
          allowedConnections: {EngineeringConnectionType.custom},
        ),
      ],
    );
    final mismatchReport = registry.validateGraph(
      CanonicalEngineeringGraph(components: [mismatch]),
    );
    expect(
      mismatchReport.issues.map((issue) => issue.code),
      contains(EngineeringExtensionIssueCode.systemLegacyMismatch),
    );
  });

  test('P11.5 extension declares every custom port medium and capability', () {
    final unsupportedMedia = EngineeringMedia('bus.vendor-other');
    final unsupportedCapability = EngineeringPortCapability('protocol.other');
    final component = EngineeringGraphComponent(
      id: ComponentId('invalid-device'),
      componentTypeId: 'hvac.invalid',
      discipline: EngineeringDiscipline.automation,
      disciplineKey: _hvacDiscipline,
      systemClass: EngineeringSystemClass.automationBus,
      systemKey: _bacnetSystem,
      ports: [
        EngineeringPortSpec.identified(
          portId: PortId('bus'),
          direction: EngineeringPortDirection.bidirectional,
          allowedConnections: {EngineeringConnectionType.rs485},
          media: {unsupportedMedia},
          capabilities: {unsupportedCapability},
        ),
      ],
    );
    final report =
        EngineeringExtensionRegistry([_hvacContract()]).validateGraph(
      CanonicalEngineeringGraph(components: [component]),
    );

    expect(
      report.issues.map((issue) => issue.code),
      containsAll([
        EngineeringExtensionIssueCode.unsupportedSystemMedia,
        EngineeringExtensionIssueCode.unsupportedSystemCapability,
      ]),
    );
  });

  test('P11.5 extension registry rejects cross-contract key collisions', () {
    final second = EngineeringExtensionContract(
      id: 'duplicate-hvac',
      version: '1.0.0',
      disciplines: [
        EngineeringExtensionDisciplineDefinition(
          key: _hvacDiscipline,
          legacyFamily: EngineeringDiscipline.automation,
        ),
      ],
    );

    expect(
      () => EngineeringExtensionRegistry([_hvacContract(), second]),
      throwsArgumentError,
    );
    expect(
      () => EngineeringExtensionDisciplineDefinition(
        key: EngineeringDisciplineKey.power,
        legacyFamily: EngineeringDiscipline.power,
      ),
      throwsArgumentError,
    );
    expect(
      () => EngineeringExtensionSystemDefinition(
        key: EngineeringSystemKey.powerAc,
        disciplineKey: EngineeringDisciplineKey.power,
        legacySystemFamily: EngineeringSystemClass.powerAc,
      ),
      throwsArgumentError,
    );
  });

  test('P11.5 compatibility rules distinguish systems sharing a legacy family',
      () {
    final controller = _hvacComponent('controller');
    final sensor = _hvacComponent('sensor');
    final edge = _bacnetConnection();
    final graph = CanonicalEngineeringGraph(
      components: [controller, sensor],
      connections: [edge],
    );

    final genericProfile = EngineeringCompatibilityProfile(
      id: 'generic-legacy',
      revision: '1',
      rules: [
        EngineeringConnectionCompatibilityRule(
          id: 'generic-automation',
          fromSystemClass: EngineeringSystemClass.automationBus,
          toSystemClass: EngineeringSystemClass.automationBus,
          connectionSystemClass: EngineeringSystemClass.automationBus,
          connectionType: EngineeringConnectionType.rs485,
          media: _bacnetMedia,
        ),
      ],
    );
    final genericReport = EngineeringGraphInvariantValidator.validate(
      graph: graph,
      compatibilityProfile: genericProfile,
      options: const EngineeringGraphValidationOptions(
        requireCompatibilityRule: true,
      ),
    );
    expect(genericReport.isValid, isFalse);

    final extensionProfile = EngineeringCompatibilityProfile(
      id: 'hvac',
      revision: '1',
      rules: [
        EngineeringConnectionCompatibilityRule(
          id: 'bacnet',
          fromSystemClass: EngineeringSystemClass.automationBus,
          fromSystemKey: _bacnetSystem,
          toSystemClass: EngineeringSystemClass.automationBus,
          toSystemKey: _bacnetSystem,
          connectionSystemClass: EngineeringSystemClass.automationBus,
          connectionSystemKey: _bacnetSystem,
          connectionType: EngineeringConnectionType.rs485,
          media: _bacnetMedia,
        ),
      ],
    );
    final extensionReport = EngineeringGraphInvariantValidator.validate(
      graph: graph,
      compatibilityProfile: extensionProfile,
      options: const EngineeringGraphValidationOptions(
        requireCompatibilityRule: true,
      ),
    );
    expect(extensionReport.isValid, isTrue);
  });

  test('P11.5 circuit membership cannot mix custom system keys', () {
    final otherSystem = EngineeringSystemKey('hvac.other-bus');
    final controller = _hvacComponent('controller');
    final sensor = _hvacComponent('sensor');
    final edge = _bacnetConnection();
    final graph = CanonicalEngineeringGraph(
      components: [controller, sensor],
      connections: [edge],
    );

    expect(
      () => CanonicalEngineeringTopology(
        graph: graph,
        circuits: [
          EngineeringCircuit(
            id: CircuitId('mixed'),
            systemClass: EngineeringSystemClass.automationBus,
            systemKey: otherSystem,
            connectionIds: [edge.id],
          ),
        ],
      ),
      throwsArgumentError,
    );
  });
}
