import 'package:elecx/src/application/project/project_authoring_error.dart';
import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_space_semantics_commands.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_space_semantics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('removing a missing Space from an overlay fails closed', () {
    final session = ProjectMutationSession(_project());
    final before = session.current;

    expect(
      () => session.commit(
        ProjectMutationRequest(
          expectedVersion: session.current.version,
          command: RemoveSpaceFromOverlayCommand(
            overlayId: OverlayClassificationId('overlay-1'),
            spaceId: SpaceId('missing-space'),
          ),
        ),
      ),
      throwsA(
        isA<ProjectAuthoringException>().having(
          (error) => error.code,
          'code',
          ProjectAuthoringIssueCode.spaceNotFound,
        ),
      ),
    );
    expect(session.current, same(before));
    expect(session.current.version, LocalProjectVersion(0));
    expect(session.undoDepth, 0);
  });
}

ProjectAggregateRoot _project() {
  final siteId = SiteId('site-1');
  final buildingId = BuildingId('building-1');
  final levelId = LevelId('level-1');
  final roomId = SpaceId('room-1');
  final overlayId = OverlayClassificationId('overlay-1');

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
          spaceIds: <SpaceId>[roomId],
        ),
      },
      spaces: <SpaceId, ProjectSpaceEntity>{
        roomId: ProjectSpaceEntity(
          id: roomId,
          levelId: levelId,
          name: 'Room',
        ),
      },
      overlays: <OverlayClassificationId, ProjectOverlayClassificationEntity>{
        overlayId: ProjectOverlayClassificationEntity(
          id: overlayId,
          name: 'Electrical zone',
          discipline: OverlayDiscipline.electrical,
          kind: OverlayClassificationKind.electricalZone,
          spaceIds: <SpaceId>[roomId],
        ),
      },
    ),
  );
}
