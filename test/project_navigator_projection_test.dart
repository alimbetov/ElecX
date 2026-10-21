import 'package:elecx/src/application/project/project_navigation_state.dart';
import 'package:elecx/src/application/project/project_navigator_projection.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P5B indexed Project Navigator + breadcrumb', () {
    test('projects canonical hierarchy without duplicating zoned Spaces', () {
      final project = _project();
      final projection = ProjectNavigatorProjection.build(project);

      expect(projection.root.id, SiteId('site-root'));
      expect(
        projection.root.childIds,
        <EntityId>[BuildingId('building-a'), BuildingId('building-b')],
      );

      final level = projection.node(LevelId('a-level-1'))!;
      expect(
        level.childIds,
        <EntityId>[ZoneId('zone-a'), SpaceId('space-unzoned')],
      );

      final zone = projection.node(ZoneId('zone-a'))!;
      expect(zone.childIds, <EntityId>[SpaceId('space-zoned')]);
      expect(
        projection.node(SpaceId('space-zoned'))!.parentId,
        ZoneId('zone-a'),
      );
    });

    test('projection records canonical project identity and source version', () {
      final project = _project(version: 7);
      final projection = ProjectNavigatorProjection.build(project);

      expect(projection.projectId, ProjectId('project-1'));
      expect(projection.sourceVersion, LocalProjectVersion(7));
      expect(projection.isCurrentFor(project), isTrue);
      expect(projection.isCurrentFor(_project(version: 8)), isFalse);
      expect(
        projection.isCurrentFor(_project(projectIdValue: 'project-2', version: 7)),
        isFalse,
      );
    });

    test('breadcrumb uses the same indexed path as selected Space', () {
      final project = _project();
      final projection = ProjectNavigatorProjection.build(project);
      final navigation = ProjectNavigationState.initial(project)
          .selectSpace(project, SpaceId('space-zoned'));

      final path = projection.pathTo(SpaceId('space-zoned'));
      final breadcrumb = projection.breadcrumb(navigation);

      expect(
        path.map((node) => node.id),
        <EntityId>[
          SiteId('site-root'),
          BuildingId('building-a'),
          LevelId('a-level-1'),
          ZoneId('zone-a'),
          SpaceId('space-zoned'),
        ],
      );
      expect(
        breadcrumb.map((item) => item.label),
        <String>[
          'Site',
          'Building A',
          'Floor 1',
          'Apartment 101',
          'Bedroom',
        ],
      );
    });

    test('unzoned Space path is Level to Space without synthetic Zone', () {
      final project = _project();
      final projection = ProjectNavigatorProjection.build(project);
      final navigation = ProjectNavigationState.initial(project)
          .selectSpace(project, SpaceId('space-unzoned'));

      expect(
        projection.breadcrumb(navigation).map((item) => item.id),
        <EntityId>[
          SiteId('site-root'),
          BuildingId('building-a'),
          LevelId('a-level-1'),
          SpaceId('space-unzoned'),
        ],
      );
    });

    test('required expansion contains only ancestors of current leaf', () {
      final project = _project();
      final projection = ProjectNavigatorProjection.build(project);
      final navigation = ProjectNavigationState.initial(project)
          .selectSpace(project, SpaceId('space-zoned'));

      expect(
        projection.requiredExpandedAncestorIds(navigation),
        <EntityId>{
          SiteId('site-root'),
          BuildingId('building-a'),
          LevelId('a-level-1'),
          ZoneId('zone-a'),
        },
      );
    });

    test('current path contains ancestors and selected leaf exactly once', () {
      final project = _project();
      final projection = ProjectNavigatorProjection.build(project);
      final navigation = ProjectNavigationState.initial(project)
          .selectSpace(project, SpaceId('space-zoned'));

      expect(
        projection.currentPathIds(navigation),
        <EntityId>{
          SiteId('site-root'),
          BuildingId('building-a'),
          LevelId('a-level-1'),
          ZoneId('zone-a'),
          SpaceId('space-zoned'),
        },
      );
    });

    test('active context and selected leaf presentation stay distinct', () {
      final project = _project();
      final projection = ProjectNavigatorProjection.build(project);
      final navigation = ProjectNavigationState.initial(project)
          .selectSpace(project, SpaceId('space-zoned'));

      final building = projection.node(BuildingId('building-a'))!;
      final level = projection.node(LevelId('a-level-1'))!;
      final zone = projection.node(ZoneId('zone-a'))!;
      final space = projection.node(SpaceId('space-zoned'))!;

      expect(projection.isActiveBuilding(building, navigation), isTrue);
      expect(projection.isActiveLevel(level, navigation), isTrue);
      expect(projection.isSelected(building, navigation), isFalse);
      expect(projection.isSelected(level, navigation), isFalse);
      expect(projection.isSelected(zone, navigation), isFalse);
      expect(projection.isSelected(space, navigation), isTrue);
      expect(projection.currentPathIds(navigation), contains(zone.id));
    });

    test('Zone is selected when it is the selected leaf', () {
      final project = _project();
      final projection = ProjectNavigatorProjection.build(project);
      final navigation = ProjectNavigationState.initial(project)
          .selectZone(project, ZoneId('zone-a'));

      final zone = projection.node(ZoneId('zone-a'))!;
      final space = projection.node(SpaceId('space-zoned'))!;

      expect(projection.isSelected(zone, navigation), isTrue);
      expect(projection.isSelected(space, navigation), isFalse);
      expect(projection.currentLeafId(navigation), zone.id);
    });

    test('same-number Levels in different Buildings remain distinct nodes', () {
      final project = _project();
      final projection = ProjectNavigatorProjection.build(project);

      final levelA = projection.node(LevelId('a-level-1'))!;
      final levelB = projection.node(LevelId('b-level-1'))!;

      expect(levelA.id, isNot(levelB.id));
      expect(levelA.parentId, BuildingId('building-a'));
      expect(levelB.parentId, BuildingId('building-b'));
      expect(project.index.level(LevelId('a-level-1'))!.levelNumber, 1);
      expect(project.index.level(LevelId('b-level-1'))!.levelNumber, 1);
    });

    test('ordering is deterministic and independent of Map insertion order',
        () {
      final projection = ProjectNavigatorProjection.build(
        _project(reverseInsertionOrder: true),
      );

      expect(
        projection.root.childIds,
        <EntityId>[BuildingId('building-a'), BuildingId('building-b')],
      );
      expect(
        projection.node(BuildingId('building-a'))!.childIds,
        <EntityId>[LevelId('a-level-1'), LevelId('a-level-2')],
      );
      expect(
        projection.node(LevelId('a-level-1'))!.childIds,
        <EntityId>[ZoneId('zone-a'), SpaceId('space-unzoned')],
      );
    });

    test('missing node path fails closed instead of guessing', () {
      final projection = ProjectNavigatorProjection.build(_project());

      expect(
        () => projection.pathTo(LevelId('missing-level')),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('navigation from another Site is rejected instead of rendered', () {
      final project = _project();
      final projection = ProjectNavigatorProjection.build(project);
      final otherProject = _project(siteIdValue: 'other-site');
      final otherNavigation = ProjectNavigationState.initial(otherProject);

      expect(
        () => projection.breadcrumb(otherNavigation),
        throwsA(isA<StateError>()),
      );
      expect(
        () => projection.currentPathIds(otherNavigation),
        throwsA(isA<StateError>()),
      );
      expect(
        () => projection.requiredExpandedAncestorIds(otherNavigation),
        throwsA(isA<StateError>()),
      );
    });

    test('level-only context produces Site Building Level breadcrumb', () {
      final project = _project();
      final projection = ProjectNavigatorProjection.build(project);
      final navigation = ProjectNavigationState.initial(project)
          .activateLevel(project, LevelId('b-level-1'));

      expect(
        projection.breadcrumb(navigation).map((item) => item.id),
        <EntityId>[
          SiteId('site-root'),
          BuildingId('building-b'),
          LevelId('b-level-1'),
        ],
      );
      expect(projection.currentLeafId(navigation), LevelId('b-level-1'));
    });
  });
}

ProjectAggregateRoot _project({
  bool reverseInsertionOrder = false,
  int version = 0,
  String projectIdValue = 'project-1',
  String siteIdValue = 'site-root',
}) {
  final siteId = SiteId(siteIdValue);
  final buildingAId = BuildingId('building-a');
  final buildingBId = BuildingId('building-b');
  final aLevel1Id = LevelId('a-level-1');
  final aLevel2Id = LevelId('a-level-2');
  final bLevel1Id = LevelId('b-level-1');
  final zoneId = ZoneId('zone-a');
  final zonedSpaceId = SpaceId('space-zoned');
  final unzonedSpaceId = SpaceId('space-unzoned');

  final buildings = <BuildingId, ProjectBuildingEntity>{};
  final levels = <LevelId, ProjectLevelEntity>{};

  void addBuildingA() {
    buildings[buildingAId] = ProjectBuildingEntity(
      id: buildingAId,
      siteId: siteId,
      name: 'Building A',
      displayOrder: 0,
      levelIds: <LevelId>[aLevel2Id, aLevel1Id],
    );
    levels[aLevel2Id] = ProjectLevelEntity(
      id: aLevel2Id,
      buildingId: buildingAId,
      name: 'Floor 2',
      levelNumber: 2,
      displayOrder: 1,
      elevationMm: 3000,
    );
    levels[aLevel1Id] = ProjectLevelEntity(
      id: aLevel1Id,
      buildingId: buildingAId,
      name: 'Floor 1',
      levelNumber: 1,
      displayOrder: 0,
      elevationMm: 0,
      zoneIds: <ZoneId>[zoneId],
      spaceIds: <SpaceId>[unzonedSpaceId, zonedSpaceId],
    );
  }

  void addBuildingB() {
    buildings[buildingBId] = ProjectBuildingEntity(
      id: buildingBId,
      siteId: siteId,
      name: 'Building B',
      displayOrder: 1,
      levelIds: <LevelId>[bLevel1Id],
    );
    levels[bLevel1Id] = ProjectLevelEntity(
      id: bLevel1Id,
      buildingId: buildingBId,
      name: 'Floor 1',
      levelNumber: 1,
      displayOrder: 0,
      elevationMm: 0,
    );
  }

  if (reverseInsertionOrder) {
    addBuildingB();
    addBuildingA();
  } else {
    addBuildingA();
    addBuildingB();
  }

  return ProjectAggregateRoot(
    id: ProjectId(projectIdValue),
    siteId: siteId,
    version: LocalProjectVersion(version),
    stores: ProjectEntityStores(
      sites: <SiteId, ProjectSiteEntity>{
        siteId: ProjectSiteEntity(
          id: siteId,
          name: 'Site',
          buildingIds: reverseInsertionOrder
              ? <BuildingId>[buildingBId, buildingAId]
              : <BuildingId>[buildingAId, buildingBId],
        ),
      },
      buildings: buildings,
      levels: levels,
      zones: <ZoneId, ProjectStructuralZoneEntity>{
        zoneId: ProjectStructuralZoneEntity(
          id: zoneId,
          levelId: aLevel1Id,
          name: 'Apartment 101',
          spaceIds: <SpaceId>[zonedSpaceId],
        ),
      },
      spaces: <SpaceId, ProjectSpaceEntity>{
        unzonedSpaceId: ProjectSpaceEntity(
          id: unzonedSpaceId,
          levelId: aLevel1Id,
          name: 'Corridor',
        ),
        zonedSpaceId: ProjectSpaceEntity(
          id: zonedSpaceId,
          levelId: aLevel1Id,
          name: 'Bedroom',
        ),
      },
    ),
  );
}
