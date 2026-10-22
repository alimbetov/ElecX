import 'dart:convert';

import 'package:elecx/src/application/project/project_snapshot.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_space_semantics.dart';
import 'package:elecx/src/serialization/project/canonical_project_document_codec.dart';
import 'package:elecx/src/serialization/project/project_document_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P6 canonical persistence', () {
    const codec = CanonicalProjectDocumentCodec();

    test('round-trips SpaceUsage, openings, adjacency and overlays', () {
      final source = _snapshot();
      final document = codec.encode(source);
      final restored = codec.decode(document);
      final stores = restored.aggregate.stores;

      expect(document.schemaVersion, 3);
      expect(stores.spaces[SpaceId('room-a')]!.usage, SpaceUsage.bedroom);
      expect(stores.spaces[SpaceId('room-b')]!.usage, SpaceUsage.corridor);

      final opening = stores.openings[OpeningId('door-1')]!;
      expect(opening.kind, OpeningKind.door);
      expect(
        opening.connectedSpaceIds,
        <SpaceId>{SpaceId('room-a'), SpaceId('room-b')},
      );
      expect(opening.widthMm, 900);
      expect(opening.heightMm, 2100);

      final adjacency = stores.adjacencies[SpaceAdjacencyId('adj-1')]!;
      expect(adjacency.kind, SpaceAdjacencyKind.opening);
      expect(adjacency.openingId, OpeningId('door-1'));

      final overlay =
          stores.overlays[OverlayClassificationId('fire-compartment-1')]!;
      expect(overlay.discipline, OverlayDiscipline.fireSafety);
      expect(overlay.kind, OverlayClassificationKind.fireCompartment);
      expect(
        overlay.spaceIds,
        <SpaceId>{SpaceId('room-a'), SpaceId('room-b')},
      );

      expect(
        jsonEncode(codec.encode(restored).payload),
        jsonEncode(document.payload),
      );
    });

    test('canonical P6 payload contains no durable wallIndex contract', () {
      final encoded = jsonEncode(codec.encode(_snapshot()).payload);

      expect(encoded, isNot(contains('wallIndex')));
      expect(encoded, isNot(contains('boundaryEdgeId')));
      expect(encoded, contains('"door-1"'));
    });

    test('unknown persisted semantic enum values fail closed', () {
      final document = codec.encode(_snapshot());
      final payload =
          jsonDecode(jsonEncode(document.payload)) as Map<String, dynamic>;
      final spaces = payload['spaces']! as List<dynamic>;
      (spaces.first as Map<String, dynamic>)['usage'] = 'translatedBedroom';

      expect(
        () => codec.decode(
          ProjectDocument(
            schemaVersion: document.schemaVersion,
            payload: payload.cast<String, Object?>(),
          ),
        ),
        throwsFormatException,
      );
    });
  });
}

ProjectSnapshot _snapshot() {
  final siteId = SiteId('site-1');
  final buildingId = BuildingId('building-1');
  final levelId = LevelId('level-1');
  final roomA = SpaceId('room-a');
  final roomB = SpaceId('room-b');
  final openingId = OpeningId('door-1');
  final adjacencyId = SpaceAdjacencyId('adj-1');
  final overlayId = OverlayClassificationId('fire-compartment-1');

  final aggregate = ProjectAggregateRoot(
    id: ProjectId('project-1'),
    siteId: siteId,
    version: LocalProjectVersion(4),
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
          spaceIds: <SpaceId>[roomA, roomB],
        ),
      },
      spaces: <SpaceId, ProjectSpaceEntity>{
        roomA: ProjectSpaceEntity(
          id: roomA,
          levelId: levelId,
          name: 'Bedroom',
          usage: SpaceUsage.bedroom,
        ),
        roomB: ProjectSpaceEntity(
          id: roomB,
          levelId: levelId,
          name: 'Corridor',
          usage: SpaceUsage.corridor,
        ),
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
      adjacencies: <SpaceAdjacencyId, ProjectSpaceAdjacencyEntity>{
        adjacencyId: ProjectSpaceAdjacencyEntity(
          id: adjacencyId,
          spaceAId: roomA,
          spaceBId: roomB,
          kind: SpaceAdjacencyKind.opening,
          openingId: openingId,
        ),
      },
      overlays:
          <OverlayClassificationId, ProjectOverlayClassificationEntity>{
        overlayId: ProjectOverlayClassificationEntity(
          id: overlayId,
          name: 'FC-01',
          discipline: OverlayDiscipline.fireSafety,
          kind: OverlayClassificationKind.fireCompartment,
          spaceIds: <SpaceId>[roomA, roomB],
        ),
      },
    ),
  );

  return ProjectSnapshot(
    aggregate: aggregate,
    name: 'P6 semantic project',
    createdAt: DateTime.utc(2026, 10, 22, 1),
    updatedAt: DateTime.utc(2026, 10, 22, 2),
  );
}
