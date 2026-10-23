import 'package:elecx/src/application/project/project_authoring_error.dart';
import 'package:elecx/src/application/project/project_building_commands.dart';
import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P4A building commands', () {
    test('creates a building and updates site membership atomically', () {
      final session = ProjectMutationSession(_project());
      final buildingId = BuildingId('building-a');

      final result = session.commit(
        ProjectMutationRequest(
          expectedVersion: session.current.version,
          command: CreateBuildingCommand(
            buildingId: buildingId,
            name: 'Building A',
            displayOrder: 10,
          ),
        ),
      )!;

      final building = result.project.index.building(buildingId);
      expect(building, isNotNull);
      expect(building!.name, 'Building A');
      expect(building.displayOrder, 10);
      expect(building.levelIds, isEmpty);
      expect(
        result.project.index.site(result.project.siteId)!.buildingIds,
        contains(buildingId),
      );
      expect(result.project.version, LocalProjectVersion(1));
      expect(result.changeSet.addedEntityIds, <EntityId>{buildingId});
      expect(result.changeSet.updatedEntityIds, <EntityId>{
        SiteId('site-root'),
      });
    });

    test('rename preserves identity, hierarchy and display order', () {
      final session = ProjectMutationSession(_projectWithBuilding());
      final buildingId = BuildingId('building-a');

      final result = session.commit(
        ProjectMutationRequest(
          expectedVersion: session.current.version,
          command: RenameBuildingCommand(
            buildingId: buildingId,
            name: 'Renamed Building',
          ),
        ),
      )!;

      final building = result.project.index.building(buildingId)!;
      expect(building.id, buildingId);
      expect(building.siteId, SiteId('site-root'));
      expect(building.displayOrder, 10);
      expect(building.name, 'Renamed Building');
      expect(result.changeSet.updatedEntityIds, <EntityId>{buildingId});
      expect(result.changeSet.addedEntityIds, isEmpty);
      expect(result.changeSet.removedEntityIds, isEmpty);
    });

    test('rename to the same semantic value is suppressed as a no-op', () {
      final session = ProjectMutationSession(_projectWithBuilding());
      final before = session.current;

      final result = session.commit(
        ProjectMutationRequest(
          expectedVersion: before.version,
          command: RenameBuildingCommand(
            buildingId: BuildingId('building-a'),
            name: 'Building A',
          ),
        ),
      );

      expect(result, isNull);
      expect(session.current, same(before));
      expect(session.undoDepth, 0);
    });

    test('rejects duplicate building id before candidate commit', () {
      final session = ProjectMutationSession(_projectWithBuilding());

      expect(
        () => session.commit(
          ProjectMutationRequest(
            expectedVersion: session.current.version,
            command: CreateBuildingCommand(
              buildingId: BuildingId('building-a'),
              name: 'Duplicate',
            ),
          ),
        ),
        throwsA(
          isA<ProjectAuthoringException>().having(
            (error) => error.code,
            'code',
            ProjectAuthoringIssueCode.buildingAlreadyExists,
          ),
        ),
      );
      expect(session.current.version, LocalProjectVersion(0));
      expect(session.undoDepth, 0);
    });

    test('rejects rename of a missing building fail closed', () {
      final session = ProjectMutationSession(_project());

      expect(
        () => session.commit(
          ProjectMutationRequest(
            expectedVersion: session.current.version,
            command: RenameBuildingCommand(
              buildingId: BuildingId('missing'),
              name: 'Missing',
            ),
          ),
        ),
        throwsA(
          isA<ProjectAuthoringException>().having(
            (error) => error.code,
            'code',
            ProjectAuthoringIssueCode.buildingNotFound,
          ),
        ),
      );
      expect(session.current.version, LocalProjectVersion(0));
      expect(session.undoDepth, 0);
    });
  });
}

ProjectAggregateRoot _project() {
  final siteId = SiteId('site-root');
  return ProjectAggregateRoot(
    id: ProjectId('project-1'),
    siteId: siteId,
    version: LocalProjectVersion(0),
    stores: ProjectEntityStores(
      sites: <SiteId, ProjectSiteEntity>{
        siteId: ProjectSiteEntity(
          id: siteId,
          name: 'Site',
          buildingIds: const <BuildingId>[],
        ),
      },
    ),
  );
}

ProjectAggregateRoot _projectWithBuilding() {
  final siteId = SiteId('site-root');
  final buildingId = BuildingId('building-a');
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
          displayOrder: 10,
          levelIds: const <LevelId>[],
        ),
      },
    ),
  );
}
