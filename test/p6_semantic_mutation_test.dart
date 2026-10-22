import 'package:elecx/src/application/project/project_authoring_error.dart';
import 'package:elecx/src/application/project/project_destructive_commands.dart';
import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_space_commands.dart';
import 'package:elecx/src/application/project/project_space_semantics_commands.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_space_semantics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P6 semantic mutations', () {
    test(
      'SetSpaceUsage is one canonical mutation and same value is a no-op',
      () {
        final session = ProjectMutationSession(_baseProject());
        final roomA = SpaceId('room-a');

        final result = session.commit(
          ProjectMutationRequest(
            expectedVersion: session.current.version,
            command: SetSpaceUsageCommand(
              spaceId: roomA,
              usage: SpaceUsage.bedroom,
            ),
          ),
        )!;

        expect(result.project.index.space(roomA)!.usage, SpaceUsage.bedroom);
        expect(result.project.version, LocalProjectVersion(1));
        expect(result.changeSet.updatedEntityIds, <EntityId>{roomA});
        expect(session.undoDepth, 1);

        final noOp = session.commit(
          ProjectMutationRequest(
            expectedVersion: session.current.version,
            command: SetSpaceUsageCommand(
              spaceId: roomA,
              usage: SpaceUsage.bedroom,
            ),
          ),
        );
        expect(noOp, isNull);
        expect(session.current.version, LocalProjectVersion(1));
        expect(session.undoDepth, 1);

        final undone = session.undo(session.current.version)!;
        expect(undone.project.index.space(roomA)!.usage, SpaceUsage.unknown);
        expect(undone.project.version, LocalProjectVersion(2));

        final redone = session.redo(session.current.version)!;
        expect(redone.project.index.space(roomA)!.usage, SpaceUsage.bedroom);
        expect(redone.project.version, LocalProjectVersion(3));
      },
    );

    test('opening, adjacency and overlay participate in diff and indexes', () {
      final session = ProjectMutationSession(_baseProject());
      final roomA = SpaceId('room-a');
      final roomB = SpaceId('room-b');
      final openingId = OpeningId('door-1');
      final adjacencyId = SpaceAdjacencyId('adj-1');
      final overlayId = OverlayClassificationId('fire-1');

      final opening = ProjectOpeningEntity(
        id: openingId,
        levelId: LevelId('level-1'),
        kind: OpeningKind.door,
        connectedSpaceIds: <SpaceId>[roomA, roomB],
        widthMm: 900,
        heightMm: 2100,
      );
      final openingResult = session.commit(
        ProjectMutationRequest(
          expectedVersion: session.current.version,
          command: CreateOpeningCommand(opening: opening),
        ),
      )!;
      expect(openingResult.changeSet.addedEntityIds, contains(openingId));
      expect(openingResult.project.index.openingsBySpaceId[roomA], <OpeningId>{
        openingId,
      });

      final adjacency = ProjectSpaceAdjacencyEntity(
        id: adjacencyId,
        spaceAId: roomA,
        spaceBId: roomB,
        kind: SpaceAdjacencyKind.opening,
        openingId: openingId,
      );
      final adjacencyResult = session.commit(
        ProjectMutationRequest(
          expectedVersion: session.current.version,
          command: CreateAdjacencyCommand(adjacency: adjacency),
        ),
      )!;
      expect(adjacencyResult.changeSet.addedEntityIds, contains(adjacencyId));
      expect(
        adjacencyResult.project.index.adjacenciesBySpaceId[roomB],
        <SpaceAdjacencyId>{adjacencyId},
      );

      final overlay = ProjectOverlayClassificationEntity(
        id: overlayId,
        name: 'FC-01',
        discipline: OverlayDiscipline.fireSafety,
        kind: OverlayClassificationKind.fireCompartment,
        spaceIds: <SpaceId>[roomA, roomB],
      );
      final overlayResult = session.commit(
        ProjectMutationRequest(
          expectedVersion: session.current.version,
          command: CreateOverlayClassificationCommand(overlay: overlay),
        ),
      )!;
      expect(overlayResult.changeSet.addedEntityIds, contains(overlayId));
      expect(
        overlayResult.project.index.overlaysBySpaceId[roomA],
        <OverlayClassificationId>{overlayId},
      );

      final undone = session.undo(session.current.version)!;
      expect(undone.project.index.overlay(overlayId), isNull);
      final redone = session.redo(session.current.version)!;
      expect(redone.project.index.overlay(overlayId), isNotNull);
    });

    test('symmetric duplicate adjacency is rejected fail closed', () {
      final roomA = SpaceId('room-a');
      final roomB = SpaceId('room-b');
      final session = ProjectMutationSession(_baseProject());

      session.commit(
        ProjectMutationRequest(
          expectedVersion: session.current.version,
          command: CreateAdjacencyCommand(
            adjacency: ProjectSpaceAdjacencyEntity(
              id: SpaceAdjacencyId('adj-1'),
              spaceAId: roomA,
              spaceBId: roomB,
              kind: SpaceAdjacencyKind.sharedBoundary,
            ),
          ),
        ),
      );
      final beforeRejected = session.current;

      expect(
        () => session.commit(
          ProjectMutationRequest(
            expectedVersion: session.current.version,
            command: CreateAdjacencyCommand(
              adjacency: ProjectSpaceAdjacencyEntity(
                id: SpaceAdjacencyId('adj-2'),
                spaceAId: roomB,
                spaceBId: roomA,
                kind: SpaceAdjacencyKind.sharedBoundary,
              ),
            ),
          ),
        ),
        throwsA(
          isA<ProjectCandidateValidationException>().having(
            (error) => error.issues.any(
              (issue) =>
                  issue.code ==
                  ProjectAggregateIssueCode.duplicateAdjacencyPair,
            ),
            'duplicate adjacency issue',
            isTrue,
          ),
        ),
      );
      expect(session.current, same(beforeRejected));
      expect(session.undoDepth, 1);
    });

    test('opening-backed adjacency must use the same two spaces', () {
      final roomA = SpaceId('room-a');
      final roomB = SpaceId('room-b');
      final roomC = SpaceId('room-c');
      final openingId = OpeningId('door-1');
      final session = ProjectMutationSession(
        _baseProject(withThirdSpace: true),
      );

      session.commit(
        ProjectMutationRequest(
          expectedVersion: session.current.version,
          command: CreateOpeningCommand(
            opening: ProjectOpeningEntity(
              id: openingId,
              levelId: LevelId('level-1'),
              kind: OpeningKind.door,
              connectedSpaceIds: <SpaceId>[roomA, roomB],
              widthMm: 900,
              heightMm: 2100,
            ),
          ),
        ),
      );

      expect(
        () => session.commit(
          ProjectMutationRequest(
            expectedVersion: session.current.version,
            command: CreateAdjacencyCommand(
              adjacency: ProjectSpaceAdjacencyEntity(
                id: SpaceAdjacencyId('adj-invalid'),
                spaceAId: roomA,
                spaceBId: roomC,
                kind: SpaceAdjacencyKind.opening,
                openingId: openingId,
              ),
            ),
          ),
        ),
        throwsA(
          isA<ProjectCandidateValidationException>().having(
            (error) => error.issues.any(
              (issue) =>
                  issue.code ==
                  ProjectAggregateIssueCode.adjacencyOpeningSpaceMismatch,
            ),
            'opening mismatch issue',
            isTrue,
          ),
        ),
      );
    });

    test('RemoveSpace reports all P6 blockers without cascade', () {
      final roomA = SpaceId('room-a');
      final roomB = SpaceId('room-b');
      final openingId = OpeningId('door-1');
      final adjacencyId = SpaceAdjacencyId('adj-1');
      final overlayId = OverlayClassificationId('fire-1');
      final project = _baseProject(
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
        adjacencies: <SpaceAdjacencyId, ProjectSpaceAdjacencyEntity>{
          adjacencyId: ProjectSpaceAdjacencyEntity(
            id: adjacencyId,
            spaceAId: roomA,
            spaceBId: roomB,
            kind: SpaceAdjacencyKind.opening,
            openingId: openingId,
          ),
        },
        overlays: <OverlayClassificationId, ProjectOverlayClassificationEntity>{
          overlayId: ProjectOverlayClassificationEntity(
            id: overlayId,
            name: 'FC-01',
            discipline: OverlayDiscipline.fireSafety,
            kind: OverlayClassificationKind.fireCompartment,
            spaceIds: <SpaceId>[roomA],
          ),
        },
      );
      final session = ProjectMutationSession(project);
      final before = session.current;

      expect(
        () => session.commit(
          ProjectMutationRequest(
            expectedVersion: session.current.version,
            command: RemoveSpaceCommand(spaceId: roomA),
          ),
        ),
        throwsA(
          isA<ProjectAuthoringException>()
              .having(
                (error) => error.code,
                'code',
                ProjectAuthoringIssueCode.spaceHasSemanticDependencies,
              )
              .having(
                (error) => error.blockingEntityIds,
                'blockingEntityIds',
                <EntityId>{openingId, adjacencyId, overlayId},
              ),
        ),
      );
      expect(session.current, same(before));
      expect(session.undoDepth, 0);
    });

    test('legacy rename preserves SpaceUsage and P6 semantic stores', () {
      final roomA = SpaceId('room-a');
      final openingId = OpeningId('window-1');
      final session = ProjectMutationSession(
        _baseProject(
          roomAUsage: SpaceUsage.bedroom,
          openings: <OpeningId, ProjectOpeningEntity>{
            openingId: ProjectOpeningEntity(
              id: openingId,
              levelId: LevelId('level-1'),
              kind: OpeningKind.window,
              connectedSpaceIds: <SpaceId>[roomA],
              widthMm: 1200,
              heightMm: 1400,
              baseElevationMm: 900,
            ),
          },
        ),
      );

      final result = session.commit(
        ProjectMutationRequest(
          expectedVersion: session.current.version,
          command: RenameSpaceCommand(spaceId: roomA, name: 'Master Bedroom'),
        ),
      )!;

      expect(result.project.index.space(roomA)!.usage, SpaceUsage.bedroom);
      expect(result.project.index.opening(openingId), isNotNull);
    });
  });
}

ProjectAggregateRoot _baseProject({
  bool withThirdSpace = false,
  SpaceUsage roomAUsage = SpaceUsage.unknown,
  Map<OpeningId, ProjectOpeningEntity> openings = const {},
  Map<SpaceAdjacencyId, ProjectSpaceAdjacencyEntity> adjacencies = const {},
  Map<OverlayClassificationId, ProjectOverlayClassificationEntity> overlays =
      const {},
}) {
  final siteId = SiteId('site-1');
  final buildingId = BuildingId('building-1');
  final levelId = LevelId('level-1');
  final roomA = SpaceId('room-a');
  final roomB = SpaceId('room-b');
  final roomC = SpaceId('room-c');
  final spaceIds = <SpaceId>[roomA, roomB, if (withThirdSpace) roomC];

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
          name: 'Floor 1',
          levelNumber: 1,
          elevationMm: 0,
          spaceIds: spaceIds,
        ),
      },
      spaces: <SpaceId, ProjectSpaceEntity>{
        roomA: ProjectSpaceEntity(
          id: roomA,
          levelId: levelId,
          name: 'Room A',
          usage: roomAUsage,
        ),
        roomB: ProjectSpaceEntity(id: roomB, levelId: levelId, name: 'Room B'),
        if (withThirdSpace)
          roomC: ProjectSpaceEntity(
            id: roomC,
            levelId: levelId,
            name: 'Room C',
          ),
      },
      openings: openings,
      adjacencies: adjacencies,
      overlays: overlays,
    ),
  );
}
