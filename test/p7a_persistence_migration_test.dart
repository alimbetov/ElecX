import 'package:elecx/src/application/project/project_snapshot.dart';
import 'package:elecx/src/domain/boundary_edge_identity_registry.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_orientation.dart';
import 'package:elecx/src/serialization/project/canonical_project_document_codec.dart';
import 'package:elecx/src/serialization/project/legacy_boundary_polygon_migration.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P7A-3 boundary persistence foundation', () {
    test('legacy polygon migration is deterministic and validates topology', () {
      final first = LegacyBoundaryPolygonMigration.migrate(
        projectId: ProjectId('project-a'),
        spaceId: SpaceId('space-a'),
        polygon: _rectangle,
      );
      final second = LegacyBoundaryPolygonMigration.migrate(
        projectId: ProjectId('project-a'),
        spaceId: SpaceId('space-a'),
        polygon: _rectangle,
      );

      expect(first.topology.validate(), isEmpty);
      expect(
        first.topology.orderedEdgeIds,
        second.topology.orderedEdgeIds,
      );
      for (final edgeId in first.topology.orderedEdgeIds) {
        expect(first.identityRegistry.ownerOf(edgeId), SpaceId('space-a'));
      }
    });

    test('explicit closing vertex does not change deterministic edge ids', () {
      final open = LegacyBoundaryPolygonMigration.migrate(
        projectId: ProjectId('project-a'),
        spaceId: SpaceId('space-a'),
        polygon: _rectangle,
      );
      final closed = LegacyBoundaryPolygonMigration.migrate(
        projectId: ProjectId('project-a'),
        spaceId: SpaceId('space-a'),
        polygon: [..._rectangle, _rectangle.first],
      );

      expect(closed.topology.orderedEdgeIds, open.topology.orderedEdgeIds);
    });

    test('same legacy polygon in another space gets different identities', () {
      final a = LegacyBoundaryPolygonMigration.migrate(
        projectId: ProjectId('project-a'),
        spaceId: SpaceId('space-a'),
        polygon: _rectangle,
      );
      final b = LegacyBoundaryPolygonMigration.migrate(
        projectId: ProjectId('project-a'),
        spaceId: SpaceId('space-b'),
        polygon: _rectangle,
      );

      expect(
        a.topology.orderedEdgeIds.toSet().intersection(
              b.topology.orderedEdgeIds.toSet(),
            ),
        isEmpty,
      );
    });

    test('schema v4 round-trip preserves boundary ids and tombstones', () {
      final projectId = ProjectId('project-a');
      final siteId = SiteId('site-a');
      final buildingId = BuildingId('building-a');
      final levelId = LevelId('level-a');
      final spaceId = SpaceId('space-a');
      final migrated = LegacyBoundaryPolygonMigration.migrate(
        projectId: projectId,
        spaceId: spaceId,
        polygon: _rectangle,
      );
      final retiredEdgeId = BoundaryEdgeId('retired-edge');
      final registry = BoundaryEdgeIdentityRegistry({
        ...migrated.identityRegistry.owners,
        retiredEdgeId: spaceId,
      });
      final aggregate = ProjectAggregateRoot(
        id: projectId,
        siteId: siteId,
        version: LocalProjectVersion(7),
        engineeringMetadata: ProjectEngineeringMetadata(
          boundaryEdgeIdentityRegistry: registry,
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
          boundaries: {spaceId: migrated.topology},
        ),
      );
      final snapshot = ProjectSnapshot(
        aggregate: aggregate,
        name: 'Boundary persistence',
        createdAt: DateTime.utc(2026, 10, 22, 8),
        updatedAt: DateTime.utc(2026, 10, 22, 9),
      );
      const codec = CanonicalProjectDocumentCodec();

      final encoded = codec.encode(snapshot);
      final restored = codec.decode(encoded);
      final reencoded = codec.encode(restored);

      expect(encoded.schemaVersion, 4);
      expect(
        restored.aggregate.index.boundary(spaceId)?.orderedEdgeIds,
        migrated.topology.orderedEdgeIds,
      );
      expect(
        restored.aggregate.engineeringMetadata.boundaryEdgeIdentityRegistry
            .ownerOf(retiredEdgeId),
        spaceId,
      );
      expect(reencoded.payload, encoded.payload);
    });

    test('registry rejects edge re-parent after tombstone restoration', () {
      final edgeId = BoundaryEdgeId('edge-stable');
      final registry = BoundaryEdgeIdentityRegistry({
        edgeId: SpaceId('space-a'),
      });
      final foreignTopology = _triangleTopology(
        SpaceId('space-b'),
        edgeId,
      );

      expect(
        () => registry.registerActiveBoundaries({
          SpaceId('space-b'): foreignTopology,
        }),
        throwsA(isA<BoundaryEdgeIdentityOwnershipException>()),
      );
    });
  });
}

const _rectangle = <BoundaryPointMm>[
  BoundaryPointMm(xMm: 0, yMm: 0),
  BoundaryPointMm(xMm: 4000, yMm: 0),
  BoundaryPointMm(xMm: 4000, yMm: 3000),
  BoundaryPointMm(xMm: 0, yMm: 3000),
];

SpaceBoundaryTopology _triangleTopology(
  SpaceId spaceId,
  BoundaryEdgeId firstId,
) {
  const a = BoundaryPointMm(xMm: 0, yMm: 0);
  const b = BoundaryPointMm(xMm: 1000, yMm: 0);
  const c = BoundaryPointMm(xMm: 0, yMm: 1000);
  final secondId = BoundaryEdgeId('edge-b');
  final thirdId = BoundaryEdgeId('edge-c');
  return SpaceBoundaryTopology(
    spaceId: spaceId,
    orderedEdgeIds: [firstId, secondId, thirdId],
    edges: {
      firstId: ProjectBoundaryEdge(
        id: firstId,
        spaceId: spaceId,
        start: a,
        end: b,
      ),
      secondId: ProjectBoundaryEdge(
        id: secondId,
        spaceId: spaceId,
        start: b,
        end: c,
      ),
      thirdId: ProjectBoundaryEdge(
        id: thirdId,
        spaceId: spaceId,
        start: c,
        end: a,
      ),
    },
  );
}
