import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_room_rectangle_authoring.dart';
import 'package:elecx/src/application/project/project_structure_authoring.dart';
import 'package:elecx/src/application/project/wizard/project_wizard_mutation_port.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PRE-P12 production room rectangle authoring', () {
    test('uses shared reservation timeline and selects canonical room', () {
      final aggregate = _project();
      final mutations = ProjectMutationSession(aggregate);
      final ids = SecureRandomEntityIdFactory();
      final session = ProjectStructureAuthoringSession(
        mutations: mutations,
        idFactory: ids,
        navigation: ProjectNavigationState.restore(
          aggregate,
          activeBuildingId: BuildingId('building-1'),
          activeLevelId: LevelId('level-1'),
        ),
      );
      final wizardMutations = SharedProjectWizardMutationPort(
        mutations: mutations,
        idFactory: ids,
      );
      final service = RoomRectangleAuthoringService(
        session: session,
        mutations: wizardMutations,
      );

      final result = service.commit(
        RoomRectangleAuthoringIntent(
          levelId: LevelId('level-1'),
          first: const BoundaryPointMm(xMm: 5000, yMm: 6000),
          second: const BoundaryPointMm(xMm: 1000, yMm: 2000),
          name: 'Room A',
        ),
      );

      final room = session.project.index.space(result.spaceId)!;
      final topology = session.project.index.boundary(result.spaceId)!;
      expect(room.levelId, LevelId('level-1'));
      expect(room.name, 'Room A');
      expect(topology.validate(), isEmpty);
      expect(topology.orderedEdgeIds, hasLength(4));
      expect(
        topology.edges[topology.orderedEdgeIds.first]!.start,
        const BoundaryPointMm(xMm: 1000, yMm: 2000),
      );
      expect(session.navigation.selectedSpaceId, result.spaceId);
      expect(session.project.version, LocalProjectVersion(1));
      expect(mutations.undoDepth, 1);
      expect(wizardMutations.activePreviewCount, 0);

      final undone = session.undoCanonicalMutation()!;
      expect(undone.project.index.space(result.spaceId), isNull);
      expect(undone.project.index.boundary(result.spaceId), isNull);
    });

    test('fails closed when rectangle target is not active Level', () {
      final aggregate = _project();
      final mutations = ProjectMutationSession(aggregate);
      final ids = SecureRandomEntityIdFactory();
      final session = ProjectStructureAuthoringSession(
        mutations: mutations,
        idFactory: ids,
        navigation: ProjectNavigationState.restore(
          aggregate,
          activeBuildingId: BuildingId('building-1'),
          activeLevelId: LevelId('level-1'),
        ),
      );
      final service = RoomRectangleAuthoringService(
        session: session,
        mutations: SharedProjectWizardMutationPort(
          mutations: mutations,
          idFactory: ids,
        ),
      );

      expect(
        () => service.commit(
          RoomRectangleAuthoringIntent(
            levelId: LevelId('foreign-level'),
            first: const BoundaryPointMm(xMm: 0, yMm: 0),
            second: const BoundaryPointMm(xMm: 4000, yMm: 4000),
            name: 'Foreign',
          ),
        ),
        throwsStateError,
      );
      expect(session.project.version, LocalProjectVersion(0));
      expect(mutations.undoDepth, 0);
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
