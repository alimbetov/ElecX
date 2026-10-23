import 'package:elecx/src/application/project/project_authoring_error.dart';
import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_structural_zone_commands.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P4 structural-zone membership', () {
    test('reassignment is exclusive, atomic and undoable', () {
      final session = ProjectMutationSession(_project());
      final spaceId = SpaceId('space-1');
      final zoneA = ZoneId('zone-a');
      final zoneB = ZoneId('zone-b');

      final result = session.commit(
        ProjectMutationRequest(
          expectedVersion: session.current.version,
          command: AssignSpaceToStructuralZoneCommand(
            spaceId: spaceId,
            zoneId: zoneB,
          ),
        ),
      )!;

      expect(result.project.index.structuralZoneBySpace[spaceId], zoneB);
      expect(result.project.index.zone(zoneA)!.spaceIds, isEmpty);
      expect(result.project.index.zone(zoneB)!.spaceIds, <SpaceId>{spaceId});
      expect(result.changeSet.updatedEntityIds, <EntityId>{zoneA, zoneB});
      expect(result.project.version, LocalProjectVersion(1));
      expect(session.undoDepth, 1);

      final undone = session.undo(session.current.version)!;
      expect(undone.project.index.structuralZoneBySpace[spaceId], zoneA);
      expect(undone.project.index.zone(zoneA)!.spaceIds, <SpaceId>{spaceId});
      expect(undone.project.index.zone(zoneB)!.spaceIds, isEmpty);

      final redone = session.redo(session.current.version)!;
      expect(redone.project.index.structuralZoneBySpace[spaceId], zoneB);
      expect(redone.project.index.zone(zoneA)!.spaceIds, isEmpty);
      expect(redone.project.index.zone(zoneB)!.spaceIds, <SpaceId>{spaceId});
    });

    test('assigning the existing zone is a semantic no-op', () {
      final session = ProjectMutationSession(_project());
      final before = session.current;

      final result = session.commit(
        ProjectMutationRequest(
          expectedVersion: before.version,
          command: AssignSpaceToStructuralZoneCommand(
            spaceId: SpaceId('space-1'),
            zoneId: ZoneId('zone-a'),
          ),
        ),
      );

      expect(result, isNull);
      expect(session.current, same(before));
      expect(session.current.version, LocalProjectVersion(0));
      expect(session.undoDepth, 0);
    });

    test('unassign removes membership and supports undo/redo', () {
      final session = ProjectMutationSession(_project());
      final spaceId = SpaceId('space-1');
      final zoneA = ZoneId('zone-a');

      final result = session.commit(
        ProjectMutationRequest(
          expectedVersion: session.current.version,
          command: UnassignSpaceFromStructuralZoneCommand(spaceId: spaceId),
        ),
      )!;

      expect(result.project.index.structuralZoneBySpace[spaceId], isNull);
      expect(result.project.index.zone(zoneA)!.spaceIds, isEmpty);
      expect(result.changeSet.updatedEntityIds, <EntityId>{zoneA});

      final undone = session.undo(session.current.version)!;
      expect(undone.project.index.structuralZoneBySpace[spaceId], zoneA);
      final redone = session.redo(session.current.version)!;
      expect(redone.project.index.structuralZoneBySpace[spaceId], isNull);
    });

    test('cross-level assignment fails closed without history mutation', () {
      final session = ProjectMutationSession(_project());
      final before = session.current;

      expect(
        () => session.commit(
          ProjectMutationRequest(
            expectedVersion: before.version,
            command: AssignSpaceToStructuralZoneCommand(
              spaceId: SpaceId('space-1'),
              zoneId: ZoneId('zone-level-2'),
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
                (error) => error.relatedEntityId,
                'actual zone level',
                LevelId('level-2'),
              ),
        ),
      );

      expect(session.current, same(before));
      expect(session.current.version, LocalProjectVersion(0));
      expect(session.undoDepth, 0);
      expect(session.redoDepth, 0);
    });
  });
}

ProjectAggregateRoot _project() {
  final siteId = SiteId('site-root');
  final buildingId = BuildingId('building-a');
  final level1 = LevelId('level-1');
  final level2 = LevelId('level-2');
  final zoneA = ZoneId('zone-a');
  final zoneB = ZoneId('zone-b');
  final zoneLevel2 = ZoneId('zone-level-2');
  final spaceId = SpaceId('space-1');

  return ProjectAggregateRoot(
    id: ProjectId('project-1'),
    siteId: siteId,
    version: LocalProjectVersion(0),
    stores: ProjectEntityStores(
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
          levelIds: [level1, level2],
        ),
      },
      levels: {
        level1: ProjectLevelEntity(
          id: level1,
          buildingId: buildingId,
          name: 'Floor 1',
          levelNumber: 1,
          elevationMm: 0,
          zoneIds: [zoneA, zoneB],
          spaceIds: [spaceId],
        ),
        level2: ProjectLevelEntity(
          id: level2,
          buildingId: buildingId,
          name: 'Floor 2',
          levelNumber: 2,
          elevationMm: 3000,
          zoneIds: [zoneLevel2],
        ),
      },
      zones: {
        zoneA: ProjectStructuralZoneEntity(
          id: zoneA,
          levelId: level1,
          name: 'Zone A',
          spaceIds: [spaceId],
        ),
        zoneB: ProjectStructuralZoneEntity(
          id: zoneB,
          levelId: level1,
          name: 'Zone B',
          spaceIds: const [],
        ),
        zoneLevel2: ProjectStructuralZoneEntity(
          id: zoneLevel2,
          levelId: level2,
          name: 'Upper zone',
          spaceIds: const [],
        ),
      },
      spaces: {
        spaceId: ProjectSpaceEntity(
          id: spaceId,
          levelId: level1,
          name: 'Room',
        ),
      },
    ),
  );
}
