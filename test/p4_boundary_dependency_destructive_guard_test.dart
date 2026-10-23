import 'package:elecx/src/application/project/project_authoring_error.dart';
import 'package:elecx/src/application/project/project_destructive_commands.dart';
import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/domain/boundary_host_migration.dart';
import 'package:elecx/src/domain/boundary_host_registry.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_orientation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'P4E remove space rejects durable wall-hosted dependencies before mutation',
    () {
      final project = _projectWithHostedRouteAnchor();
      final session = ProjectMutationSession(project);
      final before = session.current;
      final edgeId = BoundaryEdgeId('edge-1');

      expect(
        () => session.commit(
          ProjectMutationRequest(
            expectedVersion: before.version,
            command: RemoveSpaceCommand(spaceId: SpaceId('space-1')),
          ),
        ),
        throwsA(
          isA<ProjectAuthoringException>()
              .having(
                (error) => error.code,
                'code',
                ProjectAuthoringIssueCode.spaceHasBoundaryDependencies,
              )
              .having(
                (error) => error.blockingEntityIds,
                'blockingEntityIds',
                <EntityId>{edgeId},
              ),
        ),
      );

      expect(session.current, same(before));
      expect(session.current.version, LocalProjectVersion(0));
      expect(session.undoDepth, 0);
      expect(session.redoDepth, 0);
      expect(
        session.current.engineeringMetadata.boundaryHostedObjectRegistry
            .references,
        hasLength(1),
      );
      expect(session.current.index.boundary(SpaceId('space-1')), isNotNull);
    },
  );
}

ProjectAggregateRoot _projectWithHostedRouteAnchor() {
  final siteId = SiteId('site-root');
  final buildingId = BuildingId('building-a');
  final levelId = LevelId('level-1');
  final spaceId = SpaceId('space-1');
  final edge1 = BoundaryEdgeId('edge-1');
  final edge2 = BoundaryEdgeId('edge-2');
  final edge3 = BoundaryEdgeId('edge-3');
  final edge4 = BoundaryEdgeId('edge-4');
  final topology = SpaceBoundaryTopology(
    spaceId: spaceId,
    orderedEdgeIds: [edge1, edge2, edge3, edge4],
    edges: {
      edge1: ProjectBoundaryEdge(
        id: edge1,
        spaceId: spaceId,
        start: const BoundaryPointMm(xMm: 0, yMm: 0),
        end: const BoundaryPointMm(xMm: 4000, yMm: 0),
      ),
      edge2: ProjectBoundaryEdge(
        id: edge2,
        spaceId: spaceId,
        start: const BoundaryPointMm(xMm: 4000, yMm: 0),
        end: const BoundaryPointMm(xMm: 4000, yMm: 3000),
      ),
      edge3: ProjectBoundaryEdge(
        id: edge3,
        spaceId: spaceId,
        start: const BoundaryPointMm(xMm: 4000, yMm: 3000),
        end: const BoundaryPointMm(xMm: 0, yMm: 3000),
      ),
      edge4: ProjectBoundaryEdge(
        id: edge4,
        spaceId: spaceId,
        start: const BoundaryPointMm(xMm: 0, yMm: 3000),
        end: const BoundaryPointMm(xMm: 0, yMm: 0),
      ),
    },
  );
  final host = BoundaryEdgeHostRef(spaceId: spaceId, edgeId: edge1);
  final hostedRegistry = BoundaryHostedObjectRegistry({
    BoundaryHostedObjectRegistry.routeAnchorObjectKey(
      'C-103',
      RouteAnchorId('anchor-1'),
    ): BoundaryHostedReference.point(
      objectKey: BoundaryHostedObjectRegistry.routeAnchorObjectKey(
        'C-103',
        RouteAnchorId('anchor-1'),
      ),
      objectKind: BoundaryHostedObjectKind.routeAnchor,
      host: host,
      offsetMm: 1000,
    ),
  });

  return ProjectAggregateRoot(
    id: ProjectId('project-1'),
    siteId: siteId,
    version: LocalProjectVersion(0),
    engineeringMetadata: ProjectEngineeringMetadata(
      boundaryHostedObjectRegistry: hostedRegistry,
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
          name: 'Building A',
          levelIds: [levelId],
        ),
      },
      levels: {
        levelId: ProjectLevelEntity(
          id: levelId,
          buildingId: buildingId,
          name: 'Floor 1',
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
    ),
  );
}
