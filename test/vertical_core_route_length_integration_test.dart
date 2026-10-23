import 'package:elecx/src/domain/boundary_penetration.dart';
import 'package:elecx/src/domain/electrical_routing.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/domain/vertical_core_route_leg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('multi-level riser route counts slab and hidden VerticalCore length', () {
    final coreId = VerticalCoreId('VC-01');
    final slab12 = SlabId('SLAB-12');
    final slab23 = SlabId('SLAB-23');
    const point = SurfacePointMm(100, 0);
    final ceiling1 = RoomSurfaceRef.ceiling('room-l1');
    final floor2 = RoomSurfaceRef.floor('room-l2');
    final ceiling2 = RoomSurfaceRef.ceiling('room-l2');
    final floor3 = RoomSurfaceRef.floor('room-l3');

    final penetration12 = BoundaryPenetration.slab(
      id: 'P-12',
      slabId: slab12,
      verticalCoreId: coreId,
      entrySurface: ceiling1,
      entryPoint: point,
      exitSurface: floor2,
      exitPoint: point,
      hostThicknessMm: 200,
      routeId: 'R-1',
    );
    final penetration23 = BoundaryPenetration.slab(
      id: 'P-23',
      slabId: slab23,
      verticalCoreId: coreId,
      entrySurface: ceiling2,
      entryPoint: point,
      exitSurface: floor3,
      exitPoint: point,
      hostThicknessMm: 200,
      routeId: 'R-1',
    );

    final route = ElectricalCableRoute(
      id: 'R-1',
      source: const ElectricalEndpointRef(componentId: 'SRC', portId: 'OUT'),
      target: const ElectricalEndpointRef(componentId: 'DST', portId: 'IN'),
      reservePercent: 0,
      segments: [
        ElectricalRouteSegment(
          surface: ceiling1,
          points: const [
            SurfacePointMm(0, 0),
            point,
          ],
        ),
        ElectricalRouteSegment(surface: floor2, points: const [point]),
        ElectricalRouteSegment(surface: ceiling2, points: const [point]),
        ElectricalRouteSegment(
          surface: floor3,
          points: const [
            point,
            SurfacePointMm(200, 0),
          ],
        ),
      ],
      penetrations: [penetration12, penetration23],
      verticalCoreLegs: [
        VerticalCoreRouteLeg(
          verticalCoreId: coreId,
          fromSlabId: slab12,
          toSlabId: slab23,
          lengthMm: 3000,
        ),
      ],
    );

    expect(route.visibleLengthMm, 200);
    expect(route.hiddenPenetrationLengthMm, 400);
    expect(route.hiddenVerticalCoreLengthMm, 3000);
    expect(route.geometricLengthMm, 3600);
    expect(route.installationLengthMm, 3600);
  });

  test('hidden floor-to-ceiling jump fails without matching VerticalCore leg', () {
    final coreId = VerticalCoreId('VC-01');
    final slab12 = SlabId('SLAB-12');
    final slab23 = SlabId('SLAB-23');
    const point = SurfacePointMm(100, 0);
    final ceiling1 = RoomSurfaceRef.ceiling('room-l1');
    final floor2 = RoomSurfaceRef.floor('room-l2');
    final ceiling2 = RoomSurfaceRef.ceiling('room-l2');
    final floor3 = RoomSurfaceRef.floor('room-l3');

    expect(
      () => ElectricalCableRoute(
        id: 'R-1',
        source:
            const ElectricalEndpointRef(componentId: 'SRC', portId: 'OUT'),
        target: const ElectricalEndpointRef(componentId: 'DST', portId: 'IN'),
        segments: [
          ElectricalRouteSegment(surface: ceiling1, points: const [point]),
          ElectricalRouteSegment(surface: floor2, points: const [point]),
          ElectricalRouteSegment(surface: ceiling2, points: const [point]),
          ElectricalRouteSegment(surface: floor3, points: const [point]),
        ],
        penetrations: [
          BoundaryPenetration.slab(
            id: 'P-12',
            slabId: slab12,
            verticalCoreId: coreId,
            entrySurface: ceiling1,
            entryPoint: point,
            exitSurface: floor2,
            exitPoint: point,
            hostThicknessMm: 200,
            routeId: 'R-1',
          ),
          BoundaryPenetration.slab(
            id: 'P-23',
            slabId: slab23,
            verticalCoreId: coreId,
            entrySurface: ceiling2,
            entryPoint: point,
            exitSurface: floor3,
            exitPoint: point,
            hostThicknessMm: 200,
            routeId: 'R-1',
          ),
        ],
      ),
      throwsArgumentError,
    );
  });
}
