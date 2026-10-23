import 'package:elecx/src/domain/boundary_penetration.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/slab_topology.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/domain/vertical_core.dart';
import 'package:elecx/src/domain/vertical_core_route_authoring.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('L1 to L3 plan keeps two SlabIds and hidden vertical Z length', () {
    final fixture = _Fixture();

    final plan = VerticalCoreRouteAuthoring.plan(
      project: fixture.project,
      verticalCoreId: fixture.coreId,
      fromLevelId: fixture.level1Id,
      toLevelId: fixture.level3Id,
      planPoint: const BoundaryPointMm(xMm: 1200, yMm: 1200),
    );

    expect(plan, isNotNull);
    expect(
      plan!.crossings.map((crossing) => crossing.slabId),
      [fixture.slab12Id, fixture.slab23Id],
    );
    expect(plan.intermediateVerticalLengthMm, 3000);
    expect(plan.penetrationLengthMm, 400);
    expect(plan.totalHiddenLengthMm, 3400);
    expect(plan.verticalLegs, hasLength(1));
    final leg = plan.verticalLegs.single;
    expect(leg.verticalCoreId, fixture.coreId);
    expect(leg.fromSlabId, fixture.slab12Id);
    expect(leg.toSlabId, fixture.slab23Id);
    expect(leg.lengthMm, 3000);
  });

  test('crossing plan materializes canonical slab and VerticalCore identity',
      () {
    final fixture = _Fixture();
    final plan = VerticalCoreRouteAuthoring.plan(
      project: fixture.project,
      verticalCoreId: fixture.coreId,
      fromLevelId: fixture.level1Id,
      toLevelId: fixture.level2Id,
      planPoint: const BoundaryPointMm(xMm: 1200, yMm: 1200),
    )!;

    final penetration = plan.crossings.single.createPenetration(
      penetrationId: 'P-12',
      routeId: 'C-1',
      entrySurface: RoomSurfaceRef.ceiling('space-l1'),
      entryPoint: const SurfacePointMm(1200, 1200),
      exitSurface: RoomSurfaceRef.floor('space-l2'),
      exitPoint: const SurfacePointMm(1200, 1200),
    );

    expect(penetration.hostKind, BoundaryPenetrationHostKind.slab);
    expect(penetration.slabId, fixture.slab12Id);
    expect(penetration.verticalCoreId, fixture.coreId);
    expect(penetration.hostThicknessMm, 200);
    expect(penetration.materialId, 'reinforced-concrete');
  });

  test('unknown VerticalCoreId fails closed', () {
    final fixture = _Fixture();

    final plan = VerticalCoreRouteAuthoring.plan(
      project: fixture.project,
      verticalCoreId: VerticalCoreId('missing'),
      fromLevelId: fixture.level1Id,
      toLevelId: fixture.level3Id,
      planPoint: const BoundaryPointMm(xMm: 1200, yMm: 1200),
    );

    expect(plan, isNull);
  });
}

final class _Fixture {
  _Fixture() {
    final core = ProjectVerticalCore(
      id: coreId,
      buildingId: buildingId,
      kind: VerticalCoreKind.riser,
      levelIds: [level1Id, level2Id, level3Id],
      footprint: const [
        BoundaryPointMm(xMm: 1000, yMm: 1000),
        BoundaryPointMm(xMm: 1400, yMm: 1000),
        BoundaryPointMm(xMm: 1400, yMm: 1400),
        BoundaryPointMm(xMm: 1000, yMm: 1400),
      ],
    );
    project = ProjectAggregateRoot(
      id: ProjectId('P1'),
      siteId: siteId,
      version: LocalProjectVersion(0),
      stores: ProjectEntityStores(
        sites: {
          siteId: ProjectSiteEntity(
            id: siteId,
            name: 'Site',
            buildingIds: [buildingId],
          ),
        },
        buildings: {
          buildingId: ProjectBuildingEntity(
            id: buildingId,
            siteId: siteId,
            name: 'Building',
            levelIds: [level1Id, level2Id, level3Id],
          ),
        },
        levels: {
          level1Id: ProjectLevelEntity(
            id: level1Id,
            buildingId: buildingId,
            name: 'L1',
            levelNumber: 1,
            elevationMm: 0,
          ),
          level2Id: ProjectLevelEntity(
            id: level2Id,
            buildingId: buildingId,
            name: 'L2',
            levelNumber: 2,
            elevationMm: 3200,
          ),
          level3Id: ProjectLevelEntity(
            id: level3Id,
            buildingId: buildingId,
            name: 'L3',
            levelNumber: 3,
            elevationMm: 6400,
          ),
        },
        slabs: {
          slab12Id: _slab(
            slab12Id,
            level1Id,
            level2Id,
            3000,
          ),
          slab23Id: _slab(
            slab23Id,
            level2Id,
            level3Id,
            6200,
          ),
        },
        verticalCores: {coreId: core},
      ),
    );
  }

  final SiteId siteId = SiteId('S1');
  final BuildingId buildingId = BuildingId('B1');
  final LevelId level1Id = LevelId('L1');
  final LevelId level2Id = LevelId('L2');
  final LevelId level3Id = LevelId('L3');
  final SlabId slab12Id = SlabId('SLAB-12');
  final SlabId slab23Id = SlabId('SLAB-23');
  final VerticalCoreId coreId = VerticalCoreId('VC-01');

  late final ProjectAggregateRoot project;

  ProjectSlab _slab(
    SlabId id,
    LevelId below,
    LevelId above,
    int bottomElevationMm,
  ) =>
      ProjectSlab(
        id: id,
        buildingId: buildingId,
        kind: SlabKind.interLevel,
        belowLevelId: below,
        aboveLevelId: above,
        bottomElevationMm: bottomElevationMm,
        thicknessMm: 200,
        materialId: 'reinforced-concrete',
        footprint: const [
          BoundaryPointMm(xMm: 0, yMm: 0),
          BoundaryPointMm(xMm: 4000, yMm: 0),
          BoundaryPointMm(xMm: 4000, yMm: 3000),
          BoundaryPointMm(xMm: 0, yMm: 3000),
        ],
      );
}
