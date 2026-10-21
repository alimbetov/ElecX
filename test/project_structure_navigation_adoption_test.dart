import 'dart:math';

import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_structure_authoring.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P5C atomic navigation adoption', () {
    test('adopts a complete valid navigation state in one operation', () {
      final project = _project('site-1');
      final session = ProjectStructureAuthoringSession(
        mutations: ProjectMutationSession(project),
        idFactory: SecureRandomEntityIdFactory(random: Random(41)),
      );
      final next = ProjectNavigationState.initial(project)
          .selectSpace(project, SpaceId('space-1'));

      session.adoptNavigation(next);

      expect(session.navigation, next);
      expect(session.navigation.activeBuildingId, BuildingId('building-1'));
      expect(session.navigation.activeLevelId, LevelId('level-1'));
      expect(session.navigation.selectedSpaceId, SpaceId('space-1'));
    });

    test('foreign Site navigation is rejected without partial state change',
        () {
      final project = _project('site-1');
      final foreignProject = _project('site-other');
      final session = ProjectStructureAuthoringSession(
        mutations: ProjectMutationSession(project),
        idFactory: SecureRandomEntityIdFactory(random: Random(42)),
      );
      final before = session.navigation;
      final foreign = ProjectNavigationState.initial(foreignProject);

      expect(
        () => session.adoptNavigation(foreign),
        throwsA(
          isA<ProjectStructureAuthoringException>().having(
            (error) => error.code,
            'code',
            ProjectStructureAuthoringIssueCode.navigationSiteMismatch,
          ),
        ),
      );
      expect(session.navigation, before);
    });
  });
}

ProjectAggregateRoot _project(String siteValue) {
  final siteId = SiteId(siteValue);
  final buildingId = BuildingId('building-1');
  final levelId = LevelId('level-1');
  final spaceId = SpaceId('space-1');
  return ProjectAggregateRoot(
    id: ProjectId('project-$siteValue'),
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
          name: 'Floor 1',
          levelNumber: 1,
          elevationMm: 0,
          spaceIds: <SpaceId>[spaceId],
        ),
      },
      zones: const <ZoneId, ProjectStructuralZoneEntity>{},
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
