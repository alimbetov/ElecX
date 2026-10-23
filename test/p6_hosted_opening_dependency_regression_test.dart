import 'package:elecx/src/application/project/project_authoring_error.dart';
import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_space_semantics_commands.dart';
import 'package:elecx/src/domain/boundary_host_migration.dart';
import 'package:elecx/src/domain/boundary_host_registry.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_orientation.dart';
import 'package:elecx/src/domain/project_space_semantics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P6 opening mutations after P7 host adoption', () {
    test('hosted opening cannot be changed by the semantic-only command', () {
      final session = ProjectMutationSession(_hostedOpeningProject());
      final before = session.current;

      expect(
        () => session.commit(
          ProjectMutationRequest(
            expectedVersion: session.current.version,
            command: UpdateOpeningCommand(
              opening: ProjectOpeningEntity(
                id: OpeningId('door-1'),
                levelId: LevelId('level-1'),
                kind: OpeningKind.door,
                connectedSpaceIds: <SpaceId>[
                  SpaceId('room-a'),
                  SpaceId('room-b'),
                ],
                widthMm: 1000,
                heightMm: 2100,
              ),
            ),
          ),
        ),
        throwsA(
          isA<ProjectAuthoringException>()
              .having(
                (error) => error.code,
                'code',
                ProjectAuthoringIssueCode.openingHasBoundaryDependencies,
              )
              .having(
                (error) => error.blockingEntityIds,
                'blocking boundary edges',
                <EntityId>{BoundaryEdgeId('edge-a')},
              ),
        ),
      );
      expect(session.current, same(before));
      expect(session.undoDepth, 0);
    });

    test('hosted opening cannot be removed before its P7 host is detached', () {
      final session = ProjectMutationSession(_hostedOpeningProject());
      final before = session.current;

      expect(
        () => session.commit(
          ProjectMutationRequest(
            expectedVersion: session.current.version,
            command: RemoveOpeningCommand(openingId: OpeningId('door-1')),
          ),
        ),
        throwsA(
          isA<ProjectAuthoringException>().having(
            (error) => error.code,
            'code',
            ProjectAuthoringIssueCode.openingHasBoundaryDependencies,
          ),
        ),
      );
      expect(session.current, same(before));
      expect(session.undoDepth, 0);
    });

    test('identical hosted opening update remains a semantic no-op', () {
      final session = ProjectMutationSession(_hostedOpeningProject());

      final result = session.commit(
        ProjectMutationRequest(
          expectedVersion: session.current.version,
          command: UpdateOpeningCommand(
            opening: ProjectOpeningEntity(
              id: OpeningId('door-1'),
              levelId: LevelId('level-1'),
              kind: OpeningKind.door,
              connectedSpaceIds: <SpaceId>[
                SpaceId('room-b'),
                SpaceId('room-a'),
              ],
              widthMm: 900,
              heightMm: 2100,
            ),
          ),
        ),
      );

      expect(result, isNull);
      expect(session.current.version, LocalProjectVersion(0));
      expect(session.undoDepth, 0);
    });
  });
}

ProjectAggregateRoot _hostedOpeningProject() {
  final siteId = SiteId('site-1');
  final buildingId = BuildingId('building-1');
  final levelId = LevelId('level-1');
  final roomA = SpaceId('room-a');
  final roomB = SpaceId('room-b');
  final openingId = OpeningId('door-1');
  final edgeId = BoundaryEdgeId('edge-a');
  final host = BoundaryEdgeHostRef(spaceId: roomA, edgeId: edgeId);
  final hostedObjects = const BoundaryHostedObjectRegistry.empty().putOpening(
    openingId: openingId,
    host: host,
    startOffsetMm: 100,
    endOffsetMm: 1000,
  );

  return ProjectAggregateRoot(
    id: ProjectId('project-1'),
    siteId: siteId,
    version: LocalProjectVersion(0),
    engineeringMetadata: ProjectEngineeringMetadata(
      boundaryHostedObjectRegistry: hostedObjects,
    ),
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
          spaceIds: <SpaceId>[roomA, roomB],
        ),
      },
      spaces: <SpaceId, ProjectSpaceEntity>{
        roomA: ProjectSpaceEntity(id: roomA, levelId: levelId, name: 'Room A'),
        roomB: ProjectSpaceEntity(id: roomB, levelId: levelId, name: 'Room B'),
      },
      openings: <OpeningId, ProjectOpeningEntity>{
        openingId: ProjectOpeningEntity(
          id: openingId,
          levelId: levelId,
          kind: OpeningKind.door,
          connectedSpaceIds: <SpaceId>[roomA, roomB],
          widthMm: 900,
          heightMm: 2100,
        ),
      },
    ),
  );
}
