import 'dart:convert';

import 'package:elecx/src/application/project/project_snapshot.dart';
import 'package:elecx/src/domain/boundary_edge_identity_registry.dart';
import 'package:elecx/src/domain/boundary_geometry_integrity.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_orientation.dart';
import 'package:elecx/src/serialization/project/canonical_project_document_codec.dart';
import 'package:elecx/src/serialization/project/legacy_boundary_polygon_migration.dart';
import 'package:elecx/src/serialization/project/project_document_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P7A-3 boundary persistence foundation', () {
    test('legacy polygon migration is deterministic and validates topology',
        () {
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
        BoundaryGeometryIntegrity.validate(first.topology),
        isEmpty,
      );
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

    test('same legacy polygon in another project gets different identities',
        () {
      final a = LegacyBoundaryPolygonMigration.migrate(
        projectId: ProjectId('project-a'),
        spaceId: SpaceId('space-a'),
        polygon: _rectangle,
      );
      final b = LegacyBoundaryPolygonMigration.migrate(
        projectId: ProjectId('project-b'),
        spaceId: SpaceId('space-a'),
        polygon: _rectangle,
      );

      expect(
        a.topology.orderedEdgeIds.toSet().intersection(
              b.topology.orderedEdgeIds.toSet(),
            ),
        isEmpty,
      );
    });

    test('length-prefixed migration seed is unambiguous for delimiter ids', () {
      final left = LegacyBoundaryPolygonMigration.migrate(
        projectId: ProjectId('project|a'),
        spaceId: SpaceId('space'),
        polygon: _rectangle,
      );
      final right = LegacyBoundaryPolygonMigration.migrate(
        projectId: ProjectId('project'),
        spaceId: SpaceId('a|space'),
        polygon: _rectangle,
      );

      expect(
        left.topology.orderedEdgeIds.toSet().intersection(
              right.topology.orderedEdgeIds.toSet(),
            ),
        isEmpty,
      );
    });

    test('legacy migration rejects self-intersecting polygon fail closed', () {
      expect(
        () => LegacyBoundaryPolygonMigration.migrate(
          projectId: ProjectId('project-a'),
          spaceId: SpaceId('space-a'),
          polygon: _bowTie,
        ),
        throwsA(
          isA<BoundaryGeometryIntegrityException>().having(
            (error) => error.issues.map((issue) => issue.code),
            'issue codes',
            contains(BoundaryGeometryIssueCode.selfIntersection),
          ),
        ),
      );
    });

    test('legacy migration rejects zero-area polygon fail closed', () {
      expect(
        () => LegacyBoundaryPolygonMigration.migrate(
          projectId: ProjectId('project-a'),
          spaceId: SpaceId('space-a'),
          polygon: _collinearTriangle,
        ),
        throwsA(
          isA<BoundaryGeometryIntegrityException>().having(
            (error) => error.issues.map((issue) => issue.code),
            'issue codes',
            contains(BoundaryGeometryIssueCode.degenerateArea),
          ),
        ),
      );
    });

    test('schema v4 round-trip preserves boundary ids and tombstones', () {
      final fixture = _BoundarySnapshotFixture.valid();
      const codec = CanonicalProjectDocumentCodec();

      final encoded = codec.encode(fixture.snapshot);
      final restored = codec.decode(encoded);
      final reencoded = codec.encode(restored);

      expect(encoded.schemaVersion, 4);
      expect(
        restored.aggregate.index.boundary(fixture.spaceId)?.orderedEdgeIds,
        fixture.migrated.topology.orderedEdgeIds,
      );
      expect(
        restored.aggregate.engineeringMetadata.boundaryEdgeIdentityRegistry
            .ownerOf(fixture.retiredEdgeId),
        fixture.spaceId,
      );
      expect(reencoded.payload, encoded.payload);
    });

    test('persistence snapshot rejects active edge missing from durable ledger',
        () {
      final fixture = _BoundarySnapshotFixture.valid();
      final aggregate = ProjectAggregateRoot(
        id: fixture.projectId,
        siteId: fixture.siteId,
        version: LocalProjectVersion(7),
        stores: fixture.stores,
      );

      expect(
        () => ProjectSnapshot(
          aggregate: aggregate,
          name: 'Invalid missing registry',
          createdAt: DateTime.utc(2026, 10, 22, 8),
          updatedAt: DateTime.utc(2026, 10, 22, 9),
        ),
        throwsA(isA<BoundaryEdgeIdentityMissingException>()),
      );
    });

    test('persistence snapshot rejects historical owner mismatch', () {
      final fixture = _BoundarySnapshotFixture.valid();
      final firstEdgeId = fixture.migrated.topology.orderedEdgeIds.first;
      final mismatchedRegistry = BoundaryEdgeIdentityRegistry({
        ...fixture.migrated.identityRegistry.owners,
        fixture.retiredEdgeId: fixture.spaceId,
        firstEdgeId: SpaceId('foreign-space'),
      });
      final aggregate = ProjectAggregateRoot(
        id: fixture.projectId,
        siteId: fixture.siteId,
        version: LocalProjectVersion(7),
        engineeringMetadata: ProjectEngineeringMetadata(
          boundaryEdgeIdentityRegistry: mismatchedRegistry,
        ),
        stores: fixture.stores,
      );

      expect(
        () => ProjectSnapshot(
          aggregate: aggregate,
          name: 'Invalid registry owner',
          createdAt: DateTime.utc(2026, 10, 22, 8),
          updatedAt: DateTime.utc(2026, 10, 22, 9),
        ),
        throwsA(isA<BoundaryEdgeIdentityOwnershipException>()),
      );
    });

    test('codec rejects self-intersecting schema v4 geometry as format error',
        () {
      final fixture = _BoundarySnapshotFixture.valid();
      const codec = CanonicalProjectDocumentCodec();
      final document = codec.encode(fixture.snapshot);
      final payload =
          jsonDecode(jsonEncode(document.payload)) as Map<String, dynamic>;
      final boundary = (payload['boundaries'] as List<dynamic>).single
          as Map<String, dynamic>;
      final edges = boundary['edges'] as List<dynamic>;
      for (var index = 0; index < edges.length; index++) {
        final edge = edges[index] as Map<String, dynamic>;
        final start = _bowTie[index];
        final end = _bowTie[(index + 1) % _bowTie.length];
        edge['start'] = <String, Object?>{'xMm': start.xMm, 'yMm': start.yMm};
        edge['end'] = <String, Object?>{'xMm': end.xMm, 'yMm': end.yMm};
      }

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

const _bowTie = <BoundaryPointMm>[
  BoundaryPointMm(xMm: 0, yMm: 0),
  BoundaryPointMm(xMm: 3000, yMm: 3000),
  BoundaryPointMm(xMm: 0, yMm: 3000),
  BoundaryPointMm(xMm: 3000, yMm: 0),
];

const _collinearTriangle = <BoundaryPointMm>[
  BoundaryPointMm(xMm: 0, yMm: 0),
  BoundaryPointMm(xMm: 1000, yMm: 0),
  BoundaryPointMm(xMm: 2000, yMm: 0),
];

final class _BoundarySnapshotFixture {
  _BoundarySnapshotFixture._({
    required this.projectId,
    required this.siteId,
    required this.spaceId,
    required this.retiredEdgeId,
    required this.migrated,
    required this.stores,
    required this.snapshot,
  });

  factory _BoundarySnapshotFixture.valid() {
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
    );
    final aggregate = ProjectAggregateRoot(
      id: projectId,
      siteId: siteId,
      version: LocalProjectVersion(7),
      engineeringMetadata: ProjectEngineeringMetadata(
        boundaryEdgeIdentityRegistry: registry,
      ),
      stores: stores,
    );
    final snapshot = ProjectSnapshot(
      aggregate: aggregate,
      name: 'Boundary persistence',
      createdAt: DateTime.utc(2026, 10, 22, 8),
      updatedAt: DateTime.utc(2026, 10, 22, 9),
    );

    return _BoundarySnapshotFixture._(
      projectId: projectId,
      siteId: siteId,
      spaceId: spaceId,
      retiredEdgeId: retiredEdgeId,
      migrated: migrated,
      stores: stores,
      snapshot: snapshot,
    );
  }

  final ProjectId projectId;
  final SiteId siteId;
  final SpaceId spaceId;
  final BoundaryEdgeId retiredEdgeId;
  final LegacyBoundaryMigrationResult migrated;
  final ProjectEntityStores stores;
  final ProjectSnapshot snapshot;
}

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
