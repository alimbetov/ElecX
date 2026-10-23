import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/slab_topology.dart';
import 'package:elecx/src/domain/vertical_core.dart';
import 'package:elecx/src/domain/vertical_core_path_resolver.dart';
import 'package:elecx/src/domain/vertical_core_slab_crossing_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VerticalCorePathResolver', () {
    test('L1 to L3 resolves ordered physical slab chain without teleport', () {
      final fixture = _Fixture();

      final path = VerticalCorePathResolver.resolve(
        project: fixture.project,
        core: fixture.core,
        fromLevelId: fixture.level1Id,
        toLevelId: fixture.level3Id,
        planPoint: const BoundaryPointMm(xMm: 1200, yMm: 1200),
      );

      expect(path, isNotNull);
      expect(path!.direction, VerticalCoreCrossingDirection.up);
      expect(
        path.crossings.map((crossing) => crossing.slabId),
        [fixture.slab12Id, fixture.slab23Id],
      );
      expect(
        path.crossings.map((crossing) => crossing.fromLevelId),
        [fixture.level1Id, fixture.level2Id],
      );
      expect(
        path.crossings.map((crossing) => crossing.toLevelId),
        [fixture.level2Id, fixture.level3Id],
      );
    });

    test('reverse path crosses the same slabs in reverse order', () {
      final fixture = _Fixture();

      final path = VerticalCorePathResolver.resolve(
        project: fixture.project,
        core: fixture.core,
        fromLevelId: fixture.level3Id,
        toLevelId: fixture.level1Id,
        planPoint: const BoundaryPointMm(xMm: 1200, yMm: 1200),
      );

      expect(path, isNotNull);
      expect(path!.direction, VerticalCoreCrossingDirection.down);
      expect(
        path.crossings.map((crossing) => crossing.slabId),
        [fixture.slab23Id, fixture.slab12Id],
      );
    });

    test('missing intermediate slab rejects the whole multi-level path', () {
      final fixture = _Fixture(includeUpperSlab: false);

      final path = VerticalCorePathResolver.resolve(
        project: fixture.project,
        core: fixture.core,
        fromLevelId: fixture.level1Id,
        toLevelId: fixture.level3Id,
        planPoint: const BoundaryPointMm(xMm: 1200, yMm: 1200),
      );

      expect(path, isNull);
    });

    test('point outside riser footprint rejects every path', () {
      final fixture = _Fixture();

      final path = VerticalCorePathResolver.resolve(
        project: fixture.project,
        core: fixture.core,
        fromLevelId: fixture.level1Id,
        toLevelId: fixture.level3Id,
        planPoint: const BoundaryPointMm(xMm: 2000, yMm: 2000),
      );

      expect(path, isNull);
    });
  });
}

final class _Fixture {
  _Fixture({this.includeUpperSlab = true}) {
    final slab12 = _slab(
      id: slab12Id,
      below: level1Id,
      above: level2Id,
      bottomElevationMm: 3000,
    );
    final slab23 = _slab(
      id: slab23Id,
      below: level2Id,
      above: level3Id,
      bottomElevationMm: 6200,
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
          slab12Id: slab12,
          if (includeUpperSlab) slab23Id: slab23,
        },
      ),
    );

    core = ProjectVerticalCore(
      id: VerticalCoreId('VC-01'),
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
  }

  final bool includeUpperSlab;
  final SiteId siteId = SiteId('S1');
  final BuildingId buildingId = BuildingId('B1');
  final LevelId level1Id = LevelId('L1');
  final LevelId level2Id = LevelId('L2');
  final LevelId level3Id = LevelId('L3');
  final SlabId slab12Id = SlabId('SLAB-12');
  final SlabId slab23Id = SlabId('SLAB-23');

  late final ProjectAggregateRoot project;
  late final ProjectVerticalCore core;

  ProjectSlab _slab({
    required SlabId id,
    required LevelId below,
    required LevelId above,
    required int bottomElevationMm,
  }) =>
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
