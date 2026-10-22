import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_structure_authoring.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_space_semantics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('space semantics editing shares the structure-authoring P3 timeline', () {
    final project = _project();
    final mutations = ProjectMutationSession(project);
    final session = ProjectStructureAuthoringSession(
      mutations: mutations,
      idFactory: SecureRandomEntityIdFactory(),
    );

    final editing = session.spaceSemanticsEditing;
    final beforeVersion = session.project.version;

    final result = editing.setUsage(
      SpaceId('space-1'),
      SpaceUsage.bedroom,
      expectedVersion: beforeVersion,
    );

    expect(result, isNotNull);
    expect(session.project.version, beforeVersion.next());
    expect(session.project.index.space(SpaceId('space-1'))!.usage, SpaceUsage.bedroom);
    expect(mutations.current, same(session.project));
  });
}

ProjectAggregateRoot _project() {
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
        ),
      },
    ),
  );
}
