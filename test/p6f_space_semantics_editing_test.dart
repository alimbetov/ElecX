import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_space_semantics_editing.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_space_semantics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P6F ProjectSpaceSemanticsEditingPort', () {
    test('setUsage commits exactly one semantic mutation', () {
      final mutations = ProjectMutationSession(_project());
      final editing = ProjectSpaceSemanticsEditingSession(mutations);
      final before = editing.version;

      final result = editing.setUsage(
        SpaceId('space-1'),
        SpaceUsage.bedroom,
        expectedVersion: before,
      );

      expect(result, isNotNull);
      expect(editing.version.value, before.value + 1);
      expect(editing.space(SpaceId('space-1'))!.usage, SpaceUsage.bedroom);
      expect(mutations.undoDepth, 1);
    });

    test('same usage remains a semantic no-op', () {
      final mutations = ProjectMutationSession(
        _project(usage: SpaceUsage.bedroom),
      );
      final editing = ProjectSpaceSemanticsEditingSession(mutations);
      final before = editing.version;

      final result = editing.setUsage(
        SpaceId('space-1'),
        SpaceUsage.bedroom,
        expectedVersion: before,
      );

      expect(result, isNull);
      expect(editing.version, before);
      expect(mutations.undoDepth, 0);
    });

    test('stale expectedVersion is rejected without changing usage', () {
      final mutations = ProjectMutationSession(_project());
      final editing = ProjectSpaceSemanticsEditingSession(mutations);
      final stale = editing.version;
      editing.setUsage(SpaceId('space-1'), SpaceUsage.office);

      expect(
        () => editing.setUsage(
          SpaceId('space-1'),
          SpaceUsage.bedroom,
          expectedVersion: stale,
        ),
        throwsA(isA<StaleProjectMutationException>()),
      );
      expect(editing.space(SpaceId('space-1'))!.usage, SpaceUsage.office);
      expect(mutations.undoDepth, 1);
    });
  });
}

ProjectAggregateRoot _project({SpaceUsage usage = SpaceUsage.unknown}) {
  final siteId = SiteId('site-1');
  final buildingId = BuildingId('building-1');
  final levelId = LevelId('level-1');
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
          name: 'Building',
          levelIds: <LevelId>[levelId],
        ),
      },
      levels: <LevelId, ProjectLevelEntity>{
        levelId: ProjectLevelEntity(
          id: levelId,
          buildingId: buildingId,
          name: 'Level',
          levelNumber: 1,
          elevationMm: 0,
          spaceIds: <SpaceId>[spaceId],
        ),
      },
      spaces: <SpaceId, ProjectSpaceEntity>{
        spaceId: ProjectSpaceEntity(
          id: spaceId,
          levelId: levelId,
          name: 'Room',
          usage: usage,
        ),
      },
    ),
  );
}
