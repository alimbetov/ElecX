import 'package:elecx/src/application/project/project_authoring_error.dart';
import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_space_commands.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P4D space commands', () {
    test(
      'creates an unzoned space and updates level membership atomically',
      () {
        final session = ProjectMutationSession(_project());
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
      },
    );

    test('creates a zoned space as one undoable multi-entity mutation', () {
      final session = ProjectMutationSession(_project(zoneOnFirst: true));
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
      expect(session.undoDepth, 1);

      final undone = session.undo(session.current.version)!;
      expect(undone.project.index.space(spaceId), isNull);
      expect(
        undone.project.index.level(LevelId('level-1'))!.spaceIds,
        isNot(contains(spaceId)),
      );
      expect(
        undone.project.index.zone(zoneId)!.spaceIds,
        isNot(contains(spaceId)),
      );

      final redone = session.redo(session.current.version)!;
      expect(redone.project.index.space(spaceId), isNotNull);
      expect(redone.project.index.structuralZoneBySpace[spaceId], zoneId);
    });

    test('rename preserves identity, level and structural-zone membership', () {
      final session = ProjectMutationSession(
        _project(zoneOnFirst: true, spaceOnFirst: true, spaceInZone: true),
      );
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
      final session = ProjectMutationSession(
        _project(zoneOnFirst: true, spaceOnFirst: true, spaceInZone: true),
      );
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

    test('duplicate SpaceId reports its actual owner level fail closed', () {
      final session = ProjectMutationSession(
        _project(secondLevel: true, spaceOnFirst: true),
      );

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

    test('cross-level zone mismatch reports actual zone owner fail closed', () {
      final session = ProjectMutationSession(
        _project(secondLevel: true, zoneOnFirst: true),
      );

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
                LevelId('level-1'),
              ),
        ),
      );

      expect(session.current.version, LocalProjectVersion(0));
      expect(session.undoDepth, 0);
      expect(session.current.stores.spaces, isEmpty);
      expect(
        session.current.index.level(LevelId('level-2'))!.spaceIds,
        isEmpty,
      );
      expect(session.current.index.zone(ZoneId('zone-a'))!.spaceIds, isEmpty);
    });

    test('missing level, zone and space are rejected fail closed', () {
      final createMissingLevel = ProjectMutationSession(_project());
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

      final createMissingZone = ProjectMutationSession(_project());
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

      final renameMissing = ProjectMutationSession(_project());
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

ProjectAggregateRoot _project({
  bool secondLevel = false,
  bool zoneOnFirst = false,
  bool spaceOnFirst = false,
  bool spaceInZone = false,
}) {
  final siteId = SiteId('site-root');
  final buildingId = BuildingId('building-a');
  final levelOneId = LevelId('level-1');
  final levelTwoId = LevelId('level-2');
  final zoneId = ZoneId('zone-a');
  final spaceId = SpaceId('space-1');

  final levelIds = <LevelId>[
    levelOneId,
    if (secondLevel) levelTwoId,
  ];

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
          levelIds: levelIds,
        ),
      },
      levels: <LevelId, ProjectLevelEntity>{
        levelOneId: ProjectLevelEntity(
          id: levelOneId,
          buildingId: buildingId,
          name: 'Floor 1',
          levelNumber: 1,
          elevationMm: 0,
          zoneIds: zoneOnFirst ? <ZoneId>[zoneId] : const <ZoneId>[],
          spaceIds: spaceOnFirst ? <SpaceId>[spaceId] : const <SpaceId>[],
        ),
        if (secondLevel)
          levelTwoId: ProjectLevelEntity(
            id: levelTwoId,
            buildingId: buildingId,
            name: 'Floor 2',
            levelNumber: 2,
            elevationMm: 3000,
          ),
      },
      zones: <ZoneId, ProjectStructuralZoneEntity>{
        if (zoneOnFirst)
          zoneId: ProjectStructuralZoneEntity(
            id: zoneId,
            levelId: levelOneId,
            name: 'Apartment A',
            spaceIds: spaceInZone ? <SpaceId>[spaceId] : const <SpaceId>[],
          ),
      },
      spaces: <SpaceId, ProjectSpaceEntity>{
        if (spaceOnFirst)
          spaceId: ProjectSpaceEntity(
            id: spaceId,
            levelId: levelOneId,
            name: spaceInZone ? 'Bedroom' : 'Existing',
          ),
      },
    ),
  );
}
