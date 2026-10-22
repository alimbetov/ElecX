import 'dart:convert';

import 'package:elecx/src/application/project/project_snapshot.dart';
import 'package:elecx/src/domain/boundary_edge_identity_registry.dart';
import 'package:elecx/src/domain/boundary_host_migration.dart';
import 'package:elecx/src/domain/boundary_host_registry.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/boundary_wall_profile_registry.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_space_semantics.dart';
import 'package:elecx/src/domain/wall_profile.dart';
import 'package:elecx/src/serialization/project/canonical_project_document_codec.dart';
import 'package:elecx/src/serialization/project/project_document_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('schema v6 reopen rejects orphan hosted opening fail closed', () {
    final fixture = _Fixture();
    const codec = CanonicalProjectDocumentCodec();
    final encoded = codec.encode(fixture.snapshot());
    final payload =
        jsonDecode(jsonEncode(encoded.payload)) as Map<String, dynamic>;

    payload['openings'] = <Object?>[];

    expect(
      () => codec.decode(
        ProjectDocument(
          schemaVersion: encoded.schemaVersion,
          payload: payload.cast<String, Object?>(),
        ),
      ),
      throwsFormatException,
    );
  });
}

final class _Fixture {
  final projectId = ProjectId('project-p7a5-persistence');
  final siteId = SiteId('site');
  final buildingId = BuildingId('building');
  final levelId = LevelId('level');
  final spaceId = SpaceId('space');
  final openingId = OpeningId('opening');
  final edgeIds = <BoundaryEdgeId>[
    BoundaryEdgeId('bottom'),
    BoundaryEdgeId('right'),
    BoundaryEdgeId('top'),
    BoundaryEdgeId('left'),
  ];

  late final SpaceBoundaryTopology topology = SpaceBoundaryTopology(
    spaceId: spaceId,
    orderedEdgeIds: edgeIds,
    edges: {
      edgeIds[0]: ProjectBoundaryEdge(
        id: edgeIds[0],
        spaceId: spaceId,
        start: const BoundaryPointMm(xMm: 0, yMm: 0),
        end: const BoundaryPointMm(xMm: 4000, yMm: 0),
      ),
      edgeIds[1]: ProjectBoundaryEdge(
        id: edgeIds[1],
        spaceId: spaceId,
        start: const BoundaryPointMm(xMm: 4000, yMm: 0),
        end: const BoundaryPointMm(xMm: 4000, yMm: 3000),
      ),
      edgeIds[2]: ProjectBoundaryEdge(
        id: edgeIds[2],
        spaceId: spaceId,
        start: const BoundaryPointMm(xMm: 4000, yMm: 3000),
        end: const BoundaryPointMm(xMm: 0, yMm: 3000),
      ),
      edgeIds[3]: ProjectBoundaryEdge(
        id: edgeIds[3],
        spaceId: spaceId,
        start: const BoundaryPointMm(xMm: 0, yMm: 3000),
        end: const BoundaryPointMm(xMm: 0, yMm: 0),
      ),
    },
  );

  ProjectSnapshot snapshot() {
    final openingKey =
        BoundaryHostedObjectRegistry.openingObjectKey(openingId, spaceId);
    final boundaries = {spaceId: topology};
    final identity = const BoundaryEdgeIdentityRegistry.empty()
        .registerActiveBoundaries(boundaries);
    final hosts = BoundaryHostedObjectRegistry({
      openingKey: BoundaryHostedReference.interval(
        objectKey: openingKey,
        objectKind: BoundaryHostedObjectKind.opening,
        host: BoundaryEdgeHostRef(spaceId: spaceId, edgeId: edgeIds.first),
        startOffsetMm: 1000,
        endOffsetMm: 1800,
      ),
    });
    final profiles = BoundaryWallProfileRegistry({
      BoundaryEdgeHostRef(spaceId: spaceId, edgeId: edgeIds.first):
          WallProfile.rectangle(widthMm: 4000, heightMm: 3000),
    });
    final aggregate = ProjectAggregateRoot(
      id: projectId,
      siteId: siteId,
      version: LocalProjectVersion(1),
      engineeringMetadata: ProjectEngineeringMetadata(
        boundaryEdgeIdentityRegistry: identity,
        boundaryHostedObjectRegistry: hosts,
        boundaryWallProfileRegistry: profiles,
      ),
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
            levelIds: [levelId],
          ),
        },
        levels: {
          levelId: ProjectLevelEntity(
            id: levelId,
            buildingId: buildingId,
            name: 'Level',
            levelNumber: 1,
            elevationMm: 0,
            spaceIds: [spaceId],
          ),
        },
        spaces: {
          spaceId: ProjectSpaceEntity(
            id: spaceId,
            levelId: levelId,
            name: 'Room',
          ),
        },
        openings: {
          openingId: ProjectOpeningEntity(
            id: openingId,
            levelId: levelId,
            kind: OpeningKind.door,
            connectedSpaceIds: [spaceId],
            widthMm: 800,
            heightMm: 2100,
          ),
        },
        boundaries: boundaries,
      ),
    );
    return ProjectSnapshot(
      aggregate: aggregate,
      name: 'P7A-5 persistence',
      createdAt: DateTime.utc(2026, 10, 22, 10),
      updatedAt: DateTime.utc(2026, 10, 22, 11),
    );
  }
}
