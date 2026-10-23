import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/vertical_core.dart';
import 'package:elecx/src/domain/vertical_core_project_validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('vertical core levels must belong to the same canonical building', () {
    final siteId = SiteId('S1');
    final buildingA = BuildingId('BA');
    final buildingB = BuildingId('BB');
    final levelA = LevelId('LA');
    final levelB = LevelId('LB');
    final stores = ProjectEntityStores(
      sites: {
        siteId: ProjectSiteEntity(
          id: siteId,
          name: 'Site',
          buildingIds: [buildingA, buildingB],
        ),
      },
      buildings: {
        buildingA: ProjectBuildingEntity(
          id: buildingA,
          siteId: siteId,
          name: 'A',
          levelIds: [levelA],
        ),
        buildingB: ProjectBuildingEntity(
          id: buildingB,
          siteId: siteId,
          name: 'B',
          levelIds: [levelB],
        ),
      },
      levels: {
        levelA: ProjectLevelEntity(
          id: levelA,
          buildingId: buildingA,
          name: 'LA',
          levelNumber: 1,
          elevationMm: 0,
        ),
        levelB: ProjectLevelEntity(
          id: levelB,
          buildingId: buildingB,
          name: 'LB',
          levelNumber: 1,
          elevationMm: 0,
        ),
      },
    );
    final core = ProjectVerticalCore(
      id: VerticalCoreId('VC-01'),
      buildingId: buildingA,
      kind: VerticalCoreKind.riser,
      levelIds: [levelA, levelB],
      footprint: const [
        BoundaryPointMm(xMm: 0, yMm: 0),
        BoundaryPointMm(xMm: 100, yMm: 0),
        BoundaryPointMm(xMm: 100, yMm: 100),
      ],
    );

    final issues = VerticalCoreProjectValidator.validate(
      stores: stores,
      verticalCores: {core.id: core},
    );

    expect(issues, hasLength(1));
    expect(
      issues.single.code,
      VerticalCoreProjectIssueCode.levelBuildingMismatch,
    );
    expect(issues.single.relatedEntityId, levelB);
  });

  test('vertical core cannot reference a missing level', () {
    final siteId = SiteId('S1');
    final buildingId = BuildingId('B1');
    final level1 = LevelId('L1');
    final missing = LevelId('L2');
    final stores = ProjectEntityStores(
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
          levelIds: [level1],
        ),
      },
      levels: {
        level1: ProjectLevelEntity(
          id: level1,
          buildingId: buildingId,
          name: 'L1',
          levelNumber: 1,
          elevationMm: 0,
        ),
      },
    );
    final core = ProjectVerticalCore(
      id: VerticalCoreId('VC-01'),
      buildingId: buildingId,
      kind: VerticalCoreKind.shaft,
      levelIds: [level1, missing],
      footprint: const [
        BoundaryPointMm(xMm: 0, yMm: 0),
        BoundaryPointMm(xMm: 100, yMm: 0),
        BoundaryPointMm(xMm: 100, yMm: 100),
      ],
    );

    final issues = VerticalCoreProjectValidator.validate(
      stores: stores,
      verticalCores: {core.id: core},
    );

    expect(issues, hasLength(1));
    expect(issues.single.code, VerticalCoreProjectIssueCode.danglingLevel);
    expect(issues.single.relatedEntityId, missing);
  });
}
