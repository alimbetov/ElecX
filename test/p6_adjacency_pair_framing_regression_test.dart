import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_space_semantics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P6 adjacency pair identity framing', () {
    test('distinct opaque SpaceId pairs cannot collide through separators', () {
      final siteId = SiteId('site-1');
      final buildingId = BuildingId('building-1');
      final levelId = LevelId('level-1');
      final a = SpaceId('a');
      final bNulC = SpaceId('b\u0000c');
      final aNulB = SpaceId('a\u0000b');
      final c = SpaceId('c');
      final spaces = <SpaceId>[a, bNulC, aNulB, c];

      final project = ProjectAggregateRoot(
        id: ProjectId('project-1'),
        siteId: siteId,
        version: LocalProjectVersion(0),
        stores: ProjectEntityStores(
          sites: <SiteId, ProjectSiteEntity>{
            siteId: ProjectSiteEntity(
              id: siteId,
              name: 'Site',
              buildingIds: <BuildingId>[buildingId],
            ),
          },
          buildings: <BuildingId, ProjectBuildingEntity>{
            buildingId: ProjectBuildingEntity(
              id: buildingId,
              siteId: siteId,
              name: 'Building',
              levelIds: <LevelId>[levelId],
            ),
          },
          levels: <LevelId, ProjectLevelEntity>{
            levelId: ProjectLevelEntity(
              id: levelId,
              buildingId: buildingId,
              name: 'Level 1',
              levelNumber: 1,
              elevationMm: 0,
              spaceIds: spaces,
            ),
          },
          spaces: <SpaceId, ProjectSpaceEntity>{
            for (final spaceId in spaces)
              spaceId: ProjectSpaceEntity(
                id: spaceId,
                levelId: levelId,
                name: 'Space ${spaceId.value.length}',
              ),
          },
          adjacencies: <SpaceAdjacencyId, ProjectSpaceAdjacencyEntity>{
            SpaceAdjacencyId('adj-1'): ProjectSpaceAdjacencyEntity(
              id: SpaceAdjacencyId('adj-1'),
              spaceAId: a,
              spaceBId: bNulC,
              kind: SpaceAdjacencyKind.sharedBoundary,
            ),
            SpaceAdjacencyId('adj-2'): ProjectSpaceAdjacencyEntity(
              id: SpaceAdjacencyId('adj-2'),
              spaceAId: aNulB,
              spaceBId: c,
              kind: SpaceAdjacencyKind.sharedBoundary,
            ),
          },
        ),
      );

      expect(project.stores.adjacencies, hasLength(2));
    });

    test('a real duplicate typed pair is still rejected fail closed', () {
      final siteId = SiteId('site-1');
      final buildingId = BuildingId('building-1');
      final levelId = LevelId('level-1');
      final roomA = SpaceId('room-a');
      final roomB = SpaceId('room-b');

      expect(
        () => ProjectAggregateRoot(
          id: ProjectId('project-1'),
          siteId: siteId,
          version: LocalProjectVersion(0),
          stores: ProjectEntityStores(
            sites: <SiteId, ProjectSiteEntity>{
              siteId: ProjectSiteEntity(
                id: siteId,
                name: 'Site',
                buildingIds: <BuildingId>[buildingId],
              ),
            },
            buildings: <BuildingId, ProjectBuildingEntity>{
              buildingId: ProjectBuildingEntity(
                id: buildingId,
                siteId: siteId,
                name: 'Building',
                levelIds: <LevelId>[levelId],
              ),
            },
            levels: <LevelId, ProjectLevelEntity>{
              levelId: ProjectLevelEntity(
                id: levelId,
                buildingId: buildingId,
                name: 'Level 1',
                levelNumber: 1,
                elevationMm: 0,
                spaceIds: <SpaceId>[roomA, roomB],
              ),
            },
            spaces: <SpaceId, ProjectSpaceEntity>{
              roomA: ProjectSpaceEntity(
                id: roomA,
                levelId: levelId,
                name: 'Room A',
              ),
              roomB: ProjectSpaceEntity(
                id: roomB,
                levelId: levelId,
                name: 'Room B',
              ),
            },
            adjacencies: <SpaceAdjacencyId, ProjectSpaceAdjacencyEntity>{
              SpaceAdjacencyId('adj-1'): ProjectSpaceAdjacencyEntity(
                id: SpaceAdjacencyId('adj-1'),
                spaceAId: roomA,
                spaceBId: roomB,
                kind: SpaceAdjacencyKind.sharedBoundary,
              ),
              SpaceAdjacencyId('adj-2'): ProjectSpaceAdjacencyEntity(
                id: SpaceAdjacencyId('adj-2'),
                spaceAId: roomB,
                spaceBId: roomA,
                kind: SpaceAdjacencyKind.sharedBoundary,
              ),
            },
          ),
        ),
        throwsA(
          isA<ProjectAggregateValidationException>().having(
            (error) => error.issues.map((issue) => issue.code),
            'issue codes',
            contains(ProjectAggregateIssueCode.duplicateAdjacencyPair),
          ),
        ),
      );
    });
  });
}
