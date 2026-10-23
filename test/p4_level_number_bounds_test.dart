import 'package:elecx/src/application/project/project_level_commands.dart';
import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P4 level number bounds', () {
    for (final levelNumber in const [-31, 201]) {
      test('create rejects out-of-range level number $levelNumber', () {
        final session = ProjectMutationSession(_project(withLevel: false));
        final before = session.current;

        expect(
          () => session.commit(
            ProjectMutationRequest(
              expectedVersion: before.version,
              command: CreateLevelCommand(
                levelId: LevelId('new-level'),
                buildingId: BuildingId('building-a'),
                name: 'Invalid',
                levelNumber: levelNumber,
                elevationMm: 0,
              ),
            ),
          ),
          throwsRangeError,
        );

        expect(session.current, same(before));
        expect(session.current.version, LocalProjectVersion(0));
        expect(session.undoDepth, 0);
        expect(session.redoDepth, 0);
      });
    }

    for (final levelNumber in const [-31, 201]) {
      test('renumber rejects out-of-range level number $levelNumber', () {
        final session = ProjectMutationSession(_project());
        final before = session.current;

        expect(
          () => session.commit(
            ProjectMutationRequest(
              expectedVersion: before.version,
              command: RenumberLevelCommand(
                levelId: LevelId('level-1'),
                levelNumber: levelNumber,
              ),
            ),
          ),
          throwsRangeError,
        );

        expect(session.current, same(before));
        expect(session.current.index.level(LevelId('level-1'))!.levelNumber, 1);
        expect(session.current.version, LocalProjectVersion(0));
        expect(session.undoDepth, 0);
        expect(session.redoDepth, 0);
      });
    }

    test('boundary values -30 and 200 remain valid', () {
      final lower = ProjectMutationSession(_project(withLevel: false));
      expect(
        lower.commit(
          ProjectMutationRequest(
            expectedVersion: lower.current.version,
            command: CreateLevelCommand(
              levelId: LevelId('basement-30'),
              buildingId: BuildingId('building-a'),
              name: 'B30',
              levelNumber: -30,
              elevationMm: -90000,
            ),
          ),
        ),
        isNotNull,
      );

      final upper = ProjectMutationSession(_project());
      expect(
        upper.commit(
          ProjectMutationRequest(
            expectedVersion: upper.current.version,
            command: RenumberLevelCommand(
              levelId: LevelId('level-1'),
              levelNumber: 200,
            ),
          ),
        ),
        isNotNull,
      );
      expect(upper.current.index.level(LevelId('level-1'))!.levelNumber, 200);
    });
  });
}

ProjectAggregateRoot _project({bool withLevel = true}) {
  final siteId = SiteId('site-root');
  final buildingId = BuildingId('building-a');
  final levelId = LevelId('level-1');

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
          name: 'Building',
          levelIds: [if (withLevel) levelId],
        ),
      },
      levels: {
        if (withLevel)
          levelId: ProjectLevelEntity(
            id: levelId,
            buildingId: buildingId,
            name: 'Floor 1',
            levelNumber: 1,
            elevationMm: 0,
          ),
      },
    ),
  );
}
