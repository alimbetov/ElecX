import 'package:elecx/src/application/project/project_boundary_construction_editing.dart';
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
  group('ProjectBoundaryConstructionEditingService', () {
    test('construction-only edit is a real versioned mutation with undo/redo',
        () {
      final fixture = _fixture();
      final mutations = ProjectMutationSession(fixture.project);
      final service = ProjectBoundaryConstructionEditingService(mutations);
      final profile = BoundaryConstructionProfile(
        kind: BoundaryConstructionKind.wall,
        thicknessMm: 180,
        materialId: 'brick',
        fireRatingId: 'EI60',
      );

      final committed = service.setWallConstruction(
        spaceId: fixture.spaceId,
        edgeId: fixture.edgeId,
        profile: profile,
        expectedVersion: mutations.current.version,
      );

      expect(committed, isNotNull);
      expect(committed!.project.version, LocalProjectVersion(2));
      expect(
        committed.changeSet.engineeringMetadataDiff
            .boundaryConstructionRegistryChanged,
        isTrue,
      );
      expect(committed.changeSet.entityDiff.isEmpty, isTrue);
      final host = BoundaryEdgeHostRef(
        spaceId: fixture.spaceId,
        edgeId: fixture.edgeId,
      );
      expect(
        mutations.current.engineeringMetadata.boundaryConstructionRegistry[host],
        profile,
      );

      final undone = mutations.undo(mutations.current.version);
      expect(undone, isNotNull);
      expect(
        mutations.current.engineeringMetadata.boundaryConstructionRegistry[host],
        isNull,
      );

      final redone = mutations.redo(mutations.current.version);
      expect(redone, isNotNull);
      expect(
        mutations.current.engineeringMetadata.boundaryConstructionRegistry[host],
        profile,
      );
    });

    test('repeating identical profile is a no-op', () {
      final fixture = _fixture();
      final mutations = ProjectMutationSession(fixture.project);
      final service = ProjectBoundaryConstructionEditingService(mutations);
      final profile = BoundaryConstructionProfile(
        kind: BoundaryConstructionKind.wall,
        thicknessMm: 180,
        materialId: 'brick',
      );
      service.setWallConstruction(
        spaceId: fixture.spaceId,
        edgeId: fixture.edgeId,
        profile: profile,
        expectedVersion: mutations.current.version,
      );
      final version = mutations.current.version;

      final result = service.setWallConstruction(
        spaceId: fixture.spaceId,
        edgeId: fixture.edgeId,
        profile: profile,
        expectedVersion: version,
      );

      expect(result, isNull);
      expect(mutations.current.version, version);
    });

    test('inactive edge is rejected before mutation', () {
      final fixture = _fixture();
      final mutations = ProjectMutationSession(fixture.project);
      final service = ProjectBoundaryConstructionEditingService(mutations);

      expect(
        () => service.setWallConstruction(
          spaceId: fixture.spaceId,
          edgeId: BoundaryEdgeId('retired'),
          profile: BoundaryConstructionProfile(
            kind: BoundaryConstructionKind.wall,
            thicknessMm: 120,
            materialId: 'partition',
          ),
          expectedVersion: mutations.current.version,
        ),
        throwsStateError,
      );
      expect(mutations.current.version, LocalProjectVersion(1));
    });
  });
}

_ConstructionEditFixture _fixture() {
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
  return _ConstructionEditFixture(
    spaceId: spaceId,
    edgeId: edgeIds.first,
    project: ProjectAggregateRoot(
      id: projectId,
      siteId: siteId,
      version: LocalProjectVersion(1),
      engineeringMetadata: ProjectEngineeringMetadata(
        boundaryEdgeIdentityRegistry: BoundaryEdgeIdentityRegistry({
          for (final edgeId in edgeIds) edgeId: spaceId,
        }),
      ),
      stores: stores,
    ),
  );
}

final class _ConstructionEditFixture {
  const _ConstructionEditFixture({
    required this.spaceId,
    required this.edgeId,
    required this.project,
  });

  final SpaceId spaceId;
  final BoundaryEdgeId edgeId;
  final ProjectAggregateRoot project;
}
