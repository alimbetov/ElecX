import 'package:elecx/src/application/project/project_authoring_error.dart';
import 'package:elecx/src/application/project/project_destructive_commands.dart';
import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/vertical_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'P4E remove level reports every VerticalCore blocker and stays revision-neutral',
    () {
      final session = ProjectMutationSession(_projectWithVerticalCores());
      final before = session.current;
      final levelId = LevelId('level-1');
      final expectedBlockers = <EntityId>{
        VerticalCoreId('core-a'),
        VerticalCoreId('core-b'),
      };

      expect(
        () => session.commit(
          ProjectMutationRequest(
            expectedVersion: before.version,
            command: RemoveLevelCommand(levelId: levelId),
          ),
        ),
        throwsA(
          isA<ProjectAuthoringException>()
              .having(
                (error) => error.code,
                'code',
                ProjectAuthoringIssueCode.levelHasVerticalCores,
              )
              .having((error) => error.entityId, 'entityId', levelId)
              .having(
                (error) => error.blockingEntityIds,
                'blockingEntityIds',
                expectedBlockers,
              )
              .having(
                (error) => expectedBlockers.contains(error.relatedEntityId),
                'relatedEntityId is one blocker',
                isTrue,
              ),
        ),
      );

      expect(session.current, same(before));
      expect(session.current.version, LocalProjectVersion(0));
      expect(session.undoDepth, 0);
      expect(session.redoDepth, 0);
    },
  );
}

ProjectAggregateRoot _projectWithVerticalCores() {
  final siteId = SiteId('site-root');
  final buildingId = BuildingId('building-a');
  final level1 = LevelId('level-1');
  final level2 = LevelId('level-2');
  final level3 = LevelId('level-3');
  final coreA = VerticalCoreId('core-a');
  final coreB = VerticalCoreId('core-b');
  const footprint = <BoundaryPointMm>[
    BoundaryPointMm(xMm: 0, yMm: 0),
    BoundaryPointMm(xMm: 500, yMm: 0),
    BoundaryPointMm(xMm: 500, yMm: 500),
    BoundaryPointMm(xMm: 0, yMm: 500),
  ];

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
          name: 'Building A',
          levelIds: [level1, level2, level3],
        ),
      },
      levels: {
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
        ),
        level3: ProjectLevelEntity(
          id: level3,
          buildingId: buildingId,
          name: 'Floor 3',
          levelNumber: 3,
          elevationMm: 6000,
        ),
      },
      verticalCores: {
        coreA: ProjectVerticalCore(
          id: coreA,
          buildingId: buildingId,
          kind: VerticalCoreKind.riser,
          levelIds: [level1, level2],
          footprint: footprint,
        ),
        coreB: ProjectVerticalCore(
          id: coreB,
          buildingId: buildingId,
          kind: VerticalCoreKind.shaft,
          levelIds: [level1, level3],
          footprint: footprint,
        ),
      },
    ),
  );
}
