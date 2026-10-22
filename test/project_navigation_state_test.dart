import 'package:elecx/src/application/project/project_navigation_state.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P5A ProjectNavigationState', () {
    test('initial state uses deterministic Building and Level ordering', () {
      final project = _project();

      final state = ProjectNavigationState.initial(project);

      expect(state.siteId, SiteId('site-root'));
      expect(state.activeBuildingId, BuildingId('building-a'));
      expect(state.activeLevelId, LevelId('a-level-1'));
      expect(state.selectedZoneId, isNull);
      expect(state.selectedSpaceId, isNull);
    });

    test('activating another Building atomically resolves its Level', () {
      final project = _project();
      final state = ProjectNavigationState.initial(project)
          .selectSpace(project, SpaceId('a-space-1'));

      final switched = state.activateBuilding(
        project,
        BuildingId('building-b'),
      );

      expect(switched.activeBuildingId, BuildingId('building-b'));
      expect(switched.activeLevelId, LevelId('b-level-1'));
      expect(switched.selectedZoneId, isNull);
      expect(switched.selectedSpaceId, isNull);
    });

    test('same-number Levels in different Buildings remain unambiguous', () {
      final project = _project();
      var state = ProjectNavigationState.initial(project);

      state = state.activateLevel(project, LevelId('b-level-1'));

      expect(state.activeBuildingId, BuildingId('building-b'));
      expect(state.activeLevelId, LevelId('b-level-1'));
      expect(project.index.level(state.activeLevelId!)!.levelNumber, 1);
      expect(
        project.index.level(LevelId('a-level-1'))!.levelNumber,
        project.index.level(LevelId('b-level-1'))!.levelNumber,
      );
    });

    test('selecting zoned Space derives full stable-ID current path', () {
      final project = _project();
      final state = ProjectNavigationState.initial(project)
          .selectSpace(project, SpaceId('a-space-1'));

      expect(state.activeBuildingId, BuildingId('building-a'));
      expect(state.activeLevelId, LevelId('a-level-1'));
      expect(state.selectedZoneId, ZoneId('a-zone-1'));
      expect(state.selectedSpaceId, SpaceId('a-space-1'));
    });

    test('selecting Zone changes context without selecting a Space', () {
      final project = _project();
      final state = ProjectNavigationState.initial(project)
          .selectZone(project, ZoneId('a-zone-1'));

      expect(state.activeBuildingId, BuildingId('building-a'));
      expect(state.activeLevelId, LevelId('a-level-1'));
      expect(state.selectedZoneId, ZoneId('a-zone-1'));
      expect(state.selectedSpaceId, isNull);
    });

    test('invalid explicit navigation fails closed without guessing', () {
      final project = _project();
      final state = ProjectNavigationState.initial(project);

      expect(
        () => state.activateLevel(project, LevelId('missing-level')),
        throwsA(
          isA<ProjectNavigationException>().having(
            (error) => error.code,
            'code',
            ProjectNavigationIssueCode.levelNotFound,
          ),
        ),
      );
      expect(
        () => state.selectSpace(project, SpaceId('missing-space')),
        throwsA(
          isA<ProjectNavigationException>().having(
            (error) => error.code,
            'code',
            ProjectNavigationIssueCode.spaceNotFound,
          ),
        ),
      );
      expect(state.activeBuildingId, BuildingId('building-a'));
      expect(state.activeLevelId, LevelId('a-level-1'));
    });

    test('restore validates persisted identities and keeps valid context', () {
      final project = _project();

      final restored = ProjectNavigationState.restore(
        project,
        activeBuildingId: BuildingId('building-a'),
        activeLevelId: LevelId('a-level-1'),
        selectedZoneId: ZoneId('a-zone-1'),
        selectedSpaceId: SpaceId('a-space-1'),
      );

      expect(restored.activeBuildingId, BuildingId('building-a'));
      expect(restored.activeLevelId, LevelId('a-level-1'));
      expect(restored.selectedZoneId, ZoneId('a-zone-1'));
      expect(restored.selectedSpaceId, SpaceId('a-space-1'));
    });

    test(
      'restore repairs invalid identities without label or number rebinding',
      () {
        final project = _project(includeBuildingA: false);

        final restored = ProjectNavigationState.restore(
          project,
          activeBuildingId: BuildingId('missing-building'),
          activeLevelId: LevelId('a-level-1'),
          selectedSpaceId: SpaceId('missing-space'),
        );

        expect(restored.activeBuildingId, BuildingId('building-b'));
        expect(restored.activeLevelId, LevelId('b-level-1'));
        expect(restored.selectedZoneId, isNull);
        expect(restored.selectedSpaceId, isNull);
      },
    );

    test('reconcile clears deleted selected Space and keeps Level context', () {
      final before = _project();
      final state = ProjectNavigationState.initial(before)
          .selectSpace(before, SpaceId('a-space-1'));
      final after = _project(includeZoneAndSpace: false);

      final repaired = state.reconcile(after);

      expect(repaired.activeBuildingId, BuildingId('building-a'));
      expect(repaired.activeLevelId, LevelId('a-level-1'));
      expect(repaired.selectedZoneId, isNull);
      expect(repaired.selectedSpaceId, isNull);
    });

    test(
      'generic reconcile replaces deleted active Level deterministically',
      () {
        final before = _project();
        final state = ProjectNavigationState.initial(before)
            .activateLevel(before, LevelId('a-level-2'));
        final after = _project(includeSecondLevelA: false);

        final repaired = state.reconcile(after);

        expect(repaired.activeBuildingId, BuildingId('building-a'));
        expect(repaired.activeLevelId, LevelId('a-level-1'));
        expect(repaired.selectedZoneId, isNull);
        expect(repaired.selectedSpaceId, isNull);
      },
    );

    test('mutation reconcile chooses next surviving Level neighbor first', () {
      final before = _project(includeThirdLevelA: true);
      final state = ProjectNavigationState.initial(before)
          .activateLevel(before, LevelId('a-level-2'));
      final after = _project(
        includeSecondLevelA: false,
        includeThirdLevelA: true,
      );

      final repaired = state.reconcileAfterMutation(
        before: before,
        after: after,
      );

      expect(repaired.activeBuildingId, BuildingId('building-a'));
      expect(repaired.activeLevelId, LevelId('a-level-3'));
    });

    test(
      'mutation reconcile falls back to previous Level when no next survives',
      () {
        final before = _project();
        final state = ProjectNavigationState.initial(before)
            .activateLevel(before, LevelId('a-level-2'));
        final after = _project(includeSecondLevelA: false);

        final repaired = state.reconcileAfterMutation(
          before: before,
          after: after,
        );

        expect(repaired.activeBuildingId, BuildingId('building-a'));
        expect(repaired.activeLevelId, LevelId('a-level-1'));
      },
    );

    test('reconcile replaces deleted active Building deterministically', () {
      final before = _project();
      final state = ProjectNavigationState.initial(before);
      final after = _project(includeBuildingA: false);

      final repaired = state.reconcileAfterMutation(
        before: before,
        after: after,
      );

      expect(repaired.activeBuildingId, BuildingId('building-b'));
      expect(repaired.activeLevelId, LevelId('b-level-1'));
    });

    test('reconcile never rebinds invalid identity by equal level number', () {
      final before = _project();
      final state = ProjectNavigationState.initial(before)
          .activateLevel(before, LevelId('a-level-1'));
      final after = _project(includeBuildingA: false);

      final repaired = state.reconcileAfterMutation(
        before: before,
        after: after,
      );

      expect(repaired.activeLevelId, LevelId('b-level-1'));
      expect(repaired.activeLevelId, isNot(LevelId('a-level-1')));
    });

    test('clearSelection preserves active structural context', () {
      final project = _project();
      final state = ProjectNavigationState.initial(project)
          .selectSpace(project, SpaceId('a-space-1'));

      final cleared = state.clearSelection();

      expect(cleared.siteId, state.siteId);
      expect(cleared.activeBuildingId, state.activeBuildingId);
      expect(cleared.activeLevelId, state.activeLevelId);
      expect(cleared.selectedZoneId, isNull);
      expect(cleared.selectedSpaceId, isNull);
    });

    test('navigation state has semantic value equality', () {
      final project = _project();
      final left = ProjectNavigationState.initial(project)
          .selectSpace(project, SpaceId('a-space-1'));
      final right = ProjectNavigationState.restore(
        project,
        activeBuildingId: BuildingId('building-a'),
        activeLevelId: LevelId('a-level-1'),
        selectedZoneId: ZoneId('a-zone-1'),
        selectedSpaceId: SpaceId('a-space-1'),
      );

      expect(left, right);
      expect(left.hashCode, right.hashCode);
    });
  });
}

ProjectAggregateRoot _project({
  bool includeBuildingA = true,
  bool includeSecondLevelA = true,
  bool includeThirdLevelA = false,
  bool includeZoneAndSpace = true,
}) {
  final siteId = SiteId('site-root');
  final buildingAId = BuildingId('building-a');
  final buildingBId = BuildingId('building-b');
  final aLevel1Id = LevelId('a-level-1');
  final aLevel2Id = LevelId('a-level-2');
  final aLevel3Id = LevelId('a-level-3');
  final bLevel1Id = LevelId('b-level-1');
  final zoneId = ZoneId('a-zone-1');
  final spaceId = SpaceId('a-space-1');

  return ProjectAggregateRoot(
    id: ProjectId('project-1'),
    siteId: siteId,
    version: LocalProjectVersion(0),
    stores: ProjectEntityStores(
      sites: <SiteId, ProjectSiteEntity>{
        siteId: ProjectSiteEntity(
          id: siteId,
          name: 'Site',
          buildingIds: <BuildingId>[
            if (includeBuildingA) buildingAId,
            buildingBId,
          ],
        ),
      },
      buildings: <BuildingId, ProjectBuildingEntity>{
        if (includeBuildingA)
          buildingAId: ProjectBuildingEntity(
            id: buildingAId,
            siteId: siteId,
            name: 'Building A',
            displayOrder: 0,
            levelIds: <LevelId>[
              aLevel1Id,
              if (includeSecondLevelA) aLevel2Id,
              if (includeThirdLevelA) aLevel3Id,
            ],
          ),
        buildingBId: ProjectBuildingEntity(
          id: buildingBId,
          siteId: siteId,
          name: 'Building B',
          displayOrder: 1,
          levelIds: <LevelId>[bLevel1Id],
        ),
      },
      levels: <LevelId, ProjectLevelEntity>{
        if (includeBuildingA)
          aLevel1Id: ProjectLevelEntity(
            id: aLevel1Id,
            buildingId: buildingAId,
            name: 'Floor 1',
            levelNumber: 1,
            displayOrder: 0,
            elevationMm: 0,
            zoneIds: includeZoneAndSpace ? <ZoneId>[zoneId] : const <ZoneId>[],
            spaceIds:
                includeZoneAndSpace ? <SpaceId>[spaceId] : const <SpaceId>[],
          ),
        if (includeBuildingA && includeSecondLevelA)
          aLevel2Id: ProjectLevelEntity(
            id: aLevel2Id,
            buildingId: buildingAId,
            name: 'Floor 2',
            levelNumber: 2,
            displayOrder: 1,
            elevationMm: 3000,
          ),
        if (includeBuildingA && includeThirdLevelA)
          aLevel3Id: ProjectLevelEntity(
            id: aLevel3Id,
            buildingId: buildingAId,
            name: 'Floor 3',
            levelNumber: 3,
            displayOrder: 2,
            elevationMm: 6000,
          ),
        bLevel1Id: ProjectLevelEntity(
          id: bLevel1Id,
          buildingId: buildingBId,
          name: 'Floor 1',
          levelNumber: 1,
          displayOrder: 0,
          elevationMm: 0,
        ),
      },
      zones: <ZoneId, ProjectStructuralZoneEntity>{
        if (includeBuildingA && includeZoneAndSpace)
          zoneId: ProjectStructuralZoneEntity(
            id: zoneId,
            levelId: aLevel1Id,
            name: 'Apartment 101',
            spaceIds: <SpaceId>[spaceId],
          ),
      },
      spaces: <SpaceId, ProjectSpaceEntity>{
        if (includeBuildingA && includeZoneAndSpace)
          spaceId: ProjectSpaceEntity(
            id: spaceId,
            levelId: aLevel1Id,
            name: 'Bedroom',
          ),
      },
    ),
  );
}
