import 'dart:math';

import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_navigation_state.dart';
import 'package:elecx/src/application/project/project_structure_authoring.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P5C structure authoring session', () {
    test('availability follows explicit canonical navigation context', () {
      final empty = _project();
      final emptySession = _session(empty);

      expect(emptySession.availability.canAddBuilding, isTrue);
      expect(emptySession.availability.canAddLevel, isFalse);
      expect(emptySession.availability.canAddRoom, isFalse);

      final withLevel = _project(includeBuilding: true, includeLevel: true);
      final levelSession = _session(withLevel);
      expect(levelSession.availability.canAddBuilding, isTrue);
      expect(levelSession.availability.canAddLevel, isTrue);
      expect(levelSession.availability.canAddRoom, isTrue);
    });

    test('create Building commits once and activates created Building', () {
      final session = _session(_project());
      final beforeVersion = session.project.version;

      final result = session.createBuilding(
        const CreateBuildingRequest(name: 'Building A', displayOrder: 3),
      );

      expect(result.project.version.value, beforeVersion.value + 1);
      expect(result.changeSet.commandType, 'project.building.create');
      expect(result.changeSet.addedEntityIds, contains(result.createdId));
      expect(result.navigation.activeBuildingId, result.createdId);
      expect(result.navigation.activeLevelId, isNull);
      expect(result.navigation.selectedSpaceId, isNull);
      expect(result.project.index.building(result.createdId)!.displayOrder, 3);
    });

    test('create Level targets active Building and makes new Level current', () {
      final session = _session(_project(includeBuilding: true));
      final buildingId = session.navigation.activeBuildingId!;

      final result = session.createLevel(
        const CreateLevelRequest(
          name: 'Floor 1',
          levelNumber: 1,
          elevationMm: 0,
          displayOrder: 4,
        ),
      );

      final level = result.project.index.level(result.createdId)!;
      expect(level.buildingId, buildingId);
      expect(level.displayOrder, 4);
      expect(result.navigation.activeBuildingId, buildingId);
      expect(result.navigation.activeLevelId, result.createdId);
      expect(result.navigation.selectedSpaceId, isNull);
      expect(result.changeSet.addedEntityIds, contains(result.createdId));
    });

    test('create Room keeps Level active and selects created Space', () {
      final project = _project(
        includeBuilding: true,
        includeLevel: true,
        includeZone: true,
      );
      final session = _session(project);
      final levelId = session.navigation.activeLevelId!;
      final zoneId = ZoneId('zone-a');

      final result = session.createRoom(
        CreateRoomRequest(name: 'Bedroom', structuralZoneId: zoneId),
      );

      final space = result.project.index.space(result.createdId)!;
      expect(space.levelId, levelId);
      expect(result.navigation.activeLevelId, levelId);
      expect(result.navigation.selectedZoneId, zoneId);
      expect(result.navigation.selectedSpaceId, result.createdId);
      expect(
        result.project.index.structuralZoneBySpace[result.createdId],
        zoneId,
      );
      expect(result.changeSet.addedEntityIds, contains(result.createdId));
    });

    test('failed Level creation preserves project and navigation', () {
      final project = _project(includeBuilding: true, includeLevel: true);
      final session = _session(project);
      final beforeNavigation = session.navigation;
      final beforeVersion = session.project.version;

      expect(
        () => session.createLevel(
          const CreateLevelRequest(
            name: 'Duplicate Floor 1',
            levelNumber: 1,
            elevationMm: 3000,
          ),
        ),
        throwsA(anything),
      );

      expect(session.project.version, beforeVersion);
      expect(session.navigation, beforeNavigation);
    });

    test('Room zone outside active Level is rejected before mutation', () {
      final project = _twoLevelProjectWithZoneOnSecond();
      final navigation = ProjectNavigationState.initial(project)
          .activateLevel(project, LevelId('level-1'));
      final session = _session(project, navigation: navigation);
      final beforeVersion = session.project.version;
      final beforeNavigation = session.navigation;

      expect(
        () => session.createRoom(
          CreateRoomRequest(
            name: 'Invalid room',
            structuralZoneId: ZoneId('zone-level-2'),
          ),
        ),
        throwsA(isA<StateError>()),
      );

      expect(session.project.version, beforeVersion);
      expect(session.navigation, beforeNavigation);
      expect(session.project.stores.spaces, isEmpty);
    });
  });
}

ProjectStructureAuthoringSession _session(
  ProjectAggregateRoot project, {
  ProjectNavigationState? navigation,
}) {
  return ProjectStructureAuthoringSession(
    mutations: ProjectMutationSession(project),
    idFactory: SecureRandomEntityIdFactory(random: Random(7)),
    navigation: navigation,
  );
}

ProjectAggregateRoot _project({
  bool includeBuilding = false,
  bool includeLevel = false,
  bool includeZone = false,
}) {
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
          buildingIds: includeBuilding ? <BuildingId>[buildingId] : const [],
        ),
      },
      buildings: <BuildingId, ProjectBuildingEntity>{
        if (includeBuilding)
          buildingId: ProjectBuildingEntity(
            id: buildingId,
            siteId: siteId,
            name: 'Building A',
            levelIds: includeLevel ? <LevelId>[levelId] : const [],
          ),
      },
      levels: <LevelId, ProjectLevelEntity>{
        if (includeLevel)
          levelId: ProjectLevelEntity(
            id: levelId,
            buildingId: buildingId,
            name: 'Floor 1',
            levelNumber: 1,
            elevationMm: 0,
            zoneIds: includeZone ? <ZoneId>[zoneId] : const [],
          ),
      },
      zones: <ZoneId, ProjectStructuralZoneEntity>{
        if (includeZone)
          zoneId: ProjectStructuralZoneEntity(
            id: zoneId,
            levelId: levelId,
            name: 'Apartment 101',
            spaceIds: const [],
          ),
      },
      spaces: const <SpaceId, ProjectSpaceEntity>{},
    ),
  );
}

ProjectAggregateRoot _twoLevelProjectWithZoneOnSecond() {
  final siteId = SiteId('site-root');
  final buildingId = BuildingId('building-a');
  final level1 = LevelId('level-1');
  final level2 = LevelId('level-2');
  final zoneId = ZoneId('zone-level-2');

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
          levelIds: <LevelId>[level1, level2],
        ),
      },
      levels: <LevelId, ProjectLevelEntity>{
        level1: ProjectLevelEntity(
          id: level1,
          buildingId: buildingId,
          name: 'Floor 1',
          levelNumber: 1,
          elevationMm: 0,
        ),
        level2: ProjectLevelEntity(
          id: level2,
          buildingId: buildingId,
          name: 'Floor 2',
          levelNumber: 2,
          elevationMm: 3000,
          zoneIds: <ZoneId>[zoneId],
        ),
      },
      zones: <ZoneId, ProjectStructuralZoneEntity>{
        zoneId: ProjectStructuralZoneEntity(
          id: zoneId,
          levelId: level2,
          name: 'Apartment 201',
          spaceIds: const [],
        ),
      },
      spaces: const <SpaceId, ProjectSpaceEntity>{},
    ),
  );
}
