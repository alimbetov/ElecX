import 'package:elecx/src/domain/component_placement.dart';
import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('canonical placement supports typed slab and core hosts', () {
    final onSlab = ComponentPlacement(
      componentId: ComponentId('component-1'),
      host: SlabComponentHost(SlabId('slab-1')),
      position: const HostLocalPointMm(uMm: 1200, vMm: 800),
      clearance: ComponentClearanceMm(front: 600),
    );
    final inCore = ComponentPlacement(
      componentId: ComponentId('component-2'),
      host: VerticalCoreComponentHost(VerticalCoreId('core-1')),
      position: const HostLocalPointMm(uMm: 100, vMm: 200),
    );

    expect(onSlab.host.kind, ComponentHostKind.slab);
    expect(onSlab.host.stableKey, 'slab:slab-1');
    expect(onSlab.clearance.front, 600);
    expect(inCore.host.kind, ComponentHostKind.verticalCore);
  });

  test('negative clearance fails closed', () {
    expect(
      () => ComponentClearanceMm(front: -1),
      throwsArgumentError,
    );
  });

  test('legacy electrical placement projects without changing identity', () {
    final legacy = ElectricalComponentPlacement(
      id: 'socket-1',
      type: ElectricalComponentType.socketOutlet,
      surface: RoomSurfaceRef.wall('room-1', 0),
      position: const SurfacePointMm(1200, 300),
      label: 'Socket',
      rotationDegrees: 90,
    );

    final canonical = legacy.toCanonicalComponentPlacement();

    expect(canonical.componentId, ComponentId('socket-1'));
    expect(canonical.position.uMm, 1200);
    expect(canonical.position.vMm, 300);
    expect(canonical.orientation.yawDegrees, 90);
    expect(canonical.host, isA<RoomSurfaceComponentHost>());
    expect(
      (canonical.host as RoomSurfaceComponentHost).isCanonical,
      isFalse,
    );
  });

  test('boundary-edge wall host is canonical', () {
    final host = RoomSurfaceComponentHost(
      RoomSurfaceRef.wallByBoundaryEdge(
        'room-1',
        BoundaryEdgeId('edge-1'),
      ),
    );

    expect(host.isCanonical, isTrue);
    expect(host.stableKey, 'surface:room-1:boundary:edge-1');
  });
}
