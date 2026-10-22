import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_space_semantics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P6A semantic invariants', () {
    test('opening rejects duplicate connectivity before Set normalization', () {
      final room = SpaceId('room-a');

      expect(
        () => ProjectOpeningEntity(
          id: OpeningId('opening-1'),
          levelId: LevelId('level-1'),
          kind: OpeningKind.door,
          connectedSpaceIds: <SpaceId>[room, room],
          widthMm: 900,
          heightMm: 2100,
        ),
        throwsArgumentError,
      );
    });

    test('only opening adjacency may carry openingId', () {
      expect(
        () => ProjectSpaceAdjacencyEntity(
          id: SpaceAdjacencyId('adj-1'),
          spaceAId: SpaceId('room-a'),
          spaceBId: SpaceId('room-b'),
          kind: SpaceAdjacencyKind.sharedBoundary,
          openingId: OpeningId('opening-1'),
        ),
        throwsArgumentError,
      );
    });

    test('overlay discipline and kind must be semantically compatible', () {
      expect(
        () => ProjectOverlayClassificationEntity(
          id: OverlayClassificationId('overlay-1'),
          name: 'Wrong domain',
          discipline: OverlayDiscipline.fireSafety,
          kind: OverlayClassificationKind.electricalZone,
        ),
        throwsArgumentError,
      );

      expect(
        ProjectOverlayClassificationEntity(
          id: OverlayClassificationId('overlay-2'),
          name: 'Smoke zone',
          discipline: OverlayDiscipline.fireSafety,
          kind: OverlayClassificationKind.smokeZone,
        ).kind,
        OverlayClassificationKind.smokeZone,
      );
    });
  });

  group('P6B aggregate and index invariants', () {
    test('canonical store key must equal entity id', () {
      final base = _twoRoomStores();
      final entityId = OpeningId('opening-entity');
      final mapKey = OpeningId('opening-map-key');
      final stores = _copyStores(
        base,
        openings: <OpeningId, ProjectOpeningEntity>{
          mapKey: ProjectOpeningEntity(
            id: entityId,
            levelId: LevelId('level-1'),
            kind: OpeningKind.window,
            connectedSpaceIds: <SpaceId>[SpaceId('room-a')],
            widthMm: 1200,
            heightMm: 1400,
            baseElevationMm: 900,
          ),
        },
      );

      expect(
        () => ProjectAggregateRoot(
          id: ProjectId('project-1'),
          siteId: SiteId('site-1'),
          version: LocalProjectVersion(0),
          stores: stores,
        ),
        throwsA(
          isA<ProjectAggregateValidationException>().having(
            (error) => error.issues.map((issue) => issue.code),
            'issue codes',
            contains(ProjectAggregateIssueCode.storeKeyIdMismatch),
          ),
        ),
      );
    });

    test('vertical adjacency may cross levels but horizontal adjacency may not', () {
      final verticalStores = _twoLevelStores(
        adjacencyKind: SpaceAdjacencyKind.vertical,
      );
      final project = ProjectAggregateRoot(
        id: ProjectId('project-1'),
        siteId: SiteId('site-1'),
        version: LocalProjectVersion(0),
        stores: verticalStores,
      );
      expect(project.index.adjacency(SpaceAdjacencyId('adj-1')), isNotNull);

      expect(
        () => ProjectAggregateRoot(
          id: ProjectId('project-1'),
          siteId: SiteId('site-1'),
          version: LocalProjectVersion(0),
          stores: _twoLevelStores(
            adjacencyKind: SpaceAdjacencyKind.sharedBoundary,
          ),
        ),
        throwsA(
          isA<ProjectAggregateValidationException>().having(
            (error) => error.issues.map((issue) => issue.code),
            'issue codes',
            contains(ProjectAggregateIssueCode.adjacencyLevelMismatch),
          ),
        ),
      );
    });

    test('vertical adjacency on the same level is rejected', () {
      final base = _twoRoomStores();
      final stores = _copyStores(
        base,
        adjacencies: <SpaceAdjacencyId, ProjectSpaceAdjacencyEntity>{
          SpaceAdjacencyId('adj-1'): ProjectSpaceAdjacencyEntity(
            id: SpaceAdjacencyId('adj-1'),
            spaceAId: SpaceId('room-a'),
            spaceBId: SpaceId('room-b'),
            kind: SpaceAdjacencyKind.vertical,
          ),
        },
      );

      expect(
        () => ProjectAggregateRoot(
          id: ProjectId('project-1'),
          siteId: SiteId('site-1'),
          version: LocalProjectVersion(0),
          stores: stores,
        ),
        throwsA(
          isA<ProjectAggregateValidationException>().having(
            (error) => error.issues.map((issue) => issue.code),
            'issue codes',
            contains(ProjectAggregateIssueCode.verticalAdjacencyLevelMismatch),
          ),
        ),
      );
    });

    test('index consistency detects stale extra reverse projection entries', () {
      final roomA = SpaceId('room-a');
      final roomB = SpaceId('room-b');
      final openingId = OpeningId('opening-1');
      final base = _twoRoomStores();
      final initialStores = _copyStores(
        base,
        openings: <OpeningId, ProjectOpeningEntity>{
          openingId: ProjectOpeningEntity(
            id: openingId,
            levelId: LevelId('level-1'),
            kind: OpeningKind.door,
            connectedSpaceIds: <SpaceId>[roomA, roomB],
            widthMm: 900,
            heightMm: 2100,
          ),
        },
      );
      final project = ProjectAggregateRoot(
        id: ProjectId('project-1'),
        siteId: SiteId('site-1'),
        version: LocalProjectVersion(0),
        stores: initialStores,
      );
      final reducedStores = _copyStores(
        base,
        openings: <OpeningId, ProjectOpeningEntity>{
          openingId: ProjectOpeningEntity(
            id: openingId,
            levelId: LevelId('level-1'),
            kind: OpeningKind.window,
            connectedSpaceIds: <SpaceId>[roomA],
            widthMm: 900,
            heightMm: 1200,
          ),
        },
      );

      expect(project.index.isConsistentWith(reducedStores), isFalse);
    });
  });
}

ProjectEntityStores _twoRoomStores() {
  final siteId = SiteId('site-1');
  final buildingId = BuildingId('building-1');
  final levelId = LevelId('level-1');
  final roomA = SpaceId('room-a');
  final roomB = SpaceId('room-b');
  return ProjectEntityStores(
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
        spaceIds: <SpaceId>[roomA, roomB],
      ),
    },
    spaces: <SpaceId, ProjectSpaceEntity>{
      roomA: ProjectSpaceEntity(id: roomA, levelId: levelId, name: 'Room A'),
      roomB: ProjectSpaceEntity(id: roomB, levelId: levelId, name: 'Room B'),
    },
  );
}

ProjectEntityStores _twoLevelStores({required SpaceAdjacencyKind adjacencyKind}) {
  final siteId = SiteId('site-1');
  final buildingId = BuildingId('building-1');
  final level1 = LevelId('level-1');
  final level2 = LevelId('level-2');
  final roomA = SpaceId('room-a');
  final roomB = SpaceId('room-b');
  final adjacencyId = SpaceAdjacencyId('adj-1');
  return ProjectEntityStores(
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
        spaceIds: <SpaceId>[roomA],
      ),
      level2: ProjectLevelEntity(
        id: level2,
        buildingId: buildingId,
        name: 'Floor 2',
        levelNumber: 2,
        elevationMm: 3000,
        spaceIds: <SpaceId>[roomB],
      ),
    },
    spaces: <SpaceId, ProjectSpaceEntity>{
      roomA: ProjectSpaceEntity(id: roomA, levelId: level1, name: 'Room A'),
      roomB: ProjectSpaceEntity(id: roomB, levelId: level2, name: 'Room B'),
    },
    adjacencies: <SpaceAdjacencyId, ProjectSpaceAdjacencyEntity>{
      adjacencyId: ProjectSpaceAdjacencyEntity(
        id: adjacencyId,
        spaceAId: roomA,
        spaceBId: roomB,
        kind: adjacencyKind,
      ),
    },
  );
}

ProjectEntityStores _copyStores(
  ProjectEntityStores source, {
  Map<OpeningId, ProjectOpeningEntity>? openings,
  Map<SpaceAdjacencyId, ProjectSpaceAdjacencyEntity>? adjacencies,
}) => ProjectEntityStores(
  sites: source.sites,
  buildings: source.buildings,
  levels: source.levels,
  zones: source.zones,
  spaces: source.spaces,
  openings: openings ?? source.openings,
  adjacencies: adjacencies ?? source.adjacencies,
  overlays: source.overlays,
);
