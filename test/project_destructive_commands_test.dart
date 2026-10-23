import 'package:elecx/src/application/project/project_authoring_error.dart';
import 'package:elecx/src/application/project/project_destructive_commands.dart';
import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P4E dependency-safe destructive commands', () {
    test(
      'remove space clears level and structural-zone membership atomically',
      () {
        final session = ProjectMutationSession(
          _project(withZone: true, withSpace: true, spaceInZone: true),
        );
        final spaceId = SpaceId('space-1');
        final levelId = LevelId('level-1');
        final zoneId = ZoneId('zone-a');

        final result = session.commit(
          ProjectMutationRequest(
            expectedVersion: session.current.version,
            command: RemoveSpaceCommand(spaceId: spaceId),
          ),
        )!;

        expect(result.project.index.space(spaceId), isNull);
        expect(result.project.index.level(levelId)!.spaceIds, isEmpty);
        expect(result.project.index.zone(zoneId)!.spaceIds, isEmpty);
        expect(result.project.index.structuralZoneBySpace[spaceId], isNull);
        expect(result.changeSet.removedEntityIds, <EntityId>{spaceId});
        expect(result.changeSet.updatedEntityIds, <EntityId>{levelId, zoneId});
        expect(result.project.version, LocalProjectVersion(1));
        expect(session.undoDepth, 1);

        final undone = session.undo(session.current.version)!;
        expect(undone.project.index.space(spaceId), isNotNull);
        expect(
          undone.project.index.level(levelId)!.spaceIds,
          contains(spaceId),
        );
        expect(undone.project.index.zone(zoneId)!.spaceIds, contains(spaceId));
        expect(undone.project.index.structuralZoneBySpace[spaceId], zoneId);

        final redone = session.redo(session.current.version)!;
        expect(redone.project.index.space(spaceId), isNull);
        expect(redone.project.index.level(levelId)!.spaceIds, isEmpty);
        expect(redone.project.index.zone(zoneId)!.spaceIds, isEmpty);
      },
    );

    test(
      'remove empty structural zone updates level membership atomically',
      () {
        final session = ProjectMutationSession(_project(withZone: true));
        final levelId = LevelId('level-1');
        final zoneId = ZoneId('zone-a');

        final result = session.commit(
          ProjectMutationRequest(
            expectedVersion: session.current.version,
            command: RemoveStructuralZoneCommand(zoneId: zoneId),
          ),
        )!;

        expect(result.project.index.zone(zoneId), isNull);
        expect(result.project.index.level(levelId)!.zoneIds, isEmpty);
        expect(result.changeSet.removedEntityIds, <EntityId>{zoneId});
        expect(result.changeSet.updatedEntityIds, <EntityId>{levelId});

        final undone = session.undo(session.current.version)!;
        expect(undone.project.index.zone(zoneId), isNotNull);
        expect(undone.project.index.level(levelId)!.zoneIds, contains(zoneId));

        final redone = session.redo(session.current.version)!;
        expect(redone.project.index.zone(zoneId), isNull);
        expect(redone.project.index.level(levelId)!.zoneIds, isEmpty);
      },
    );

    test('remove empty level updates building membership atomically', () {
      final session = ProjectMutationSession(_project());
      final buildingId = BuildingId('building-a');
      final levelId = LevelId('level-1');

      final result = session.commit(
        ProjectMutationRequest(
          expectedVersion: session.current.version,
          command: RemoveLevelCommand(levelId: levelId),
        ),
      )!;

      expect(result.project.index.level(levelId), isNull);
      expect(result.project.index.building(buildingId)!.levelIds, isEmpty);
      expect(result.changeSet.removedEntityIds, <EntityId>{levelId});
      expect(result.changeSet.updatedEntityIds, <EntityId>{buildingId});

      final undone = session.undo(session.current.version)!;
      expect(undone.project.index.level(levelId), isNotNull);
      expect(
        undone.project.index.building(buildingId)!.levelIds,
        contains(levelId),
      );

      final redone = session.redo(session.current.version)!;
      expect(redone.project.index.level(levelId), isNull);
      expect(redone.project.index.building(buildingId)!.levelIds, isEmpty);
    });

    test('remove empty building updates site membership atomically', () {
      final session = ProjectMutationSession(_project(withLevel: false));
      final siteId = SiteId('site-root');
      final buildingId = BuildingId('building-a');

      final result = session.commit(
        ProjectMutationRequest(
          expectedVersion: session.current.version,
          command: RemoveBuildingCommand(buildingId: buildingId),
        ),
      )!;

      expect(result.project.index.building(buildingId), isNull);
      expect(result.project.index.site(siteId)!.buildingIds, isEmpty);
      expect(result.changeSet.removedEntityIds, <EntityId>{buildingId});
      expect(result.changeSet.updatedEntityIds, <EntityId>{siteId});

      final undone = session.undo(session.current.version)!;
      expect(undone.project.index.building(buildingId), isNotNull);
      expect(
        undone.project.index.site(siteId)!.buildingIds,
        contains(buildingId),
      );

      final redone = session.redo(session.current.version)!;
      expect(redone.project.index.building(buildingId), isNull);
      expect(redone.project.index.site(siteId)!.buildingIds, isEmpty);
    });

    test('zone deletion reports every blocking space', () {
      final session = ProjectMutationSession(
        _project(withZone: true, withSpace: true, spaceInZone: true),
      );
      final before = session.current;

      expect(
        () => session.commit(
          ProjectMutationRequest(
            expectedVersion: before.version,
            command: RemoveStructuralZoneCommand(zoneId: ZoneId('zone-a')),
          ),
        ),
        throwsA(
          isA<ProjectAuthoringException>()
              .having(
                (error) => error.code,
                'code',
                ProjectAuthoringIssueCode.structuralZoneHasSpaces,
              )
              .having((error) => error.entityId, 'entityId', ZoneId('zone-a'))
              .having(
                (error) => error.relatedEntityId,
                'relatedEntityId',
                SpaceId('space-1'),
              )
              .having(
            (error) => error.blockingEntityIds,
            'blockingEntityIds',
            <EntityId>{SpaceId('space-1')},
          ),
        ),
      );

      expect(session.current, same(before));
      expect(session.current.version, LocalProjectVersion(0));
      expect(session.undoDepth, 0);
    });

    test('level deletion reports all direct zone and space blockers', () {
      final session = ProjectMutationSession(
        _project(withZone: true, withSpace: true),
      );
      final before = session.current;

      expect(
        () => session.commit(
          ProjectMutationRequest(
            expectedVersion: before.version,
            command: RemoveLevelCommand(levelId: LevelId('level-1')),
          ),
        ),
        throwsA(
          isA<ProjectAuthoringException>()
              .having(
                (error) => error.code,
                'code',
                ProjectAuthoringIssueCode.levelHasChildren,
              )
              .having((error) => error.entityId, 'entityId', LevelId('level-1'))
              .having(
            (error) => error.blockingEntityIds,
            'blockingEntityIds',
            <EntityId>{ZoneId('zone-a'), SpaceId('space-1')},
          ),
        ),
      );

      expect(session.current, same(before));
      expect(session.current.version, LocalProjectVersion(0));
      expect(session.undoDepth, 0);
    });

    test('building deletion reports every direct level blocker', () {
      final session = ProjectMutationSession(_project(secondLevel: true));
      final before = session.current;

      expect(
        () => session.commit(
          ProjectMutationRequest(
            expectedVersion: before.version,
            command: RemoveBuildingCommand(
              buildingId: BuildingId('building-a'),
            ),
          ),
        ),
        throwsA(
          isA<ProjectAuthoringException>()
              .having(
                (error) => error.code,
                'code',
                ProjectAuthoringIssueCode.buildingHasLevels,
              )
              .having(
                (error) => error.entityId,
                'entityId',
                BuildingId('building-a'),
              )
              .having(
            (error) => error.blockingEntityIds,
            'blockingEntityIds',
            <EntityId>{LevelId('level-1'), LevelId('level-2')},
          ),
        ),
      );

      expect(session.current, same(before));
      expect(session.current.version, LocalProjectVersion(0));
      expect(session.undoDepth, 0);
    });

    test('rejected destructive command preserves existing redo history', () {
      final session = ProjectMutationSession(
        _project(withZone: true, withSpace: true, spaceInZone: true),
      );
      final removeResult = session.commit(
        ProjectMutationRequest(
          expectedVersion: session.current.version,
          command: RemoveSpaceCommand(spaceId: SpaceId('space-1')),
        ),
      );
      expect(removeResult, isNotNull);

      final undoResult = session.undo(session.current.version);
      expect(undoResult, isNotNull);
      expect(session.redoDepth, 1);
      final beforeRejectedDelete = session.current;

      expect(
        () => session.commit(
          ProjectMutationRequest(
            expectedVersion: session.current.version,
            command: RemoveStructuralZoneCommand(zoneId: ZoneId('zone-a')),
          ),
        ),
        throwsA(
          isA<ProjectAuthoringException>().having(
            (error) => error.code,
            'code',
            ProjectAuthoringIssueCode.structuralZoneHasSpaces,
          ),
        ),
      );

      expect(session.current, same(beforeRejectedDelete));
      expect(session.redoDepth, 1);
      expect(session.canRedo, isTrue);

      final redone = session.redo(session.current.version)!;
      expect(redone.project.index.space(SpaceId('space-1')), isNull);
    });

    test('missing destructive targets fail closed with specific codes', () {
      final cases = <(ProjectCommand, ProjectAuthoringIssueCode)>[
        (
          RemoveSpaceCommand(spaceId: SpaceId('missing-space')),
          ProjectAuthoringIssueCode.spaceNotFound,
        ),
        (
          RemoveStructuralZoneCommand(zoneId: ZoneId('missing-zone')),
          ProjectAuthoringIssueCode.structuralZoneNotFound,
        ),
        (
          RemoveLevelCommand(levelId: LevelId('missing-level')),
          ProjectAuthoringIssueCode.levelNotFound,
        ),
        (
          RemoveBuildingCommand(buildingId: BuildingId('missing-building')),
          ProjectAuthoringIssueCode.buildingNotFound,
        ),
      ];

      for (final (command, expectedCode) in cases) {
        final session = ProjectMutationSession(_project());
        final before = session.current;
        expect(
          () => session.commit(
            ProjectMutationRequest(
              expectedVersion: before.version,
              command: command,
            ),
          ),
          throwsA(
            isA<ProjectAuthoringException>().having(
              (error) => error.code,
              'code',
              expectedCode,
            ),
          ),
        );
        expect(session.current, same(before));
        expect(session.current.version, LocalProjectVersion(0));
        expect(session.undoDepth, 0);
        expect(session.redoDepth, 0);
      }
    });
  });
}

ProjectAggregateRoot _project({
  bool withLevel = true,
  bool secondLevel = false,
  bool withZone = false,
  bool withSpace = false,
  bool spaceInZone = false,
}) {
  final siteId = SiteId('site-root');
  final buildingId = BuildingId('building-a');
  final levelId = LevelId('level-1');
  final secondLevelId = LevelId('level-2');
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
          levelIds: <LevelId>[
            if (withLevel) levelId,
            if (secondLevel) secondLevelId,
          ],
        ),
      },
      levels: <LevelId, ProjectLevelEntity>{
        if (withLevel)
          levelId: ProjectLevelEntity(
            id: levelId,
            buildingId: buildingId,
            name: 'Floor 1',
            levelNumber: 1,
            elevationMm: 0,
            zoneIds: withZone ? <ZoneId>[zoneId] : const <ZoneId>[],
            spaceIds: withSpace ? <SpaceId>[spaceId] : const <SpaceId>[],
          ),
        if (secondLevel)
          secondLevelId: ProjectLevelEntity(
            id: secondLevelId,
            buildingId: buildingId,
            name: 'Floor 2',
            levelNumber: 2,
            elevationMm: 3000,
          ),
      },
      zones: <ZoneId, ProjectStructuralZoneEntity>{
        if (withZone)
          zoneId: ProjectStructuralZoneEntity(
            id: zoneId,
            levelId: levelId,
            name: 'Apartment A',
            spaceIds: spaceInZone ? <SpaceId>[spaceId] : const <SpaceId>[],
          ),
      },
      spaces: <SpaceId, ProjectSpaceEntity>{
        if (withSpace)
          spaceId: ProjectSpaceEntity(
            id: spaceId,
            levelId: levelId,
            name: 'Bedroom',
          ),
      },
    ),
  );
}
