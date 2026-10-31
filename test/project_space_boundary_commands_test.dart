import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_space_boundary_commands.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PRE-P12 atomic canonical room geometry', () {
    test('creates Space + boundary in one version and one undo record', () {
      final session = ProjectMutationSession(_project());
      final spaceId = SpaceId('room-1');
      final edgeIds = <BoundaryEdgeId>[
        BoundaryEdgeId('room-1-edge-1'),
        BoundaryEdgeId('room-1-edge-2'),
        BoundaryEdgeId('room-1-edge-3'),
        BoundaryEdgeId('room-1-edge-4'),
      ];

      final result = session.commit(
        ProjectMutationRequest(
          expectedVersion: session.current.version,
          command: CreateSpaceWithBoundaryCommand(
            spaceId: spaceId,
            levelId: LevelId('level-1'),
            name: 'Room 1',
            boundaryPoints: const <BoundaryPointMm>[
              BoundaryPointMm(xMm: 1000, yMm: 2000),
              BoundaryPointMm(xMm: 5000, yMm: 2000),
              BoundaryPointMm(xMm: 5000, yMm: 6000),
              BoundaryPointMm(xMm: 1000, yMm: 6000),
            ],
            boundaryEdgeIds: edgeIds,
          ),
        ),
      )!;

      final room = result.project.index.space(spaceId)!;
      final boundary = result.project.index.boundary(spaceId)!;
      expect(room.type, ProjectSpaceType.room);
      expect(room.levelId, LevelId('level-1'));
      expect(boundary.spaceId, spaceId);
      expect(boundary.orderedEdgeIds, edgeIds);
      expect(boundary.validate(), isEmpty);
      expect(
        result.project.index.level(LevelId('level-1'))!.spaceIds,
        contains(spaceId),
      );
      expect(result.project.version, LocalProjectVersion(1));
      expect(session.undoDepth, 1);

      final undone = session.undo(session.current.version)!;
      expect(undone.project.index.space(spaceId), isNull);
      expect(undone.project.index.boundary(spaceId), isNull);
      expect(session.redoDepth, 1);

      final redone = session.redo(session.current.version)!;
      expect(redone.project.index.space(spaceId), isNotNull);
      expect(redone.project.index.boundary(spaceId)!.validate(), isEmpty);
    });

    test('rejects duplicate boundary identities before mutation', () {
      final session = ProjectMutationSession(_project());
      final duplicate = BoundaryEdgeId('edge-duplicate');

      expect(
        () => CreateSpaceWithBoundaryCommand(
          spaceId: SpaceId('room-1'),
          levelId: LevelId('level-1'),
          name: 'Room 1',
          boundaryPoints: const <BoundaryPointMm>[
            BoundaryPointMm(xMm: 0, yMm: 0),
            BoundaryPointMm(xMm: 4000, yMm: 0),
            BoundaryPointMm(xMm: 4000, yMm: 4000),
            BoundaryPointMm(xMm: 0, yMm: 4000),
          ],
          boundaryEdgeIds: <BoundaryEdgeId>[
            duplicate,
            BoundaryEdgeId('edge-2'),
            BoundaryEdgeId('edge-3'),
            duplicate,
          ],
        ),
        throwsArgumentError,
      );
      expect(session.current.version, LocalProjectVersion(0));
      expect(session.undoDepth, 0);
    });
  });
}

ProjectAggregateRoot _project() {
  final siteId = SiteId('site-root');
  final buildingId = BuildingId('building-1');
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
          name: 'Building',
          levelIds: <LevelId>[levelId],
        ),
      },
      levels: <LevelId, ProjectLevelEntity>{
        levelId: ProjectLevelEntity(
          id: levelId,
          buildingId: buildingId,
          name: 'Level 1',
          levelNumber: 1,
          elevationMm: 0,
        ),
      },
    ),
  );
}
