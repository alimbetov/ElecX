import 'package:elecx/src/application/project/project_boundary_topology_migration.dart';
import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/domain/boundary_edge_identity_registry.dart';
import 'package:elecx/src/domain/boundary_host_migration.dart';
import 'package:elecx/src/domain/boundary_host_registry.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_orientation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('diagonal host split commits atomically without false ambiguity', () {
    final fixture = _Fixture();
    final initial = fixture.project();
    final mutations = ProjectMutationSession(initial);
    final edit = ProjectBoundaryTopologyMigrationService(mutations).begin(
      spaceId: fixture.spaceId,
      expectedVersion: initial.version,
    );

    final preview = edit.previewSplitEdge(
      sourceEdgeId: fixture.source,
      splitPoint: const BoundaryPointMm(xMm: 300, yMm: 300),
      firstResultEdgeId: fixture.first,
      secondResultEdgeId: fixture.second,
    );

    final host = preview.hostedObjects['component:diagonal']!;
    expect(host.host.edgeId, fixture.first);
    expect(host.startOffsetMm, 424);
    expect(mutations.current.version, LocalProjectVersion(0));
    expect(mutations.undoDepth, 0);

    final committed = edit.commit();
    expect(committed, isNotNull);
    expect(mutations.current.version, LocalProjectVersion(1));
    expect(mutations.undoDepth, 1);
    expect(
      mutations.current.engineeringMetadata
          .boundaryHostedObjectRegistry['component:diagonal']!.host.edgeId,
      fixture.first,
    );
    expect(
      mutations.current.engineeringMetadata
          .boundaryHostedObjectRegistry['component:diagonal']!.startOffsetMm,
      424,
    );
  });
}

final class _Fixture {
  final projectId = ProjectId('p7a62-diagonal-project');
  final siteId = SiteId('site');
  final buildingId = BuildingId('building');
  final levelId = LevelId('level');
  final spaceId = SpaceId('space');
  final source = BoundaryEdgeId('source');
  final first = BoundaryEdgeId('first');
  final second = BoundaryEdgeId('second');
  final sideB = BoundaryEdgeId('side-b');
  final sideC = BoundaryEdgeId('side-c');

  late final SpaceBoundaryTopology topology = SpaceBoundaryTopology(
    spaceId: spaceId,
    orderedEdgeIds: [source, sideB, sideC],
    edges: {
      source: _edge(source, 0, 0, 600, 600),
      sideB: _edge(sideB, 600, 600, 0, 1200),
      sideC: _edge(sideC, 0, 1200, 0, 0),
    },
  );

  ProjectAggregateRoot project() {
    final identity = const BoundaryEdgeIdentityRegistry.empty()
        .registerActiveBoundaries({spaceId: topology});
    final hostedObjects = BoundaryHostedObjectRegistry({
      'component:diagonal': BoundaryHostedReference.point(
        objectKey: 'component:diagonal',
        objectKind: BoundaryHostedObjectKind.component,
        host: BoundaryEdgeHostRef(spaceId: spaceId, edgeId: source),
        offsetMm: 424,
      ),
    });
    return ProjectAggregateRoot(
      id: projectId,
      siteId: siteId,
      version: LocalProjectVersion(0),
      engineeringMetadata: ProjectEngineeringMetadata(
        boundaryEdgeIdentityRegistry: identity,
        boundaryHostedObjectRegistry: hostedObjects,
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
            name: 'Diagonal room',
          ),
        },
        boundaries: {spaceId: topology},
      ),
    );
  }

  ProjectBoundaryEdge _edge(
    BoundaryEdgeId id,
    int x1,
    int y1,
    int x2,
    int y2,
  ) =>
      ProjectBoundaryEdge(
        id: id,
        spaceId: spaceId,
        start: BoundaryPointMm(xMm: x1, yMm: y1),
        end: BoundaryPointMm(xMm: x2, yMm: y2),
      );
}
