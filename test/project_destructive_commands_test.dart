import 'package:elecx/src/application/project/project_authoring_error.dart';
import 'package:elecx/src/application/project/project_destructive_commands.dart';
import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P4E dependency-safe destructive commands', () {
    test('remove space clears level and structural-zone membership atomically',
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
      expect(
        result.changeSet.updatedEntityIds,
        <EntityId>{levelId, zoneId},
      );
      expect(result.project.version, LocalProjectVersion(1));
      expect(session.undoDepth, 1);

      final undone = session.undo(session.current.version)!;
      expect(undone.project.index.space(spaceId), isNotNull);
      expect(undone.project.index.level(levelId)!.spaceIds, contains(spaceId));
      expect(undone.project.index.zone(zoneId)!.spaceIds, contains(spaceId));
      expect(undone.project.index.structuralZoneBySpace[spaceId], zoneId);

      final redone = session.redo(session.current.version)!;
      expect(redone.project.index.space(spaceId), isNull);
      expect(redone.project.index.level(levelId)!.spaceIds, isEmpty);
      expect(redone.project.index.zone(zoneId)!.spaceIds, isEmpty);
    });

    test('remove empty structural zone updates level membership atomically', () {
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
    });

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
    });

    test('rejects structural zone deletion while spaces depend on it', () {
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
              .having(
                (error) => error.entityId,
                'entityId',
                ZoneId('zone-a'),
              )
              .having(
                (error) => error.relatedEntityId,
                'relatedEntityId',
                SpaceId('space-1'),
              ),
        ),
      );

      expect(session.current, same(before));
      expect(session.current.version, LocalProjectVersion(0));
      expect(session.undoDepth, 0);
    });

    test('rejects level deletion while zones or spaces depend on it', () {
      final zoneSession = ProjectMutationSession(_project(withZone: true));
      final zoneBefore = zoneSession.current;

      expect(
        () => zoneSession.commit(
          ProjectMutationRequest(
            expectedVersion: zoneBefore.version,
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
              .having(
                (error) => error.relatedEntityId,
                'relatedEntityId',
                ZoneId('zone-a'),
              ),
        ),
      );
      expect(zoneSession.current, same(zoneBefore));
      expect(zoneSession.undoDepth, 0);

      final spaceSession = ProjectMutationSession(_project(withSpace: true));
      expect(
        () => spaceSession.commit(
          ProjectMutationRequest(
            expectedVersion: spaceSession.current.version,
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
              .having(
                (error) => error.relatedEntityId,
                'relatedEntityId',
                SpaceId('space-1'),
              ),
        ),
      );
      expect(spaceSession.current.version, LocalProjectVersion(0));
      expect(spaceSession.undoDepth, 0);
    });

    test('rejects building deletion while levels depend on it', () {
      final session = ProjectMutationSession(_project());
      final before = session.current;

      expect(
        () => session.commit(
          ProjectMutationRequest(
            expectedVersion: before.version,
            command: RemoveBuildingCommand(buildingId: BuildingId('building-a')),
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
                (error) => error.relatedEntityId,
                'relatedEntityId',
                LevelId('level-1'),
              ),
        ),
      );

      expect(session.current, same(before));
      expect(session.current.version, LocalProjectVersion(0));
      expect(session.undoDepth, 0);
    });

    test('missing destructive targets fail closed', () {
      final session = ProjectMutationSession(_project());

      for (final command in <ProjectCommand>[
        RemoveSpaceCommand(spaceId: SpaceId('missing-space')),
        RemoveStructuralZoneCommand(zoneId: ZoneId('missing-zone')),
        RemoveLevelCommand(levelId: LevelId('missing-level')),
        RemoveBuildingCommand(buildingId: BuildingId('missing-building')),
      ]) {
        expect(
          () => session.commit(
            ProjectMutationRequest(
              expectedVersion: session.current.version,
              command: command,
            ),
          ),
          throwsA(isA<ProjectAuthoringException>()),
        );
        expect(session.current.version, LocalProjectVersion(0));
        expect(session.undoDepth, 0);
      }
    });
  });
}

ProjectAggregateRoot _project({
  bool withLevel = true,
  bool withZone = false,
  bool withSpace = false,
  bool spaceInZone = false,
}) {
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
          levelIds: withLevel ? <LevelId>[levelId] : const <LevelId>[],
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
