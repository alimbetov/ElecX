import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/slab_topology.dart';
import 'package:elecx/src/domain/vertical_core.dart';
import 'package:elecx/src/domain/vertical_core_slab_crossing_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VerticalCoreSlabCrossingResolver', () {
    test('resolves upward crossing through exact canonical SlabId', () {
      final fixture = _Fixture();

      final crossing = VerticalCoreSlabCrossingResolver.resolve(
        project: fixture.project,
        core: fixture.core,
        fromLevelId: fixture.lowerLevelId,
        toLevelId: fixture.upperLevelId,
        planPoint: const BoundaryPointMm(xMm: 1200, yMm: 1200),
      );

      expect(crossing, isNotNull);
      expect(crossing!.verticalCoreId, fixture.core.id);
      expect(crossing.slabId, fixture.slabId);
      expect(crossing.direction, VerticalCoreCrossingDirection.up);
    });

    test('same physical core resolves reverse crossing as down', () {
      final fixture = _Fixture();

      final crossing = VerticalCoreSlabCrossingResolver.resolve(
        project: fixture.project,
        core: fixture.core,
        fromLevelId: fixture.upperLevelId,
        toLevelId: fixture.lowerLevelId,
        planPoint: const BoundaryPointMm(xMm: 1200, yMm: 1200),
      );

      expect(crossing, isNotNull);
      expect(crossing!.slabId, fixture.slabId);
      expect(crossing.direction, VerticalCoreCrossingDirection.down);
    });

    test('point outside vertical core footprint fails closed', () {
      final fixture = _Fixture();

      final crossing = VerticalCoreSlabCrossingResolver.resolve(
        project: fixture.project,
        core: fixture.core,
        fromLevelId: fixture.lowerLevelId,
        toLevelId: fixture.upperLevelId,
        planPoint: const BoundaryPointMm(xMm: 2500, yMm: 1200),
      );

      expect(crossing, isNull);
    });

    test('point outside slab footprint fails closed', () {
      final fixture = _Fixture(
        slabFootprint: const [
          BoundaryPointMm(xMm: 1000, yMm: 1000),
          BoundaryPointMm(xMm: 1100, yMm: 1000),
          BoundaryPointMm(xMm: 1100, yMm: 1100),
          BoundaryPointMm(xMm: 1000, yMm: 1100),
        ],
      );

      final crossing = VerticalCoreSlabCrossingResolver.resolve(
        project: fixture.project,
        core: fixture.core,
        fromLevelId: fixture.lowerLevelId,
        toLevelId: fixture.upperLevelId,
        planPoint: const BoundaryPointMm(xMm: 1200, yMm: 1200),
      );

      expect(crossing, isNull);
    });

    test('core that does not serve target level fails closed', () {
      final fixture = _Fixture();
      final unrelatedLevel = LevelId('L3');
      final restrictedCore = ProjectVerticalCore(
        id: fixture.core.id,
        buildingId: fixture.buildingId,
        kind: VerticalCoreKind.riser,
        levelIds: [fixture.lowerLevelId, unrelatedLevel],
        footprint: fixture.core.footprint,
      );

      final crossing = VerticalCoreSlabCrossingResolver.resolve(
        project: fixture.project,
        core: restrictedCore,
        fromLevelId: fixture.lowerLevelId,
        toLevelId: fixture.upperLevelId,
        planPoint: const BoundaryPointMm(xMm: 1200, yMm: 1200),
      );

      expect(crossing, isNull);
    });
  });
}

final class _Fixture {
  _Fixture({List<BoundaryPointMm>? slabFootprint}) {
    final slab = ProjectSlab(
      id: slabId,
      buildingId: buildingId,
      kind: SlabKind.interLevel,
      belowLevelId: lowerLevelId,
      aboveLevelId: upperLevelId,
      bottomElevationMm: 3000,
      thicknessMm: 200,
      materialId: 'reinforced-concrete',
      footprint: slabFootprint ??
          const [
            BoundaryPointMm(xMm: 0, yMm: 0),
            BoundaryPointMm(xMm: 4000, yMm: 0),
            BoundaryPointMm(xMm: 4000, yMm: 3000),
            BoundaryPointMm(xMm: 0, yMm: 3000),
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
            levelIds: [lowerLevelId, upperLevelId],
          ),
        },
        levels: {
          lowerLevelId: ProjectLevelEntity(
            id: lowerLevelId,
            buildingId: buildingId,
            name: 'Lower',
            levelNumber: 1,
            elevationMm: 0,
          ),
          upperLevelId: ProjectLevelEntity(
            id: upperLevelId,
            buildingId: buildingId,
            name: 'Upper',
            levelNumber: 2,
            elevationMm: 3200,
          ),
        },
        slabs: {slabId: slab},
      ),
    );
    core = ProjectVerticalCore(
      id: VerticalCoreId('VC-01'),
      buildingId: buildingId,
      kind: VerticalCoreKind.riser,
      levelIds: [lowerLevelId, upperLevelId],
      footprint: const [
        BoundaryPointMm(xMm: 1000, yMm: 1000),
        BoundaryPointMm(xMm: 1400, yMm: 1000),
        BoundaryPointMm(xMm: 1400, yMm: 1400),
        BoundaryPointMm(xMm: 1000, yMm: 1400),
      ],
    );
  }

  final SiteId siteId = SiteId('S1');
  final BuildingId buildingId = BuildingId('B1');
  final LevelId lowerLevelId = LevelId('L1');
  final LevelId upperLevelId = LevelId('L2');
  final SlabId slabId = SlabId('SLAB-L1-L2');

  late final ProjectAggregateRoot project;
  late final ProjectVerticalCore core;
}
