import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/electrical_routing.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/domain/vertical_core_cable_route_authoring.dart';
import 'package:elecx/src/domain/vertical_core_route_authoring.dart';
import 'package:elecx/src/domain/vertical_core_route_leg.dart';
import 'package:elecx/src/domain/vertical_core_slab_crossing_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('assembler creates one route through two slabs and one riser leg', () {
    final coreId = VerticalCoreId('VC-01');
    final slab12 = SlabId('SLAB-12');
    final slab23 = SlabId('SLAB-23');
    final level1 = LevelId('L1');
    final level2 = LevelId('L2');
    final level3 = LevelId('L3');
    const point = SurfacePointMm(100, 0);
    final ceiling1 = RoomSurfaceRef.ceiling('room-l1');
    final floor2 = RoomSurfaceRef.floor('room-l2');
    final ceiling2 = RoomSurfaceRef.ceiling('room-l2');
    final floor3 = RoomSurfaceRef.floor('room-l3');
    final plan = VerticalCoreRouteAuthoringPlan(
      verticalCoreId: coreId,
      fromLevelId: level1,
      toLevelId: level3,
      intermediateVerticalLengthMm: 3000,
      crossings: [
        VerticalCoreRouteCrossingPlan(
          verticalCoreId: coreId,
          slabId: slab12,
          fromLevelId: level1,
          toLevelId: level2,
          planPoint: const BoundaryPointMm(xMm: 100, yMm: 100),
          direction: VerticalCoreCrossingDirection.up,
          hostThicknessMm: 200,
          materialId: 'reinforced-concrete',
        ),
        VerticalCoreRouteCrossingPlan(
          verticalCoreId: coreId,
          slabId: slab23,
          fromLevelId: level2,
          toLevelId: level3,
          planPoint: const BoundaryPointMm(xMm: 100, yMm: 100),
          direction: VerticalCoreCrossingDirection.up,
          hostThicknessMm: 200,
          materialId: 'reinforced-concrete',
        ),
      ],
      verticalLegs: [
        VerticalCoreRouteLeg(
          verticalCoreId: coreId,
          fromSlabId: slab12,
          toSlabId: slab23,
          lengthMm: 3000,
        ),
      ],
    );

    final route = VerticalCoreCableRouteAuthoring.build(
      plan: plan,
      routeId: 'R-1',
      source: const ElectricalEndpointRef(componentId: 'SRC', portId: 'OUT'),
      target: const ElectricalEndpointRef(componentId: 'DST', portId: 'IN'),
      reservePercent: 0,
      segments: [
        ElectricalRouteSegment(
          surface: ceiling1,
          points: const [SurfacePointMm(0, 0), point],
        ),
        ElectricalRouteSegment(surface: floor2, points: const [point]),
        ElectricalRouteSegment(surface: ceiling2, points: const [point]),
        ElectricalRouteSegment(
          surface: floor3,
          points: const [point, SurfacePointMm(200, 0)],
        ),
      ],
      crossings: [
        VerticalCoreRouteCrossingMaterialization(
          slabId: slab12,
          penetrationId: BoundaryPenetrationId('P-12'),
          entrySurface: ceiling1,
          entryPoint: point,
          exitSurface: floor2,
          exitPoint: point,
        ),
        VerticalCoreRouteCrossingMaterialization(
          slabId: slab23,
          penetrationId: BoundaryPenetrationId('P-23'),
          entrySurface: ceiling2,
          entryPoint: point,
          exitSurface: floor3,
          exitPoint: point,
        ),
      ],
    );

    expect(route.penetrations, hasLength(2));
    expect(
      route.penetrations.map((value) => value.slabId),
      [slab12, slab23],
    );
    expect(
      route.penetrations.map((value) => value.verticalCoreId).toSet(),
      {coreId},
    );
    expect(route.verticalCoreLegs, plan.verticalLegs);
    expect(route.geometricLengthMm, 3600);
  });

  test('assembler rejects reordered slab materialization', () {
    final coreId = VerticalCoreId('VC-01');
    final slab12 = SlabId('SLAB-12');
    final slab23 = SlabId('SLAB-23');
    final level1 = LevelId('L1');
    final level2 = LevelId('L2');
    final level3 = LevelId('L3');
    final plan = VerticalCoreRouteAuthoringPlan(
      verticalCoreId: coreId,
      fromLevelId: level1,
      toLevelId: level3,
      intermediateVerticalLengthMm: 0,
      crossings: [
        VerticalCoreRouteCrossingPlan(
          verticalCoreId: coreId,
          slabId: slab12,
          fromLevelId: level1,
          toLevelId: level2,
          planPoint: const BoundaryPointMm(xMm: 100, yMm: 100),
          direction: VerticalCoreCrossingDirection.up,
          hostThicknessMm: 200,
          materialId: 'concrete',
        ),
        VerticalCoreRouteCrossingPlan(
          verticalCoreId: coreId,
          slabId: slab23,
          fromLevelId: level2,
          toLevelId: level3,
          planPoint: const BoundaryPointMm(xMm: 100, yMm: 100),
          direction: VerticalCoreCrossingDirection.up,
          hostThicknessMm: 200,
          materialId: 'concrete',
        ),
      ],
    );

    expect(
      () => VerticalCoreCableRouteAuthoring.build(
        plan: plan,
        routeId: 'R-1',
        source: const ElectricalEndpointRef(componentId: 'SRC', portId: 'OUT'),
        target: const ElectricalEndpointRef(componentId: 'DST', portId: 'IN'),
        segments: const [],
        crossings: [
          VerticalCoreRouteCrossingMaterialization(
            slabId: slab23,
            penetrationId: BoundaryPenetrationId('P-23'),
            entrySurface: RoomSurfaceRef.ceiling('room-l1'),
            entryPoint: const SurfacePointMm(100, 0),
            exitSurface: RoomSurfaceRef.floor('room-l2'),
            exitPoint: const SurfacePointMm(100, 0),
          ),
          VerticalCoreRouteCrossingMaterialization(
            slabId: slab12,
            penetrationId: BoundaryPenetrationId('P-12'),
            entrySurface: RoomSurfaceRef.ceiling('room-l2'),
            entryPoint: const SurfacePointMm(100, 0),
            exitSurface: RoomSurfaceRef.floor('room-l3'),
            exitPoint: const SurfacePointMm(100, 0),
          ),
        ],
      ),
      throwsStateError,
    );
  });
}
