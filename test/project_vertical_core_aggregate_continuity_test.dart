import 'package:elecx/src/application/project/project_level_commands.dart';
import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/vertical_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('aggregate loading rejects a VerticalCore with a skipped level', () {
    final level1 = LevelId('level-1');
    final level2 = LevelId('level-2');
    final level3 = LevelId('level-3');

    expect(
      () => _project(
        levelIds: [level1, level2, level3],
        levels: [
          _level(level1, number: 1, elevationMm: 0),
          _level(level2, number: 2, elevationMm: 3000),
          _level(level3, number: 3, elevationMm: 6000),
        ],
        coreLevelIds: [level1, level3],
      ),
      throwsA(
        isA<ProjectAggregateValidationException>().having(
          (error) => error.issues.map((issue) => issue.code),
          'issue codes',
          contains(ProjectAggregateIssueCode.invalidVerticalCoreContinuity),
        ),
      ),
    );
  });

  test('inserting a physical level revalidates existing core continuity', () {
    final level1 = LevelId('level-1');
    final level3 = LevelId('level-3');
    final session = ProjectMutationSession(
      _project(
        levelIds: [level1, level3],
        levels: [
          _level(level1, number: 1, elevationMm: 0),
          _level(level3, number: 3, elevationMm: 6000),
        ],
        coreLevelIds: [level1, level3],
      ),
    );

    final level2 = LevelId('level-2');
    expect(
      () => session.commit(
        ProjectMutationRequest(
          expectedVersion: session.current.version,
          command: CreateLevelCommand(
            levelId: level2,
            buildingId: BuildingId('building'),
            name: 'Level 2',
            levelNumber: 2,
            elevationMm: 3000,
          ),
        ),
      ),
      throwsA(
        isA<ProjectCandidateValidationException>().having(
          (error) => error.issues.map((issue) => issue.code),
          'issue codes',
          contains(ProjectAggregateIssueCode.invalidVerticalCoreContinuity),
        ),
      ),
    );
    expect(session.current.version, LocalProjectVersion(0));
    expect(session.current.stores.levels, hasLength(2));
  });
}

ProjectAggregateRoot _project({
  required List<LevelId> levelIds,
  required List<ProjectLevelEntity> levels,
  required List<LevelId> coreLevelIds,
}) {
  final siteId = SiteId('site');
  final buildingId = BuildingId('building');
  final coreId = VerticalCoreId('core');
  return ProjectAggregateRoot(
    id: ProjectId('project'),
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
          name: 'Building',
          levelIds: levelIds,
        ),
      },
      levels: {for (final level in levels) level.id: level},
      verticalCores: {
        coreId: ProjectVerticalCore(
          id: coreId,
          buildingId: buildingId,
          kind: VerticalCoreKind.riser,
          levelIds: coreLevelIds,
          footprint: const [
            BoundaryPointMm(xMm: 0, yMm: 0),
            BoundaryPointMm(xMm: 100, yMm: 0),
            BoundaryPointMm(xMm: 100, yMm: 100),
          ],
        ),
      },
    ),
  );
}

ProjectLevelEntity _level(
  LevelId id, {
  required int number,
  required int elevationMm,
}) => ProjectLevelEntity(
  id: id,
  buildingId: BuildingId('building'),
  name: 'Level $number',
  levelNumber: number,
  elevationMm: elevationMm,
);
