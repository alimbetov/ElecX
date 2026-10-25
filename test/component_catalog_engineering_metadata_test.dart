import 'package:elecx/src/domain/component_catalog_engineering_metadata.dart';
import 'package:elecx/src/domain/component_catalog_v2.dart';
import 'package:elecx/src/domain/component_placement.dart';
import 'package:elecx/src/domain/engineering_graph.dart';
import 'package:flutter_test/flutter_test.dart';

Set<EngineeringConnectionType> connectionsFor(ComponentCatalogEntryV2 entry) =>
    entry.ports.expand((port) => port.allowedConnections).toSet();

void main() {
  test('incomplete catalog facts are not auto-configuration ready', () {
    final socket = ComponentCatalogV2.require('power.socket.general');
    final record = ComponentCatalogEngineeringRecord(
      entry: socket,
      metadata: ComponentCatalogEngineeringMetadata(
        componentTypeId: socket.id,
        compatibility: ComponentCompatibilityProfile(
          systems: {socket.systemClass},
          connections: connectionsFor(socket),
          hostKinds: {ComponentHostKind.roomSurface},
        ),
      ),
    );

    expect(record.metadata.isAutoConfigurationReady, isFalse);
    expect(
      record.supports(systemClass: socket.systemClass),
      isFalse,
    );
    expect(
      record.supports(
        systemClass: socket.systemClass,
        requireAutoConfigurationReady: false,
      ),
      isTrue,
    );
  });

  test('verified physical and source facts unlock candidate selection', () {
    final camera = ComponentCatalogV2.require('cctv.camera.poe');
    final record = ComponentCatalogEngineeringRecord(
      entry: camera,
      metadata: ComponentCatalogEngineeringMetadata(
        componentTypeId: camera.id,
        physicalEnvelope: ComponentPhysicalEnvelopeMm(
          widthMm: 100,
          heightMm: 100,
          depthMm: 80,
        ),
        source: ComponentCatalogSourceMetadata(
          manufacturer: 'Test Manufacturer',
          model: 'Test Model',
          revision: 'rev-a',
        ),
        compatibility: ComponentCompatibilityProfile(
          systems: {camera.systemClass},
          connections: connectionsFor(camera),
          hostKinds: {ComponentHostKind.roomSurface},
        ),
      ),
    );
    final registry = ComponentCatalogEngineeringRegistry([record]);

    final candidates = registry.compatibleCandidates(
      systemClass: EngineeringSystemClass.cctv,
      connectionType: EngineeringConnectionType.poe,
      hostKind: ComponentHostKind.roomSurface,
    );

    expect(record.metadata.isAutoConfigurationReady, isTrue);
    expect(candidates, [record]);
  });

  test('metadata cannot contradict catalog port media', () {
    final camera = ComponentCatalogV2.require('cctv.camera.poe');

    expect(
      () => ComponentCatalogEngineeringRecord(
        entry: camera,
        metadata: ComponentCatalogEngineeringMetadata(
          componentTypeId: camera.id,
          compatibility: ComponentCompatibilityProfile(
            systems: {camera.systemClass},
            connections: {EngineeringConnectionType.fiber},
            hostKinds: {ComponentHostKind.roomSurface},
          ),
        ),
      ),
      throwsArgumentError,
    );
  });
}
