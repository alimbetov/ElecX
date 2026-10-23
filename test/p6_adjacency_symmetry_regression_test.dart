import 'dart:convert';

import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_snapshot.dart';
import 'package:elecx/src/application/project/project_space_semantics_commands.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_space_semantics.dart';
import 'package:elecx/src/serialization/project/canonical_project_document_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P6 symmetric adjacency canonicalization', () {
    test('constructor normalizes the unordered Space pair', () {
      final adjacency = ProjectSpaceAdjacencyEntity(
        id: SpaceAdjacencyId('adj-1'),
        spaceAId: SpaceId('room-z'),
        spaceBId: SpaceId('room-a'),
        kind: SpaceAdjacencyKind.sharedBoundary,
      );

      expect(adjacency.spaceAId, SpaceId('room-a'));
      expect(adjacency.spaceBId, SpaceId('room-z'));
    });

    test('reversing the same adjacency endpoints is a semantic no-op', () {
      final session = ProjectMutationSession(_project());
      final before = session.current;
      final beforeUndoDepth = session.undoDepth;

      final result = session.commit(
        ProjectMutationRequest(
          expectedVersion: session.current.version,
          command: UpdateAdjacencyCommand(
            adjacency: ProjectSpaceAdjacencyEntity(
              id: SpaceAdjacencyId('adj-1'),
              spaceAId: SpaceId('room-b'),
              spaceBId: SpaceId('room-a'),
              kind: SpaceAdjacencyKind.sharedBoundary,
            ),
          ),
        ),
      );

      expect(result, isNull);
      expect(session.current, same(before));
      expect(session.current.version, LocalProjectVersion(0));
      expect(session.undoDepth, beforeUndoDepth);
    });

    test('canonical serialization is independent from input endpoint order',
        () {
      const codec = CanonicalProjectDocumentCodec();
      final forward = codec.encode(_snapshot(reverseInput: false));
      final reverse = codec.encode(_snapshot(reverseInput: true));

      expect(jsonEncode(reverse.payload), jsonEncode(forward.payload));
    });
  });
}

ProjectAggregateRoot _project({bool reverseInput = false}) {
  final siteId = SiteId('site-1');
  final buildingId = BuildingId('building-1');
  final levelId = LevelId('level-1');
  final roomA = SpaceId('room-a');
  final roomB = SpaceId('room-b');
  final adjacencyId = SpaceAdjacencyId('adj-1');

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
          spaceIds: <SpaceId>[roomA, roomB],
        ),
      },
      spaces: <SpaceId, ProjectSpaceEntity>{
        roomA: ProjectSpaceEntity(id: roomA, levelId: levelId, name: 'Room A'),
        roomB: ProjectSpaceEntity(id: roomB, levelId: levelId, name: 'Room B'),
      },
      adjacencies: <SpaceAdjacencyId, ProjectSpaceAdjacencyEntity>{
        adjacencyId: ProjectSpaceAdjacencyEntity(
          id: adjacencyId,
          spaceAId: reverseInput ? roomB : roomA,
          spaceBId: reverseInput ? roomA : roomB,
          kind: SpaceAdjacencyKind.sharedBoundary,
        ),
      },
    ),
  );
}

ProjectSnapshot _snapshot({required bool reverseInput}) => ProjectSnapshot(
      aggregate: _project(reverseInput: reverseInput),
      name: 'P6 adjacency symmetry',
      createdAt: DateTime.utc(2026, 10, 23, 10),
      updatedAt: DateTime.utc(2026, 10, 23, 10),
    );
