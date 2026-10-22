import 'package:elecx/src/application/project/project_boundary_topology_editing.dart';
import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/domain/boundary_edge_identity_registry.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_orientation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('vertex edit preserves stable ids and commits once', () {
    final fixture = _Fixture();
    final edit = fixture.service.begin(
      spaceId: fixture.spaceId,
      expectedVersion: fixture.mutations.current.version,
    );

    final preview = edit.previewMoveVertex(
      outgoingEdgeId: fixture.edgeIds[1],
      target: const BoundaryPointMm(xMm: 4500, yMm: 0),
    );

    expect(preview.topology.orderedEdgeIds, fixture.edgeIds);
    expect(
      preview.lineage.lineage.every(
        (record) => record.kind == BoundaryEdgeLineageKind.preserved,
      ),
      isTrue,
    );
    expect(fixture.mutations.current.version, LocalProjectVersion(0));

    final committed = edit.commit();
    expect(committed, isNotNull);
    expect(fixture.mutations.current.version, LocalProjectVersion(1));
    expect(
      committed!.mutation.changeSet.updatedEntityIds,
      containsAll(<EntityId>[
        fixture.spaceId,
        fixture.edgeIds[0],
        fixture.edgeIds[1],
      ]),
    );
    final topology = fixture.mutations.current.index.boundary(fixture.spaceId)!;
    expect(
      topology.edges[fixture.edgeIds[0]]!.end,
      const BoundaryPointMm(xMm: 4500, yMm: 0),
    );
    expect(
      topology.edges[fixture.edgeIds[1]]!.start,
      const BoundaryPointMm(xMm: 4500, yMm: 0),
    );
  });

  test('edge normal edit uses BoundaryEdgeId and remains one undo step', () {
    final fixture = _Fixture();
    final edit = fixture.service.begin(
      spaceId: fixture.spaceId,
      expectedVersion: fixture.mutations.current.version,
    );

    edit.previewMoveEdgeNormal(edgeId: fixture.edgeIds[0], distanceMm: 500);
    final committed = edit.commit();
    expect(committed, isNotNull);
    expect(fixture.mutations.undoDepth, 1);

    final moved = fixture.mutations.current.index.boundary(fixture.spaceId)!;
    expect(moved.edges[fixture.edgeIds[0]]!.start.yMm, 500);
    expect(moved.edges[fixture.edgeIds[0]]!.end.yMm, 500);

    final undo = fixture.mutations.undo(fixture.mutations.current.version);
    expect(undo, isNotNull);
    final restored = fixture.mutations.current.index.boundary(fixture.spaceId)!;
    expect(restored.edges[fixture.edgeIds[0]]!.start.yMm, 0);
    expect(restored.edges[fixture.edgeIds[0]]!.end.yMm, 0);
  });

  test('cancel leaves canonical project unchanged', () {
    final fixture = _Fixture();
    final before = fixture.mutations.current;
    final edit = fixture.service.begin(
      spaceId: fixture.spaceId,
      expectedVersion: before.version,
    );

    edit.previewMoveEdgeNormal(edgeId: fixture.edgeIds[1], distanceMm: 400);
    expect(edit.dirty, isTrue);
    edit.cancel();

    expect(edit.dirty, isFalse);
    expect(fixture.mutations.current, same(before));
    expect(fixture.mutations.undoDepth, 0);
  });

  test('stale edit session is rejected before canonical mutation', () {
    final fixture = _Fixture();
    final edit = fixture.service.begin(
      spaceId: fixture.spaceId,
      expectedVersion: fixture.mutations.current.version,
    );

    final competing = fixture.service.begin(
      spaceId: fixture.spaceId,
      expectedVersion: fixture.mutations.current.version,
    );
    competing.previewMoveEdgeNormal(
      edgeId: fixture.edgeIds[2],
      distanceMm: 300,
    );
    expect(competing.commit(), isNotNull);

    expect(
      () => edit.previewMoveEdgeNormal(
        edgeId: fixture.edgeIds[0],
        distanceMm: 300,
      ),
      throwsA(isA<StaleProjectMutationException>()),
    );
    expect(fixture.mutations.undoDepth, 1);
  });

  test('invalid short edge fails before authoritative state changes', () {
    final fixture = _Fixture();
    final before = fixture.mutations.current;
    final edit = fixture.service.begin(
      spaceId: fixture.spaceId,
      expectedVersion: before.version,
    );

    expect(
      () => edit.previewMoveVertex(
        outgoingEdgeId: fixture.edgeIds[1],
        target: const BoundaryPointMm(xMm: 100, yMm: 0),
      ),
      throwsA(
        isA<BoundaryTopologyEditingException>().having(
          (error) => error.code,
          'code',
          BoundaryTopologyEditingIssueCode.geometryTooShort,
        ),
      ),
    );
    expect(fixture.mutations.current, same(before));
    expect(fixture.mutations.undoDepth, 0);
  });
}

final class _Fixture {
  _Fixture() {
    final topology = SpaceBoundaryTopology(
      spaceId: spaceId,
      orderedEdgeIds: edgeIds,
      edges: <BoundaryEdgeId, ProjectBoundaryEdge>{
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
    final boundaries = <SpaceId, SpaceBoundaryTopology>{spaceId: topology};
    final registry = const BoundaryEdgeIdentityRegistry.empty()
        .registerActiveBoundaries(boundaries);
    final project = ProjectAggregateRoot(
      id: ProjectId('project'),
      siteId: siteId,
      version: LocalProjectVersion(0),
      engineeringMetadata: ProjectEngineeringMetadata(
        boundaryEdgeIdentityRegistry: registry,
      ),
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
            name: 'Level',
            levelNumber: 1,
            elevationMm: 0,
            spaceIds: <SpaceId>[spaceId],
          ),
        },
        spaces: <SpaceId, ProjectSpaceEntity>{
          spaceId: ProjectSpaceEntity(
            id: spaceId,
            levelId: levelId,
            name: 'Room',
          ),
        },
        boundaries: boundaries,
      ),
    );
    mutations = ProjectMutationSession(project);
    service = ProjectBoundaryTopologyEditingService(mutations);
  }

  final SiteId siteId = SiteId('site');
  final BuildingId buildingId = BuildingId('building');
  final LevelId levelId = LevelId('level');
  final SpaceId spaceId = SpaceId('space');
  final List<BoundaryEdgeId> edgeIds = <BoundaryEdgeId>[
    BoundaryEdgeId('edge-a'),
    BoundaryEdgeId('edge-b'),
    BoundaryEdgeId('edge-c'),
    BoundaryEdgeId('edge-d'),
  ];

  late final ProjectMutationSession mutations;
  late final ProjectBoundaryTopologyEditingService service;
}
