import 'package:elecx/src/domain/boundary_penetration.dart';
import 'package:elecx/src/domain/electrical_routing.dart';
import 'package:elecx/src/domain/hosted_routing.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/route_host.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('slab requirement propagates stable VerticalCore identity', () {
    final coreId = VerticalCoreId('VC-01');
    final slabId = SlabId('SLAB-12');
    final requirement = BoundaryPenetrationRequirement(
      hostKind: BoundaryPenetrationHostKind.slab,
      hostThicknessMm: 200,
      materialId: 'reinforced-concrete',
      slabId: slabId,
      verticalCoreId: coreId,
    );

    final penetration = requirement.create(
      penetrationId: 'P-12',
      routeId: 'R-1',
      entrySurface: RoomSurfaceRef.ceiling('room-l1'),
      entryPoint: const SurfacePointMm(100, 100),
      exitSurface: RoomSurfaceRef.floor('room-l2'),
      exitPoint: const SurfacePointMm(100, 100),
    );

    expect(penetration.slabId, slabId);
    expect(penetration.verticalCoreId, coreId);
  });

  test('wall penetration rejects accidental VerticalCore identity', () {
    expect(
      () => BoundaryPenetration.normal(
        id: 'P-WALL',
        hostKind: BoundaryPenetrationHostKind.wall,
        entrySurface: RoomSurfaceRef.wall('room-a', 0),
        entryPoint: const SurfacePointMm(100, 100),
        exitSurface: RoomSurfaceRef.wall('room-b', 0),
        exitPoint: const SurfacePointMm(100, 100),
        hostThicknessMm: 180,
        routeId: 'R-1',
        verticalCoreId: VerticalCoreId('VC-01'),
      ),
      throwsArgumentError,
    );
  });

  test('HostedRouteAdapter preserves SlabId and VerticalCoreId', () {
    final coreId = VerticalCoreId('VC-01');
    final slabId = SlabId('SLAB-12');
    final ceiling = RoomSurfaceRef.ceiling('room-l1');
    final floor = RoomSurfaceRef.floor('room-l2');
    const point = SurfacePointMm(100, 100);
    final penetration = BoundaryPenetration.slab(
      id: 'P-12',
      slabId: slabId,
      verticalCoreId: coreId,
      entrySurface: ceiling,
      entryPoint: point,
      exitSurface: floor,
      exitPoint: point,
      hostThicknessMm: 200,
      routeId: 'R-1',
    );
    final route = ElectricalCableRoute(
      id: 'R-1',
      source: const ElectricalEndpointRef(componentId: 'SRC', portId: 'OUT'),
      target: const ElectricalEndpointRef(componentId: 'DST', portId: 'IN'),
      segments: [
        ElectricalRouteSegment(surface: ceiling, points: const [point]),
        ElectricalRouteSegment(surface: floor, points: const [point]),
      ],
      penetrations: [penetration],
    );

    final hosted = HostedRouteAdapter.fromIndoor(route);
    final transition = hosted.transitions.single;

    expect(transition.kind, RouteHostTransitionKind.levelPenetration);
    expect(transition.slabId, slabId);
    expect(transition.verticalCoreId, coreId);
  });
}
