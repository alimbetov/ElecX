import 'package:elecx/src/application/project/project_boundary_topology_migration.dart';
import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/domain/boundary_construction_registry.dart';
import 'package:elecx/src/domain/boundary_edge_identity_registry.dart';
import 'package:elecx/src/domain/boundary_host_migration.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_orientation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('topology split migrates wall construction in the same canonical commit',
      () {
    final fixture = _fixture();
    final mutations = ProjectMutationSession(fixture.project);
    final service = ProjectBoundaryTopologyMigrationService(mutations);
    final first = BoundaryEdgeId('edge-0-a');
    final second = BoundaryEdgeId('edge-0-b');
    final edit = service.begin(
      spaceId: fixture.spaceId,
      expectedVersion: mutations.current.version,
    );

    final preview = edit.previewSplitEdge(
      sourceEdgeId: fixture.sourceEdgeId,
      splitPoint: const BoundaryPointMm(xMm: 2000, yMm: 0),
      firstResultEdgeId: first,
      secondResultEdgeId: second,
    );

    final firstHost = BoundaryEdgeHostRef(
      spaceId: fixture.spaceId,
      edgeId: first,
    );
    final secondHost = BoundaryEdgeHostRef(
      spaceId: fixture.spaceId,
      edgeId: second,
    );
    expect(preview.constructions[firstHost], fixture.profile);
    expect(preview.constructions[secondHost], fixture.profile);
    expect(
      preview.constructions[fixture.sourceHost],
      isNull,
    );

    final committed = edit.commit();
    expect(committed, isNotNull);
    expect(mutations.current.version, LocalProjectVersion(2));
    expect(
      committed!.mutation.changeSet.engineeringMetadataDiff
          .boundaryConstructionRegistryChanged,
      isTrue,
    );
    expect(
      mutations
          .current.engineeringMetadata.boundaryConstructionRegistry[firstHost],
      fixture.profile,
    );
    expect(
      mutations
          .current.engineeringMetadata.boundaryConstructionRegistry[secondHost],
      fixture.profile,
    );
    expect(
      mutations.current.engineeringMetadata
          .boundaryConstructionRegistry[fixture.sourceHost],
      isNull,
    );

    final undone = mutations.undo(mutations.current.version);
    expect(undone, isNotNull);
    expect(
      mutations.current.engineeringMetadata
          .boundaryConstructionRegistry[fixture.sourceHost],
      fixture.profile,
    );
    expect(
      mutations
          .current.engineeringMetadata.boundaryConstructionRegistry[firstHost],
      isNull,
    );

    final redone = mutations.redo(mutations.current.version);
    expect(redone, isNotNull);
    expect(
      mutations
          .current.engineeringMetadata.boundaryConstructionRegistry[firstHost],
      fixture.profile,
    );
    expect(
      mutations
          .current.engineeringMetadata.boundaryConstructionRegistry[secondHost],
      fixture.profile,
    );
  });
}

_TopologyConstructionFixture _fixture() {
  final projectId = ProjectId('project-topology-construction');
  final siteId = SiteId('site-1');
  final buildingId = BuildingId('building-1');
  final levelId = LevelId('level-1');
  final spaceId = SpaceId('space-1');
  final edges = [
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
  final boundaryEdges = <BoundaryEdgeId, ProjectBoundaryEdge>{};
  for (var index = 0; index < edges.length; index++) {
    boundaryEdges[edges[index]] = ProjectBoundaryEdge(
      id: edges[index],
      spaceId: spaceId,
      start: points[index],
      end: points[(index + 1) % points.length],
    );
  }
  final topology = SpaceBoundaryTopology(
    spaceId: spaceId,
    orderedEdgeIds: edges,
    edges: boundaryEdges,
  );
  final sourceHost = BoundaryEdgeHostRef(
    spaceId: spaceId,
    edgeId: edges.first,
  );
  final profile = BoundaryConstructionProfile(
    kind: BoundaryConstructionKind.wall,
    thicknessMm: 180,
    materialId: 'brick',
    fireRatingId: 'EI60',
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
        name: 'L1',
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
  final project = ProjectAggregateRoot(
    id: projectId,
    siteId: siteId,
    version: LocalProjectVersion(1),
    engineeringMetadata: ProjectEngineeringMetadata(
      boundaryEdgeIdentityRegistry: BoundaryEdgeIdentityRegistry({
        for (final edgeId in edges) edgeId: spaceId,
      }),
      boundaryConstructionRegistry: BoundaryConstructionRegistry({
        sourceHost: profile,
      }),
    ),
    stores: stores,
  );
  return _TopologyConstructionFixture(
    project: project,
    spaceId: spaceId,
    sourceEdgeId: edges.first,
    sourceHost: sourceHost,
    profile: profile,
  );
}

final class _TopologyConstructionFixture {
  const _TopologyConstructionFixture({
    required this.project,
    required this.spaceId,
    required this.sourceEdgeId,
    required this.sourceHost,
    required this.profile,
  });

  final ProjectAggregateRoot project;
  final SpaceId spaceId;
  final BoundaryEdgeId sourceEdgeId;
  final BoundaryEdgeHostRef sourceHost;
  final BoundaryConstructionProfile profile;
}
