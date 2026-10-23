import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_space_semantics_editing.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P4 space semantics editing port', () {
    test('reassigns structural zone through the shared mutation timeline', () {
      final mutations = ProjectMutationSession(_project());
      final editing = ProjectSpaceSemanticsEditingSession(mutations);
      final spaceId = SpaceId('space-1');
      final zoneA = ZoneId('zone-a');
      final zoneB = ZoneId('zone-b');

      final result = editing.assignStructuralZone(spaceId, zoneB)!;

      expect(result.project.index.structuralZoneBySpace[spaceId], zoneB);
      expect(result.project.index.zone(zoneA)!.spaceIds, isEmpty);
      expect(result.project.index.zone(zoneB)!.spaceIds, <SpaceId>{spaceId});
      expect(result.changeSet.updatedEntityIds, <EntityId>{zoneA, zoneB});
      expect(editing.version, LocalProjectVersion(1));
      expect(mutations.undoDepth, 1);

      final undone = mutations.undo(editing.version)!;
      expect(undone.project.index.structuralZoneBySpace[spaceId], zoneA);
      final redone = mutations.redo(mutations.current.version)!;
      expect(redone.project.index.structuralZoneBySpace[spaceId], zoneB);
    });

    test('unassigning an already unassigned space is a version-neutral no-op', () {
      final mutations = ProjectMutationSession(_project(unzoned: true));
      final editing = ProjectSpaceSemanticsEditingSession(mutations);
      final before = mutations.current;

      final result = editing.unassignStructuralZone(SpaceId('space-1'));

      expect(result, isNull);
      expect(mutations.current, same(before));
      expect(editing.version, LocalProjectVersion(0));
      expect(mutations.undoDepth, 0);
      expect(mutations.redoDepth, 0);
    });

    test('stale expectedVersion rejects reassignment before mutation', () {
      final mutations = ProjectMutationSession(_project());
      final editing = ProjectSpaceSemanticsEditingSession(mutations);
      final stale = editing.version;

      editing.assignStructuralZone(SpaceId('space-1'), ZoneId('zone-b'));
      final before = mutations.current;
      final undoDepth = mutations.undoDepth;

      expect(
        () => editing.assignStructuralZone(
          SpaceId('space-1'),
          ZoneId('zone-a'),
          expectedVersion: stale,
        ),
        throwsA(isA<StaleProjectMutationException>()),
      );
      expect(mutations.current, same(before));
      expect(mutations.undoDepth, undoDepth);
    });
  });
}

ProjectAggregateRoot _project({bool unzoned = false}) {
  final siteId = SiteId('site-root');
  final buildingId = BuildingId('building-a');
  final levelId = LevelId('level-1');
  final zoneA = ZoneId('zone-a');
  final zoneB = ZoneId('zone-b');
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
          zoneIds: [zoneA, zoneB],
          spaceIds: [spaceId],
        ),
      },
      zones: {
        zoneA: ProjectStructuralZoneEntity(
          id: zoneA,
          levelId: levelId,
          name: 'Zone A',
          spaceIds: unzoned ? const [] : [spaceId],
        ),
        zoneB: ProjectStructuralZoneEntity(
          id: zoneB,
          levelId: levelId,
          name: 'Zone B',
          spaceIds: const [],
        ),
      },
      spaces: {
        spaceId: ProjectSpaceEntity(
          id: spaceId,
          levelId: levelId,
          name: 'Room',
        ),
      },
    ),
  );
}
