import 'package:elecx/src/application/project/project_authoring_error.dart';
import 'package:elecx/src/application/project/project_level_commands.dart';
import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P4B level commands', () {
    test('creates a level and updates building membership atomically', () {
      final session = ProjectMutationSession(_projectWithBuilding());
      final levelId = LevelId('level-2');

      final result = session.commit(
        ProjectMutationRequest(
          expectedVersion: session.current.version,
          command: CreateLevelCommand(
            levelId: levelId,
            buildingId: BuildingId('building-a'),
            name: 'Floor 2',
            levelNumber: 2,
            displayOrder: 20,
            elevationMm: 3000,
          ),
        ),
      )!;

      final level = result.project.index.level(levelId)!;
      expect(level.buildingId, BuildingId('building-a'));
      expect(level.name, 'Floor 2');
      expect(level.levelNumber, 2);
      expect(level.displayOrder, 20);
      expect(level.elevationMm, 3000);
      expect(
        result.project.index.building(BuildingId('building-a'))!.levelIds,
        contains(levelId),
      );
      expect(result.changeSet.addedEntityIds, <EntityId>{levelId});
      expect(
        result.changeSet.updatedEntityIds,
        <EntityId>{BuildingId('building-a')},
      );
    });

    test('rename preserves level identity and structural attributes', () {
      final session = ProjectMutationSession(_projectWithLevel());
      final levelId = LevelId('level-1');

      final result = session.commit(
        ProjectMutationRequest(
          expectedVersion: session.current.version,
          command: RenameLevelCommand(levelId: levelId, name: 'Ground Floor'),
        ),
      )!;

      final level = result.project.index.level(levelId)!;
      expect(level.id, levelId);
      expect(level.buildingId, BuildingId('building-a'));
      expect(level.name, 'Ground Floor');
      expect(level.levelNumber, 1);
      expect(level.displayOrder, 10);
      expect(level.elevationMm, 0);
      expect(result.changeSet.updatedEntityIds, <EntityId>{levelId});
    });

    test('renumber preserves LevelId and does not use number as identity', () {
      final session = ProjectMutationSession(_projectWithLevel());
      final levelId = LevelId('level-1');

      final result = session.commit(
        ProjectMutationRequest(
          expectedVersion: session.current.version,
          command: RenumberLevelCommand(levelId: levelId, levelNumber: 7),
        ),
      )!;

      final level = result.project.index.level(levelId)!;
      expect(level.id, levelId);
      expect(level.levelNumber, 7);
      expect(level.name, 'Floor 1');
      expect(level.displayOrder, 10);
      expect(level.elevationMm, 0);
      expect(result.changeSet.updatedEntityIds, <EntityId>{levelId});
    });

    test('reorder changes display order without changing number or identity',
        () {
      final session = ProjectMutationSession(_projectWithLevel());
      final levelId = LevelId('level-1');

      final result = session.commit(
        ProjectMutationRequest(
          expectedVersion: session.current.version,
          command: ReorderLevelCommand(levelId: levelId, displayOrder: 99),
        ),
      )!;

      final level = result.project.index.level(levelId)!;
      expect(level.id, levelId);
      expect(level.levelNumber, 1);
      expect(level.displayOrder, 99);
      expect(level.elevationMm, 0);
    });

    test('same level number remains valid in a different building', () {
      final session = ProjectMutationSession(_twoBuildingsOneLevel());

      final result = session.commit(
        ProjectMutationRequest(
          expectedVersion: session.current.version,
          command: CreateLevelCommand(
            levelId: LevelId('level-b-1'),
            buildingId: BuildingId('building-b'),
            name: 'Floor 1',
            levelNumber: 1,
            displayOrder: 10,
            elevationMm: 0,
          ),
        ),
      );

      expect(result, isNotNull);
      expect(result!.project.stores.levels, hasLength(2));
      expect(
        result.project.index.level(LevelId('level-b-1'))!.buildingId,
        BuildingId('building-b'),
      );
    });

    test('rejects duplicate level number inside one building fail closed', () {
      final session = ProjectMutationSession(_projectWithLevel());
      final newLevelId = LevelId('duplicate-number');

      expect(
        () => session.commit(
          ProjectMutationRequest(
            expectedVersion: session.current.version,
            command: CreateLevelCommand(
              levelId: newLevelId,
              buildingId: BuildingId('building-a'),
              name: 'Duplicate Floor',
              levelNumber: 1,
              elevationMm: 3000,
            ),
          ),
        ),
        throwsA(
          isA<ProjectAuthoringException>()
              .having(
                (error) => error.code,
                'code',
                ProjectAuthoringIssueCode.duplicateLevelNumber,
              )
              .having((error) => error.entityId, 'entityId', newLevelId)
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

    test('rejects renumber collision and preserves current level state', () {
      final session = ProjectMutationSession(_projectWithTwoLevels());
      final level2 = LevelId('level-2');

      expect(
        () => session.commit(
          ProjectMutationRequest(
            expectedVersion: session.current.version,
            command: RenumberLevelCommand(levelId: level2, levelNumber: 1),
          ),
        ),
        throwsA(
          isA<ProjectAuthoringException>()
              .having(
                (error) => error.code,
                'code',
                ProjectAuthoringIssueCode.duplicateLevelNumber,
              )
              .having((error) => error.entityId, 'entityId', level2)
              .having(
                (error) => error.relatedEntityId,
                'relatedEntityId',
                LevelId('level-1'),
              ),
        ),
      );
      expect(session.current.version, LocalProjectVersion(0));
      expect(session.current.index.level(level2)!.levelNumber, 2);
      expect(session.undoDepth, 0);
    });

    test('rejects duplicate LevelId and missing building fail closed', () {
      final session = ProjectMutationSession(_projectWithLevel());

      expect(
        () => session.commit(
          ProjectMutationRequest(
            expectedVersion: session.current.version,
            command: CreateLevelCommand(
              levelId: LevelId('level-1'),
              buildingId: BuildingId('building-a'),
              name: 'Duplicate Id',
              levelNumber: 2,
              elevationMm: 3000,
            ),
          ),
        ),
        throwsA(
          isA<ProjectAuthoringException>().having(
            (error) => error.code,
            'code',
            ProjectAuthoringIssueCode.levelAlreadyExists,
          ),
        ),
      );

      expect(
        () => session.commit(
          ProjectMutationRequest(
            expectedVersion: session.current.version,
            command: CreateLevelCommand(
              levelId: LevelId('new-level'),
              buildingId: BuildingId('missing-building'),
              name: 'Missing parent',
              levelNumber: 2,
              elevationMm: 3000,
            ),
          ),
        ),
        throwsA(
          isA<ProjectAuthoringException>().having(
            (error) => error.code,
            'code',
            ProjectAuthoringIssueCode.buildingNotFound,
          ),
        ),
      );
      expect(session.current.version, LocalProjectVersion(0));
      expect(session.undoDepth, 0);
    });

    test('rename, renumber and reorder semantic no-ops are suppressed', () {
      final commands = <ProjectCommand>[
        RenameLevelCommand(levelId: LevelId('level-1'), name: 'Floor 1'),
        RenumberLevelCommand(levelId: LevelId('level-1'), levelNumber: 1),
        ReorderLevelCommand(levelId: LevelId('level-1'), displayOrder: 10),
      ];

      for (final command in commands) {
        final session = ProjectMutationSession(_projectWithLevel());
        final before = session.current;
        final result = session.commit(
          ProjectMutationRequest(
            expectedVersion: before.version,
            command: command,
          ),
        );
        expect(result, isNull);
        expect(session.current, same(before));
        expect(session.undoDepth, 0);
      }
    });

    test('rejects operations for a missing LevelId fail closed', () {
      final commands = <ProjectCommand>[
        RenameLevelCommand(levelId: LevelId('missing'), name: 'Missing'),
        RenumberLevelCommand(levelId: LevelId('missing'), levelNumber: 9),
        ReorderLevelCommand(levelId: LevelId('missing'), displayOrder: 9),
      ];

      for (final command in commands) {
        final session = ProjectMutationSession(_projectWithBuilding());
        expect(
          () => session.commit(
            ProjectMutationRequest(
              expectedVersion: session.current.version,
              command: command,
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
        expect(session.current.version, LocalProjectVersion(0));
        expect(session.undoDepth, 0);
      }
    });
  });
}

ProjectAggregateRoot _projectWithBuilding() {
  final siteId = SiteId('site-root');
  final buildingId = BuildingId('building-a');
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
          levelIds: const <LevelId>[],
        ),
      },
    ),
  );
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

ProjectAggregateRoot _projectWithTwoLevels() {
  final siteId = SiteId('site-root');
  final buildingId = BuildingId('building-a');
  final level1 = LevelId('level-1');
  final level2 = LevelId('level-2');
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
    ),
  );
}

ProjectAggregateRoot _twoBuildingsOneLevel() {
  final siteId = SiteId('site-root');
  final buildingA = BuildingId('building-a');
  final buildingB = BuildingId('building-b');
  final levelA = LevelId('level-a-1');
  return ProjectAggregateRoot(
    id: ProjectId('project-1'),
    siteId: siteId,
    version: LocalProjectVersion(0),
    stores: ProjectEntityStores(
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
          displayOrder: 10,
          levelIds: <LevelId>[levelA],
        ),
        buildingB: ProjectBuildingEntity(
          id: buildingB,
          siteId: siteId,
          name: 'Building B',
          displayOrder: 20,
          levelIds: const <LevelId>[],
        ),
      },
      levels: <LevelId, ProjectLevelEntity>{
        levelA: ProjectLevelEntity(
          id: levelA,
          buildingId: buildingA,
          name: 'Floor 1',
          levelNumber: 1,
          displayOrder: 10,
          elevationMm: 0,
        ),
      },
    ),
  );
}
