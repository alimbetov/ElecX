import 'package:elecx/src/application/project/project_snapshot.dart';
import 'package:elecx/src/domain/boundary_construction_registry.dart';
import 'package:elecx/src/domain/boundary_edge_identity_registry.dart';
import 'package:elecx/src/domain/boundary_host_migration.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_orientation.dart';
import 'package:elecx/src/serialization/project/canonical_project_document_codec.dart';
import 'package:elecx/src/serialization/project/project_document_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('boundary construction persistence', () {
    test('canonical schema v8 round-trip preserves wall construction data', () {
      final fixture = _fixture();
      const codec = CanonicalProjectDocumentCodec();

      final encoded = codec.encode(fixture.snapshot);
      final restored = codec.decode(encoded);
      final profile = restored.aggregate.engineeringMetadata
          .boundaryConstructionRegistry[fixture.constructionHost];

      expect(encoded.schemaVersion, 8);
      expect(profile, isNotNull);
      expect(profile!.kind, BoundaryConstructionKind.wall);
      expect(profile.thicknessMm, 180);
      expect(profile.materialId, 'brick');
      expect(profile.fireRatingId, 'EI60');
      expect(codec.encode(restored).payload, encoded.payload);
    });

    test('canonical schema v6 migrates to empty construction registry', () {
      final fixture = _fixture();
      const codec = CanonicalProjectDocumentCodec();
      final current = codec.encode(fixture.snapshot);
      final legacyPayload = Map<String, Object?>.from(current.payload)
        ..remove('boundaryConstructionRegistry');

      final restored = codec.decode(
        ProjectDocument(schemaVersion: 6, payload: legacyPayload),
      );

      expect(
        restored.aggregate.engineeringMetadata.boundaryConstructionRegistry
            .profiles,
        isEmpty,
      );
    });

    test('aggregate rejects construction profile hosted by inactive edge', () {
      final fixture = _fixture();
      final invalidRegistry = BoundaryConstructionRegistry({
        BoundaryEdgeHostRef(
          spaceId: fixture.spaceId,
          edgeId: BoundaryEdgeId('retired-edge'),
        ): BoundaryConstructionProfile(
          kind: BoundaryConstructionKind.wall,
          thicknessMm: 100,
          materialId: 'partition',
        ),
      });

      expect(
        () => ProjectAggregateRoot(
          id: fixture.projectId,
          siteId: fixture.siteId,
          version: LocalProjectVersion(1),
          engineeringMetadata: fixture.snapshot.aggregate.engineeringMetadata
              .copyWith(boundaryConstructionRegistry: invalidRegistry),
          stores: fixture.snapshot.aggregate.stores,
        ),
        throwsA(isA<BoundaryConstructionRegistryException>()),
      );
    });
  });
}

_ConstructionFixture _fixture() {
  final projectId = ProjectId('project-1');
  final siteId = SiteId('site-1');
  final buildingId = BuildingId('building-1');
  final levelId = LevelId('level-1');
  final spaceId = SpaceId('space-1');
  final edgeIds = [
    BoundaryEdgeId('edge-0'),
    BoundaryEdgeId('edge-1'),
    BoundaryEdgeId('edge-2'),
    BoundaryEdgeId('edge-3'),
  ];
  final points = const [
    BoundaryPointMm(xMm: 0, yMm: 0),
    BoundaryPointMm(xMm: 4000, yMm: 0),
    BoundaryPointMm(xMm: 4000, yMm: 3000),
    BoundaryPointMm(xMm: 0, yMm: 3000),
  ];
  final edges = <BoundaryEdgeId, ProjectBoundaryEdge>{};
  for (var index = 0; index < edgeIds.length; index++) {
    edges[edgeIds[index]] = ProjectBoundaryEdge(
      id: edgeIds[index],
      spaceId: spaceId,
      start: points[index],
      end: points[(index + 1) % points.length],
    );
  }
  final topology = SpaceBoundaryTopology(
    spaceId: spaceId,
    orderedEdgeIds: edgeIds,
    edges: edges,
  );
  final stores = ProjectEntityStores(
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
        name: 'Level 1',
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
    boundaries: {spaceId: topology},
  );
  final identityRegistry = BoundaryEdgeIdentityRegistry({
    for (final edgeId in edgeIds) edgeId: spaceId,
  });
  final constructionHost = BoundaryEdgeHostRef(
    spaceId: spaceId,
    edgeId: edgeIds.first,
  );
  final constructionRegistry = BoundaryConstructionRegistry({
    constructionHost: BoundaryConstructionProfile(
      kind: BoundaryConstructionKind.wall,
      thicknessMm: 180,
      materialId: 'brick',
      fireRatingId: 'EI60',
    ),
  });
  final aggregate = ProjectAggregateRoot(
    id: projectId,
    siteId: siteId,
    version: LocalProjectVersion(1),
    engineeringMetadata: ProjectEngineeringMetadata(
      boundaryEdgeIdentityRegistry: identityRegistry,
      boundaryConstructionRegistry: constructionRegistry,
    ),
    stores: stores,
  );
  final snapshot = ProjectSnapshot(
    aggregate: aggregate,
    name: 'Construction persistence',
    createdAt: DateTime.utc(2026, 10, 23, 1),
    updatedAt: DateTime.utc(2026, 10, 23, 2),
  );
  return _ConstructionFixture(
    projectId: projectId,
    siteId: siteId,
    spaceId: spaceId,
    constructionHost: constructionHost,
    snapshot: snapshot,
  );
}

final class _ConstructionFixture {
  const _ConstructionFixture({
    required this.projectId,
    required this.siteId,
    required this.spaceId,
    required this.constructionHost,
    required this.snapshot,
  });

  final ProjectId projectId;
  final SiteId siteId;
  final SpaceId spaceId;
  final BoundaryEdgeHostRef constructionHost;
  final ProjectSnapshot snapshot;
}
