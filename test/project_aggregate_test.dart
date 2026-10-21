import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProjectAggregateRoot', () {
    test('supports same display level number in different buildings', () {
      final projectId = ProjectId('project-1');
      final siteId = SiteId('site-1');
      final buildingAId = BuildingId('building-a');
      final buildingBId = BuildingId('building-b');
      final levelAId = LevelId('level-a-2');
      final levelBId = LevelId('level-b-2');
      final roomAId = SpaceId('room-a');
      final roomBId = SpaceId('room-b');

      final stores = ProjectEntityStores(
        sites: {
          siteId: ProjectSiteEntity(
            id: siteId,
            name: 'Site',
            buildingIds: [buildingAId, buildingBId],
          ),
        },
        buildings: {
          buildingAId: ProjectBuildingEntity(
            id: buildingAId,
            siteId: siteId,
            name: 'Building A',
            levelIds: [levelAId],
          ),
          buildingBId: ProjectBuildingEntity(
            id: buildingBId,
            siteId: siteId,
            name: 'Building B',
            levelIds: [levelBId],
          ),
        },
        levels: {
          levelAId: ProjectLevelEntity(
            id: levelAId,
            buildingId: buildingAId,
            name: 'Floor 2',
            levelNumber: 2,
            elevationMm: 3000,
            spaceIds: [roomAId],
          ),
          levelBId: ProjectLevelEntity(
            id: levelBId,
            buildingId: buildingBId,
            name: 'Floor 2',
            levelNumber: 2,
            elevationMm: 3000,
            spaceIds: [roomBId],
          ),
        },
        spaces: {
          roomAId: ProjectSpaceEntity(
            id: roomAId,
            levelId: levelAId,
            name: 'Room A',
          ),
          roomBId: ProjectSpaceEntity(
            id: roomBId,
            levelId: levelBId,
            name: 'Room B',
          ),
        },
      );

      final project = ProjectAggregateRoot(
        id: projectId,
        siteId: siteId,
        version: LocalProjectVersion(0),
        stores: stores,
      );

      expect(project.index.buildingByLevel[levelAId], buildingAId);
      expect(project.index.buildingByLevel[levelBId], buildingBId);
      expect(project.index.levelBySpace[roomAId], levelAId);
      expect(project.index.levelBySpace[roomBId], levelBId);
      expect(project.index.level(levelAId)?.levelNumber, 2);
      expect(project.index.level(levelBId)?.levelNumber, 2);
    });

    test('rejects duplicate level number inside one building', () {
      final siteId = SiteId('site-1');
      final buildingId = BuildingId('building-a');
      final firstLevelId = LevelId('level-2-a');
      final secondLevelId = LevelId('level-2-b');

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
            name: 'Building A',
            levelIds: [firstLevelId, secondLevelId],
          ),
        },
        levels: {
          firstLevelId: ProjectLevelEntity(
            id: firstLevelId,
            buildingId: buildingId,
            name: 'Floor 2 A',
            levelNumber: 2,
            elevationMm: 3000,
          ),
          secondLevelId: ProjectLevelEntity(
            id: secondLevelId,
            buildingId: buildingId,
            name: 'Floor 2 B',
            levelNumber: 2,
            elevationMm: 3200,
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
            contains(ProjectAggregateIssueCode.duplicateLevelNumber),
          ),
        ),
      );
    });

    test('rejects dangling hierarchy references fail closed', () {
      final siteId = SiteId('site-1');
      final buildingId = BuildingId('building-a');
      final levelId = LevelId('level-1');
      final missingSpaceId = SpaceId('missing-space');

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
            name: 'Building A',
            levelIds: [levelId],
          ),
        },
        levels: {
          levelId: ProjectLevelEntity(
            id: levelId,
            buildingId: buildingId,
            name: 'Floor 1',
            levelNumber: 1,
            elevationMm: 0,
            spaceIds: [missingSpaceId],
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
            contains(ProjectAggregateIssueCode.danglingSpace),
          ),
        ),
      );
    });

    test('rejects duplicate structural zone membership on one level', () {
      final siteId = SiteId('site-1');
      final buildingId = BuildingId('building-a');
      final levelId = LevelId('level-1');
      final roomId = SpaceId('room-1');
      final zoneAId = ZoneId('zone-a');
      final zoneBId = ZoneId('zone-b');

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
            name: 'Building A',
            levelIds: [levelId],
          ),
        },
        levels: {
          levelId: ProjectLevelEntity(
            id: levelId,
            buildingId: buildingId,
            name: 'Floor 1',
            levelNumber: 1,
            elevationMm: 0,
            zoneIds: [zoneAId, zoneBId],
            spaceIds: [roomId],
          ),
        },
        zones: {
          zoneAId: ProjectStructuralZoneEntity(
            id: zoneAId,
            levelId: levelId,
            name: 'Apartment A',
            spaceIds: [roomId],
          ),
          zoneBId: ProjectStructuralZoneEntity(
            id: zoneBId,
            levelId: levelId,
            name: 'Apartment B',
            spaceIds: [roomId],
          ),
        },
        spaces: {
          roomId: ProjectSpaceEntity(
            id: roomId,
            levelId: levelId,
            name: 'Room',
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
            contains(
              ProjectAggregateIssueCode.duplicateStructuralZoneMembership,
            ),
          ),
        ),
      );
    });
  });

  group('LocalProjectVersion', () {
    test('is monotonic and rejects negative values', () {
      final version = LocalProjectVersion(0);

      expect(version.next(), LocalProjectVersion(1));
      expect(version.next().next(), LocalProjectVersion(2));
      expect(() => LocalProjectVersion(-1), throwsArgumentError);
    });
  });
}
