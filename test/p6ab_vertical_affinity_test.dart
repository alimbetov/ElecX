import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_space_semantics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('vertical adjacency cannot cross building ownership', () {
    final siteId = SiteId('site-1');
    final buildingA = BuildingId('building-a');
    final buildingB = BuildingId('building-b');
    final levelA = LevelId('level-a');
    final levelB = LevelId('level-b');
    final roomA = SpaceId('room-a');
    final roomB = SpaceId('room-b');
    final adjacencyId = SpaceAdjacencyId('adj-1');

    final stores = ProjectEntityStores(
      sites: <SiteId, ProjectSiteEntity>{
        siteId: ProjectSiteEntity(
          id: siteId,
          name: 'Site',
          buildingIds: <BuildingId>[buildingA, buildingB],
        ),
      },
      buildings: <BuildingId, ProjectBuildingEntity>{
        buildingA: ProjectBuildingEntity(
          id: buildingA,
          siteId: siteId,
          name: 'Building A',
          levelIds: <LevelId>[levelA],
        ),
        buildingB: ProjectBuildingEntity(
          id: buildingB,
          siteId: siteId,
          name: 'Building B',
          levelIds: <LevelId>[levelB],
        ),
      },
      levels: <LevelId, ProjectLevelEntity>{
        levelA: ProjectLevelEntity(
          id: levelA,
          buildingId: buildingA,
          name: 'A Floor 1',
          levelNumber: 1,
          elevationMm: 0,
          spaceIds: <SpaceId>[roomA],
        ),
        levelB: ProjectLevelEntity(
          id: levelB,
          buildingId: buildingB,
          name: 'B Floor 2',
          levelNumber: 2,
          elevationMm: 3000,
          spaceIds: <SpaceId>[roomB],
        ),
      },
      spaces: <SpaceId, ProjectSpaceEntity>{
        roomA: ProjectSpaceEntity(id: roomA, levelId: levelA, name: 'Room A'),
        roomB: ProjectSpaceEntity(id: roomB, levelId: levelB, name: 'Room B'),
      },
      adjacencies: <SpaceAdjacencyId, ProjectSpaceAdjacencyEntity>{
        adjacencyId: ProjectSpaceAdjacencyEntity(
          id: adjacencyId,
          spaceAId: roomA,
          spaceBId: roomB,
          kind: SpaceAdjacencyKind.vertical,
        ),
      },
    );

    expect(
      () => ProjectAggregateRoot(
        id: ProjectId('project-1'),
        siteId: siteId,
        version: LocalProjectVersion(0),
        stores: stores,
      ),
      throwsA(
        isA<ProjectAggregateValidationException>().having(
          (error) => error.issues.map((issue) => issue.code),
          'issue codes',
          contains(ProjectAggregateIssueCode.verticalAdjacencyBuildingMismatch),
        ),
      ),
    );
  });
}
