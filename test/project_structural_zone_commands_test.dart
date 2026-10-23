import 'package:elecx/src/application/project/project_authoring_error.dart';
import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_structural_zone_commands.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P4C structural zone commands', () {
    test('creates a zone and updates level membership atomically', () {
      final session = ProjectMutationSession(_projectWithLevel());
      final zoneId = ZoneId('zone-a');

      final result = session.commit(
        ProjectMutationRequest(
          expectedVersion: session.current.version,
          command: CreateStructuralZoneCommand(
            zoneId: zoneId,
            levelId: LevelId('level-1'),
            name: 'Apartment A',
          ),
        ),
      )!;

      final zone = result.project.index.zone(zoneId)!;
      expect(zone.id, zoneId);
      expect(zone.levelId, LevelId('level-1'));
      expect(zone.name, 'Apartment A');
      expect(zone.spaceIds, isEmpty);
      expect(
        result.project.index.level(LevelId('level-1'))!.zoneIds,
        contains(zoneId),
      );
      expect(result.changeSet.addedEntityIds, <EntityId>{zoneId});
      expect(result.changeSet.updatedEntityIds, <EntityId>{LevelId('level-1')});
      expect(result.project.version, LocalProjectVersion(1));
      expect(session.undoDepth, 1);
    });

    test('rename preserves identity, level ownership and space membership', () {
      final session = ProjectMutationSession(_projectWithZoneAndSpace());
      final zoneId = ZoneId('zone-a');

      final result = session.commit(
        ProjectMutationRequest(
          expectedVersion: session.current.version,
          command: RenameStructuralZoneCommand(
            zoneId: zoneId,
            name: 'Renamed Apartment',
          ),
        ),
      )!;

      final zone = result.project.index.zone(zoneId)!;
      expect(zone.id, zoneId);
      expect(zone.levelId, LevelId('level-1'));
      expect(zone.name, 'Renamed Apartment');
      expect(zone.spaceIds, <SpaceId>{SpaceId('space-1')});
      expect(result.changeSet.updatedEntityIds, <EntityId>{zoneId});
      expect(result.changeSet.addedEntityIds, isEmpty);
      expect(result.changeSet.removedEntityIds, isEmpty);
    });

    test('rename to the same semantic value is suppressed as a no-op', () {
      final session = ProjectMutationSession(_projectWithZoneAndSpace());
      final before = session.current;

      final result = session.commit(
        ProjectMutationRequest(
          expectedVersion: before.version,
          command: RenameStructuralZoneCommand(
            zoneId: ZoneId('zone-a'),
            name: 'Apartment A',
          ),
        ),
      );

      expect(result, isNull);
      expect(session.current, same(before));
      expect(session.current.version, LocalProjectVersion(0));
      expect(session.undoDepth, 0);
    });

    test('rejects duplicate ZoneId fail closed', () {
      final session = ProjectMutationSession(_projectWithZoneAndSpace());

      expect(
        () => session.commit(
          ProjectMutationRequest(
            expectedVersion: session.current.version,
            command: CreateStructuralZoneCommand(
              zoneId: ZoneId('zone-a'),
              levelId: LevelId('level-1'),
              name: 'Duplicate',
            ),
          ),
        ),
        throwsA(
          isA<ProjectAuthoringException>()
              .having(
                (error) => error.code,
                'code',
                ProjectAuthoringIssueCode.structuralZoneAlreadyExists,
              )
              .having((error) => error.entityId, 'entityId', ZoneId('zone-a'))
              .having(
                (error) => error.relatedEntityId,
                'relatedEntityId',
                LevelId('level-1'),
              ),
        ),
      );
      expect(session.current.version, LocalProjectVersion(0));
      expect(session.undoDepth, 0);
    });

    test('duplicate ZoneId reports its actual owning level', () {
      final session = ProjectMutationSession(_projectWithTwoLevelsAndZone());

      expect(
        () => session.commit(
          ProjectMutationRequest(
            expectedVersion: session.current.version,
            command: CreateStructuralZoneCommand(
              zoneId: ZoneId('zone-a'),
              levelId: LevelId('level-2'),
              name: 'Duplicate on another level',
            ),
          ),
        ),
        throwsA(
          isA<ProjectAuthoringException>()
              .having(
                (error) => error.code,
                'code',
                ProjectAuthoringIssueCode.structuralZoneAlreadyExists,
              )
              .having((error) => error.entityId, 'entityId', ZoneId('zone-a'))
              .having(
                (error) => error.relatedEntityId,
                'relatedEntityId',
                LevelId('level-1'),
              ),
        ),
      );
      expect(session.current.version, LocalProjectVersion(0));
      expect(session.undoDepth, 0);
      expect(session.current.index.level(LevelId('level-2'))!.zoneIds, isEmpty);
    });

    test('rejects create under a missing level fail closed', () {
      final session = ProjectMutationSession(_projectWithLevel());

      expect(
        () => session.commit(
          ProjectMutationRequest(
            expectedVersion: session.current.version,
            command: CreateStructuralZoneCommand(
              zoneId: ZoneId('zone-new'),
              levelId: LevelId('missing-level'),
              name: 'Missing parent',
            ),
          ),
        ),
        throwsA(
          isA<ProjectAuthoringException>()
              .having(
                (error) => error.code,
                'code',
                ProjectAuthoringIssueCode.levelNotFound,
              )
              .having(
                (error) => error.entityId,
                'entityId',
                LevelId('missing-level'),
              ),
        ),
      );
      expect(session.current.version, LocalProjectVersion(0));
      expect(session.undoDepth, 0);
    });

    test('rejects rename of a missing structural zone fail closed', () {
      final session = ProjectMutationSession(_projectWithLevel());

      expect(
        () => session.commit(
          ProjectMutationRequest(
            expectedVersion: session.current.version,
            command: RenameStructuralZoneCommand(
              zoneId: ZoneId('missing-zone'),
              name: 'Missing',
            ),
          ),
        ),
        throwsA(
          isA<ProjectAuthoringException>()
              .having(
                (error) => error.code,
                'code',
                ProjectAuthoringIssueCode.structuralZoneNotFound,
              )
              .having(
                (error) => error.entityId,
                'entityId',
                ZoneId('missing-zone'),
              ),
        ),
      );
      expect(session.current.version, LocalProjectVersion(0));
      expect(session.undoDepth, 0);
    });
  });
}

ProjectAggregateRoot _projectWithLevel() {
  final siteId = SiteId('site-root');
  final buildingId = BuildingId('building-a');
  final levelId = LevelId('level-1');
  return ProjectAggregateRoot(
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
          name: 'Building A',
          displayOrder: 10,
          levelIds: <LevelId>[levelId],
        ),
      },
      levels: <LevelId, ProjectLevelEntity>{
        levelId: ProjectLevelEntity(
          id: levelId,
          buildingId: buildingId,
          name: 'Floor 1',
          levelNumber: 1,
          displayOrder: 10,
          elevationMm: 0,
        ),
      },
    ),
  );
}

ProjectAggregateRoot _projectWithZoneAndSpace() {
  final siteId = SiteId('site-root');
  final buildingId = BuildingId('building-a');
  final levelId = LevelId('level-1');
  final zoneId = ZoneId('zone-a');
  final spaceId = SpaceId('space-1');
  return ProjectAggregateRoot(
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
          name: 'Building A',
          displayOrder: 10,
          levelIds: <LevelId>[levelId],
        ),
      },
      levels: <LevelId, ProjectLevelEntity>{
        levelId: ProjectLevelEntity(
          id: levelId,
          buildingId: buildingId,
          name: 'Floor 1',
          levelNumber: 1,
          displayOrder: 10,
          elevationMm: 0,
          zoneIds: <ZoneId>[zoneId],
          spaceIds: <SpaceId>[spaceId],
        ),
      },
      zones: <ZoneId, ProjectStructuralZoneEntity>{
        zoneId: ProjectStructuralZoneEntity(
          id: zoneId,
          levelId: levelId,
          name: 'Apartment A',
          spaceIds: <SpaceId>[spaceId],
        ),
      },
      spaces: <SpaceId, ProjectSpaceEntity>{
        spaceId: ProjectSpaceEntity(
          id: spaceId,
          levelId: levelId,
          name: 'Room 1',
        ),
      },
    ),
  );
}

ProjectAggregateRoot _projectWithTwoLevelsAndZone() {
  final siteId = SiteId('site-root');
  final buildingId = BuildingId('building-a');
  final level1 = LevelId('level-1');
  final level2 = LevelId('level-2');
  final zoneId = ZoneId('zone-a');
  return ProjectAggregateRoot(
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
          name: 'Building A',
          displayOrder: 10,
          levelIds: <LevelId>[level1, level2],
        ),
      },
      levels: <LevelId, ProjectLevelEntity>{
        level1: ProjectLevelEntity(
          id: level1,
          buildingId: buildingId,
          name: 'Floor 1',
          levelNumber: 1,
          displayOrder: 10,
          elevationMm: 0,
          zoneIds: <ZoneId>[zoneId],
        ),
        level2: ProjectLevelEntity(
          id: level2,
          buildingId: buildingId,
          name: 'Floor 2',
          levelNumber: 2,
          displayOrder: 20,
          elevationMm: 3000,
        ),
      },
      zones: <ZoneId, ProjectStructuralZoneEntity>{
        zoneId: ProjectStructuralZoneEntity(
          id: zoneId,
          levelId: level1,
          name: 'Apartment A',
          spaceIds: const <SpaceId>[],
        ),
      },
    ),
  );
}
