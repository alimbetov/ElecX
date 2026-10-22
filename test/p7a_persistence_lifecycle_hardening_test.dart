import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_snapshot.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/serialization/project/canonical_project_document_codec.dart';
import 'package:elecx/src/serialization/project/legacy_boundary_polygon_migration.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'BoundaryEdgeId owner survives commit undo save reopen and blocks re-parent',
    () {
      final fixture = _LifecycleFixture();
      final initial = fixture.initialProject();
      final migrated = LegacyBoundaryPolygonMigration.migrate(
        projectId: fixture.projectId,
        spaceId: fixture.spaceA,
        polygon: _rectangle,
      );
      final session = ProjectMutationSession(initial);

      final created = session.commit(
        ProjectMutationRequest(
          expectedVersion: initial.version,
          command: _SetBoundariesCommand({
            fixture.spaceA: migrated.topology,
          }),
        ),
      );
      expect(created, isNotNull);
      final issuedEdgeId = migrated.topology.orderedEdgeIds.first;
      expect(
        created!.project.engineeringMetadata.boundaryEdgeIdentityRegistry
            .ownerOf(issuedEdgeId),
        fixture.spaceA,
      );

      final undone = session.undo(created.project.version);
      expect(undone, isNotNull);
      expect(undone!.project.stores.boundaries, isEmpty);
      expect(
        undone.project.engineeringMetadata.boundaryEdgeIdentityRegistry
            .ownerOf(issuedEdgeId),
        fixture.spaceA,
        reason: 'undo must retire topology without deleting the identity owner',
      );

      final snapshot = ProjectSnapshot(
        aggregate: undone.project,
        name: 'Lifecycle H1',
        createdAt: DateTime.utc(2026, 10, 22, 9),
        updatedAt: DateTime.utc(2026, 10, 22, 10),
      );
      const codec = CanonicalProjectDocumentCodec();
      final reopened = codec.decode(codec.encode(snapshot));
      expect(
        reopened.aggregate.engineeringMetadata.boundaryEdgeIdentityRegistry
            .ownerOf(issuedEdgeId),
        fixture.spaceA,
      );

      final foreign = _reownerTopology(
        migrated.topology,
        fixture.spaceB,
      );
      final reopenedSession = ProjectMutationSession(reopened.aggregate);
      expect(
        () => reopenedSession.commit(
          ProjectMutationRequest(
            expectedVersion: reopened.localVersion,
            command: _SetBoundariesCommand({fixture.spaceB: foreign}),
          ),
        ),
        throwsA(
          isA<BoundaryEdgeOwnershipException>()
              .having((error) => error.edgeId, 'edgeId', issuedEdgeId)
              .having(
                (error) => error.expectedSpaceId,
                'expectedSpaceId',
                fixture.spaceA,
              )
              .having(
                (error) => error.actualSpaceId,
                'actualSpaceId',
                fixture.spaceB,
              ),
        ),
      );
      expect(reopenedSession.current.version, reopened.localVersion);
      expect(reopenedSession.current.stores.boundaries, isEmpty);
    },
  );
}

const _rectangle = <BoundaryPointMm>[
  BoundaryPointMm(xMm: 0, yMm: 0),
  BoundaryPointMm(xMm: 4000, yMm: 0),
  BoundaryPointMm(xMm: 4000, yMm: 3000),
  BoundaryPointMm(xMm: 0, yMm: 3000),
];

final class _SetBoundariesCommand implements ProjectCommand {
  const _SetBoundariesCommand(this.boundaries);

  final Map<SpaceId, SpaceBoundaryTopology> boundaries;

  @override
  String get commandType => 'p7aLifecycleSetBoundaries';

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) =>
      ProjectCommandCandidate.fromState(
        state: ProjectMutableState(
          engineeringMetadata: current.engineeringMetadata,
          stores: ProjectEntityStores(
            sites: current.stores.sites,
            buildings: current.stores.buildings,
            levels: current.stores.levels,
            zones: current.stores.zones,
            spaces: current.stores.spaces,
            openings: current.stores.openings,
            adjacencies: current.stores.adjacencies,
            overlays: current.stores.overlays,
            boundaries: boundaries,
          ),
        ),
      );
}

SpaceBoundaryTopology _reownerTopology(
  SpaceBoundaryTopology source,
  SpaceId owner,
) {
  final edges = <BoundaryEdgeId, ProjectBoundaryEdge>{};
  for (final edgeId in source.orderedEdgeIds) {
    final edge = source.edges[edgeId]!;
    edges[edgeId] = ProjectBoundaryEdge(
      id: edgeId,
      spaceId: owner,
      start: edge.start,
      end: edge.end,
    );
  }
  return SpaceBoundaryTopology(
    spaceId: owner,
    orderedEdgeIds: source.orderedEdgeIds,
    edges: edges,
  );
}

final class _LifecycleFixture {
  final projectId = ProjectId('project-lifecycle');
  final siteId = SiteId('site-lifecycle');
  final buildingId = BuildingId('building-lifecycle');
  final levelId = LevelId('level-lifecycle');
  final spaceA = SpaceId('space-a');
  final spaceB = SpaceId('space-b');

  ProjectAggregateRoot initialProject() => ProjectAggregateRoot(
        id: projectId,
        siteId: siteId,
        version: LocalProjectVersion(0),
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
              spaceIds: [spaceA, spaceB],
            ),
          },
          spaces: {
            spaceA: ProjectSpaceEntity(
              id: spaceA,
              levelId: levelId,
              name: 'Room A',
            ),
            spaceB: ProjectSpaceEntity(
              id: spaceB,
              levelId: levelId,
              name: 'Room B',
            ),
          },
        ),
      );
}
