import 'package:elecx/src/application/project/project_authoring_error.dart';
import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_space_commands.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P4D space commands', () {
    test('creates an unzoned space and updates level membership atomically', () {
      final session = ProjectMutationSession(_projectWithLevel());
      final spaceId = SpaceId('space-1');

      final result = session.commit(
        ProjectMutationRequest(
          expectedVersion: session.current.version,
          command: CreateSpaceCommand(
            spaceId: spaceId,
            levelId: LevelId('level-1'),
            name: 'Room 1',
          ),
        ),
      )!;

      final space = result.project.index.space(spaceId)!;
      expect(space.id, spaceId);
      expect(space.levelId, LevelId('level-1'));
      expect(space.name, 'Room 1');
      expect(
        result.project.index.level(LevelId('level-1'))!.spaceIds,
        contains(spaceId),
      );
      expect(result.project.index.structuralZoneBySpace[spaceId], isNull);
      expect(result.changeSet.addedEntityIds, <EntityId>{spaceId});
      expect(
        result.changeSet.updatedEntityIds,
        <EntityId>{LevelId('level-1')},
      );
      expect(result.project.version, LocalProjectVersion(1));
      expect(session.undoDepth, 1);
    });

    test('creates a zoned space and updates level and zone atomically', () {
      final session = ProjectMutationSession(_projectWithEmptyZone());
      final spaceId = SpaceId('space-1');
      final zoneId = ZoneId('zone-a');

      final result = session.commit(
        ProjectMutationRequest(
          expectedVersion: session.current.version,
          command: CreateSpaceCommand(
            spaceId: spaceId,
            levelId: LevelId('level-1'),
            structuralZoneId: zoneId,
            name: 'Bedroom',
          ),
        ),
      )!;

      expect(
        result.project.index.level(LevelId('level-1'))!.spaceIds,
        contains(spaceId),
      );
      expect(result.project.index.zone(zoneId)!.spaceIds, contains(spaceId));
      expect(result.project.index.structuralZoneBySpace[spaceId], zoneId);
      expect(result.changeSet.addedEntityIds, <EntityId>{spaceId});
      expect(
        result.changeSet.updatedEntityIds,
        <EntityId>{LevelId('level-1'), zoneId},
      );
    });

    test('rename preserves identity, level and structural zone membership', () {
      final session = ProjectMutationSession(_projectWithZonedSpace());
      final spaceId = SpaceId('space-1');

      final result = session.commit(
        ProjectMutationRequest(
          expectedVersion: session.current.version,
          command: RenameSpaceCommand(
            spaceId: spaceId,
            name: 'Renamed Bedroom',
          ),
        ),
      )!;

      final space = result.project.index.space(spaceId)!;
      expect(space.id, spaceId);
      expect(space.levelId, LevelId('level-1'));
      expect(space.name, 'Renamed Bedroom');
      expect(
        result.project.index.structuralZoneBySpace[spaceId],
        ZoneId('zone-a'),
      );
      expect(result.changeSet.updatedEntityIds, <EntityId>{spaceId});
      expect(result.changeSet.addedEntityIds, isEmpty);
      expect(result.changeSet.removedEntityIds, isEmpty);
    });

    test('rename to the same semantic value is suppressed as a no-op', () {
      final session = ProjectMutationSession(_projectWithZonedSpace());
      final before = session.current;

      final result = session.commit(
        ProjectMutationRequest(
          expectedVersion: before.version,
          command: RenameSpaceCommand(
            spaceId: SpaceId('space-1'),
            name: 'Bedroom',
          ),
        ),
      );

      expect(result, isNull);
      expect(session.current, same(before));
      expect(session.current.version, LocalProjectVersion(0));
      expect(session.undoDepth, 0);
    });

    test('rejects duplicate SpaceId and reports existing owner level', () {
      final session = ProjectMutationSession(_twoLevelsWithSpaceOnFirst());

      expect(
        () => session.commit(
          ProjectMutationRequest(
            expectedVersion: session.current.version,
            command: CreateSpaceCommand(
              spaceId: SpaceId('space-1'),
              levelId: LevelId('level-2'),
              name: 'Duplicate',
            ),
          ),
        ),
        throwsA(
          isA<ProjectAuthoringException>()
              .having(
                (error) => error.code,
                'code',
                ProjectAuthoringIssueCode.spaceAlreadyExists,
              )
              .having(
                (error) => error.entityId,
                'entityId',
                SpaceId('space-1'),
              )
              .having(
                (error) => error.relatedEntityId,
                'relatedEntityId',
                LevelId('level-1'),
              ),
        ),
      );
      expect(session.current.version, LocalProjectVersion(0));
      expect(session.undoDepth, 0);
      expect(
        session.current.index.level(LevelId('level-2'))!.spaceIds,
        isEmpty,
      );
    });

    test('rejects structural zone from another level fail closed', () {
      final session = ProjectMutationSession(_twoLevelsWithZoneOnFirst());

      expect(
        () => session.commit(
          ProjectMutationRequest(
            expectedVersion: session.current.version,
            command: CreateSpaceCommand(
              spaceId: SpaceId('space-new'),
              levelId: LevelId('level-2'),
              structuralZoneId: ZoneId('zone-a'),
              name: 'Wrong Level',
            ),
          ),
        ),
        throwsA(
          isA<ProjectAuthoringException>()
              .having(
                (error) => error.code,
                'code',
                ProjectAuthoringIssueCode.structuralZoneLevelMismatch,
              )
              .having(
                (error) => error.entityId,
                'entityId',
                ZoneId('zone-a'),
              )
              .having(
                (error) => error.relatedEntityId,
                'relatedEntityId',
                LevelId('level-2'),
              ),
        ),
      );
      expect(session.current.version, LocalProjectVersion(0));
      expect(session.undoDepth, 0);
      expect(session.current.stores.spaces, isEmpty);
    });

    test('rejects missing level, zone and space fail closed', () {
      final createMissingLevel = ProjectMutationSession(_projectWithLevel());
      expect(
        () => createMissingLevel.commit(
          ProjectMutationRequest(
            expectedVersion: createMissingLevel.current.version,
            command: CreateSpaceCommand(
              spaceId: SpaceId('space-new'),
              levelId: LevelId('missing-level'),
              name: 'Missing Level',
            ),
          ),
        ),
        throwsA(
          isA<ProjectAuthoringException>().having(
            (error) => error.code,
            'code',
            ProjectAuthoringIssueCode.levelNotFound,
          ),
        ),
      );

      final createMissingZone = ProjectMutationSession(_projectWithLevel());
      expect(
        () => createMissingZone.commit(
          ProjectMutationRequest(
            expectedVersion: createMissingZone.current.version,
            command: CreateSpaceCommand(
              spaceId: SpaceId('space-new'),
              levelId: LevelId('level-1'),
              structuralZoneId: ZoneId('missing-zone'),
              name: 'Missing Zone',
            ),
          ),
        ),
        throwsA(
          isA<ProjectAuthoringException>().having(
            (error) => error.code,
            'code',
            ProjectAuthoringIssueCode.structuralZoneNotFound,
          ),
        ),
      );

      final renameMissing = ProjectMutationSession(_projectWithLevel());
      expect(
        () => renameMissing.commit(
          ProjectMutationRequest(
            expectedVersion: renameMissing.current.version,
            command: RenameSpaceCommand(
              spaceId: SpaceId('missing-space'),
              name: 'Missing',
            ),
          ),
        ),
        throwsA(
          isA<ProjectAuthoringException>().having(
            (error) => error.code,
            'code',
            ProjectAuthoringIssueCode.spaceNotFound,
          ),
        ),
      );

      expect(createMissingLevel.current.version, LocalProjectVersion(0));
      expect(createMissingZone.current.version, LocalProjectVersion(0));
      expect(renameMissing.current.version, LocalProjectVersion(0));
      expect(createMissingLevel.undoDepth, 0);
      expect(createMissingZone.undoDepth, 0);
      expect(renameMissing.undoDepth, 0);
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
          levelIds: <LevelId>[levelId],
        ),
      },
      levels: <LevelId, ProjectLevelEntity>{
        levelId: ProjectLevelEntity(
          id: levelId,
          buildingId: buildingId,
          name: 'Floor 1',
          levelNumber: 1,
          elevationMm: 0,
        ),
      },
    ),
  );
}

ProjectAggregateRoot _projectWithEmptyZone() {
  final siteId = SiteId('site-root');
  final buildingId = BuildingId('building-a');
  final levelId = LevelId('level-1');
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
          levelIds: <LevelId>[levelId],
        ),
      },
      levels: <LevelId, ProjectLevelEntity>{
        levelId: ProjectLevelEntity(
          id: levelId,
          buildingId: buildingId,
          name: 'Floor 1',
          levelNumber: 1,
          elevationMm: 0,
          zoneIds: <ZoneId>[zoneId],
        ),
      },
      zones: <ZoneId, ProjectStructuralZoneEntity>{
        zoneId: ProjectStructuralZoneEntity(
          id: zoneId,
          levelId: levelId,
          name: 'Apartment A',
          spaceIds: const <SpaceId>[],
        ),
      },
    ),
  );
}

ProjectAggregateRoot _projectWithZonedSpace() {
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
          levelIds: <LevelId>[levelId],
        ),
      },
      levels: <LevelId, ProjectLevelEntity>{
        levelId: ProjectLevelEntity(
          id: levelId,
          buildingId: buildingId,
          name: 'Floor 1',
          levelNumber: 1,
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
          name: 'Bedroom',
        ),
      },
    ),
  );
}

ProjectAggregateRoot _twoLevelsWithSpaceOnFirst() {
  final base = _twoLevels();
  final levelOne = base.index.level(LevelId('level-1'))!;
  final levels = Map<LevelId, ProjectLevelEntity>.from(base.stores.levels);
  levels[levelOne.id] = ProjectLevelEntity(
    id: levelOne.id,
    buildingId: levelOne.buildingId,
    name: levelOne.name,
    levelNumber: levelOne.levelNumber,
    displayOrder: levelOne.displayOrder,
    elevationMm: levelOne.elevationMm,
    zoneIds: levelOne.zoneIds,
    spaceIds: <SpaceId>[SpaceId('space-1')],
  );
  return ProjectAggregateRoot(
    id: base.id,
    siteId: base.siteId,
    version: base.version,
    stores: ProjectEntityStores(
      sites: base.stores.sites,
      buildings: base.stores.buildings,
      levels: levels,
      zones: base.stores.zones,
      spaces: <SpaceId, ProjectSpaceEntity>{
        SpaceId('space-1'): ProjectSpaceEntity(
          id: SpaceId('space-1'),
          levelId: LevelId('level-1'),
          name: 'Existing',
        ),
      },
    ),
  );
}

ProjectAggregateRoot _twoLevelsWithZoneOnFirst() {
  final base = _twoLevels();
  final levelOne = base.index.level(LevelId('level-1'))!;
  final levels = Map<LevelId, ProjectLevelEntity>.from(base.stores.levels);
  levels[levelOne.id] = ProjectLevelEntity(
    id: levelOne.id,
    buildingId: levelOne.buildingId,
    name: levelOne.name,
    levelNumber: levelOne.levelNumber,
    displayOrder: levelOne.displayOrder,
    elevationMm: levelOne.elevationMm,
    zoneIds: <ZoneId>[ZoneId('zone-a')],
    spaceIds: levelOne.spaceIds,
  );
  return ProjectAggregateRoot(
    id: base.id,
    siteId: base.siteId,
    version: base.version,
    stores: ProjectEntityStores(
      sites: base.stores.sites,
      buildings: base.stores.buildings,
      levels: levels,
      zones: <ZoneId, ProjectStructuralZoneEntity>{
        ZoneId('zone-a'): ProjectStructuralZoneEntity(
          id: ZoneId('zone-a'),
          levelId: LevelId('level-1'),
          name: 'Apartment A',
          spaceIds: const <SpaceId>[],
        ),
      },
      spaces: base.stores.spaces,
    ),
  );
}

ProjectAggregateRoot _twoLevels() {
  final siteId = SiteId('site-root');
  final buildingId = BuildingId('building-a');
  final levelOne = LevelId('level-1');
  final levelTwo = LevelId('level-2');
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
          levelIds: <LevelId>[levelOne, levelTwo],
        ),
      },
      levels: <LevelId, ProjectLevelEntity>{
        levelOne: ProjectLevelEntity(
          id: levelOne,
          buildingId: buildingId,
          name: 'Floor 1',
          levelNumber: 1,
          elevationMm: 0,
        ),
        levelTwo: ProjectLevelEntity(
          id: levelTwo,
          buildingId: buildingId,
          name: 'Floor 2',
          levelNumber: 2,
          elevationMm: 3000,
        ),
      },
    ),
  );
}
