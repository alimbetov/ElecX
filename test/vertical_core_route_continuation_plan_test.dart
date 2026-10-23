import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_space_semantics.dart';
import 'package:elecx/src/domain/slab_topology.dart';
import 'package:elecx/src/domain/vertical_core.dart';
import 'package:elecx/src/domain/vertical_core_route_authoring.dart';
import 'package:elecx/src/domain/vertical_core_route_continuation_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('multi-level continuation requires explicit target SpaceId per level', () {
    final fixture = _Fixture();
    final routePlan = VerticalCoreRouteAuthoring.plan(
      project: fixture.project,
      verticalCoreId: fixture.coreId,
      fromLevelId: fixture.level1Id,
      toLevelId: fixture.level3Id,
      planPoint: const BoundaryPointMm(xMm: 1200, yMm: 1200),
    )!;

    final continuation = VerticalCoreRouteContinuationPlanner.resolve(
      project: fixture.project,
      routePlan: routePlan,
      targetSpaceByLevel: {
        fixture.level2Id: fixture.space2Id,
        fixture.level3Id: fixture.space3Id,
      },
    );

    expect(continuation, isNotNull);
    expect(continuation!.hops, hasLength(2));
    expect(
      continuation.hops.map((hop) => hop.slabId),
      [fixture.slab12Id, fixture.slab23Id],
    );
    expect(
      continuation.hops.map((hop) => hop.toSpaceId),
      [fixture.space2Id, fixture.space3Id],
    );
    expect(
      continuation.hops.map((hop) => hop.verticalCoreId).toSet(),
      {fixture.coreId},
    );
  });

  test('missing intermediate target SpaceId fails closed', () {
    final fixture = _Fixture();
    final routePlan = VerticalCoreRouteAuthoring.plan(
      project: fixture.project,
      verticalCoreId: fixture.coreId,
      fromLevelId: fixture.level1Id,
      toLevelId: fixture.level3Id,
      planPoint: const BoundaryPointMm(xMm: 1200, yMm: 1200),
    )!;

    expect(
      VerticalCoreRouteContinuationPlanner.resolve(
        project: fixture.project,
        routePlan: routePlan,
        targetSpaceByLevel: {fixture.level3Id: fixture.space3Id},
      ),
      isNull,
    );
  });

  test('SpaceId from the wrong target level fails closed', () {
    final fixture = _Fixture();
    final routePlan = VerticalCoreRouteAuthoring.plan(
      project: fixture.project,
      verticalCoreId: fixture.coreId,
      fromLevelId: fixture.level1Id,
      toLevelId: fixture.level3Id,
      planPoint: const BoundaryPointMm(xMm: 1200, yMm: 1200),
    )!;

    expect(
      VerticalCoreRouteContinuationPlanner.resolve(
        project: fixture.project,
        routePlan: routePlan,
        targetSpaceByLevel: {
          fixture.level2Id: fixture.space3Id,
          fixture.level3Id: fixture.space3Id,
        },
      ),
      isNull,
    );
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
            spaceIds: [space1Id],
          ),
          level2Id: ProjectLevelEntity(
            id: level2Id,
            buildingId: buildingId,
            name: 'L2',
            levelNumber: 2,
            elevationMm: 3200,
            spaceIds: [space2Id],
          ),
          level3Id: ProjectLevelEntity(
            id: level3Id,
            buildingId: buildingId,
            name: 'L3',
            levelNumber: 3,
            elevationMm: 6400,
            spaceIds: [space3Id],
          ),
        },
        spaces: {
          space1Id: ProjectSpaceEntity(
            id: space1Id,
            levelId: level1Id,
            name: 'Room L1',
            usage: SpaceUsage.serviceShaft,
          ),
          space2Id: ProjectSpaceEntity(
            id: space2Id,
            levelId: level2Id,
            name: 'Room L2',
            usage: SpaceUsage.serviceShaft,
          ),
          space3Id: ProjectSpaceEntity(
            id: space3Id,
            levelId: level3Id,
            name: 'Room L3',
            usage: SpaceUsage.serviceShaft,
          ),
        },
        slabs: {
          slab12Id: _slab(slab12Id, level1Id, level2Id, 3000),
          slab23Id: _slab(slab23Id, level2Id, level3Id, 6200),
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
  final SpaceId space1Id = SpaceId('SPACE-1');
  final SpaceId space2Id = SpaceId('SPACE-2');
  final SpaceId space3Id = SpaceId('SPACE-3');
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
