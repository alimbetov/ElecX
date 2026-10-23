import 'package:elecx/src/application/project/project_boundary_topology_migration.dart';
import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P7A-6.3 lifecycle interruption', () {
    test('cancel after split preview leaves canonical state and history exact',
        () {
      final fixture = _Fixture();
      final initial = fixture.project();
      final mutations = ProjectMutationSession(initial);
      final edit = ProjectBoundaryTopologyMigrationService(mutations).begin(
        spaceId: fixture.spaceId,
        expectedVersion: initial.version,
      );

      edit.previewSplitEdge(
        sourceEdgeId: fixture.bottom,
        splitPoint: const BoundaryPointMm(xMm: 2000, yMm: 0),
        firstResultEdgeId: fixture.bottomA,
        secondResultEdgeId: fixture.bottomB,
      );

      expect(edit.dirty, isTrue);
      expect(mutations.current, same(initial));
      expect(mutations.undoDepth, 0);
      expect(mutations.redoDepth, 0);

      edit.cancel();

      expect(edit.dirty, isFalse);
      expect(edit.previewTopology, same(edit.source));
      expect(mutations.current, same(initial));
      expect(mutations.current.version, LocalProjectVersion(0));
      expect(mutations.undoDepth, 0);
      expect(mutations.redoDepth, 0);
      expect(
        mutations.current.index.boundary(fixture.spaceId)!.orderedEdgeIds,
        [fixture.bottom, fixture.east, fixture.north, fixture.west],
      );
    });

    test('preview interrupted by another canonical commit cannot commit later',
        () {
      final fixture = _Fixture();
      final initial = fixture.project();
      final mutations = ProjectMutationSession(initial);
      final edit = ProjectBoundaryTopologyMigrationService(mutations).begin(
        spaceId: fixture.spaceId,
        expectedVersion: initial.version,
      );

      edit.previewSplitEdge(
        sourceEdgeId: fixture.bottom,
        splitPoint: const BoundaryPointMm(xMm: 2000, yMm: 0),
        firstResultEdgeId: fixture.bottomA,
        secondResultEdgeId: fixture.bottomB,
      );

      final winner = mutations.commit(
        ProjectMutationRequest(
          expectedVersion: initial.version,
          command: const _RenameSiteCommand('Renamed while preview open'),
        ),
      );
      expect(winner, isNotNull);
      expect(mutations.current.version, LocalProjectVersion(1));
      expect(mutations.undoDepth, 1);

      expect(
        edit.commit,
        throwsA(isA<StaleProjectMutationException>()),
      );

      expect(mutations.current.version, LocalProjectVersion(1));
      expect(mutations.undoDepth, 1);
      expect(mutations.redoDepth, 0);
      expect(
        mutations.current.index.boundary(fixture.spaceId)!.orderedEdgeIds,
        [fixture.bottom, fixture.east, fixture.north, fixture.west],
      );
      expect(
        mutations.current.index.site(fixture.siteId)!.name,
        'Renamed while preview open',
      );
    });

    test('cancel remains harmless after preview becomes stale', () {
      final fixture = _Fixture();
      final initial = fixture.project();
      final mutations = ProjectMutationSession(initial);
      final edit = ProjectBoundaryTopologyMigrationService(mutations).begin(
        spaceId: fixture.spaceId,
        expectedVersion: initial.version,
      );

      edit.previewSplitEdge(
        sourceEdgeId: fixture.bottom,
        splitPoint: const BoundaryPointMm(xMm: 2000, yMm: 0),
        firstResultEdgeId: fixture.bottomA,
        secondResultEdgeId: fixture.bottomB,
      );
      mutations.commit(
        ProjectMutationRequest(
          expectedVersion: initial.version,
          command: const _RenameSiteCommand('Winner'),
        ),
      );

      edit.cancel();

      expect(edit.dirty, isFalse);
      expect(mutations.current.version, LocalProjectVersion(1));
      expect(mutations.undoDepth, 1);
      expect(
        mutations.current.index.boundary(fixture.spaceId)!.orderedEdgeIds,
        [fixture.bottom, fixture.east, fixture.north, fixture.west],
      );
    });
  });
}

final class _Fixture {
  final projectId = ProjectId('project-p7a63');
  final siteId = SiteId('site-p7a63');
  final buildingId = BuildingId('building-p7a63');
  final levelId = LevelId('level-p7a63');
  final spaceId = SpaceId('space-p7a63');

  final bottom = BoundaryEdgeId('bottom');
  final bottomA = BoundaryEdgeId('bottom-a');
  final bottomB = BoundaryEdgeId('bottom-b');
  final east = BoundaryEdgeId('east');
  final north = BoundaryEdgeId('north');
  final west = BoundaryEdgeId('west');

  ProjectAggregateRoot project() => ProjectAggregateRoot(
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
          boundaries: {spaceId: boundary()},
        ),
      );

  SpaceBoundaryTopology boundary() => SpaceBoundaryTopology(
        spaceId: spaceId,
        orderedEdgeIds: [bottom, east, north, west],
        edges: {
          bottom: _edge(bottom, 0, 0, 4000, 0),
          east: _edge(east, 4000, 0, 4000, 3000),
          north: _edge(north, 4000, 3000, 0, 3000),
          west: _edge(west, 0, 3000, 0, 0),
        },
      );

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

final class _RenameSiteCommand implements ProjectCommand {
  const _RenameSiteCommand(this.name);

  final String name;

  @override
  String get commandType => 'p7a63.rename-site';

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) {
    final site = current.index.site(current.siteId)!;
    final sites = Map<SiteId, ProjectSiteEntity>.from(current.stores.sites)
      ..[site.id] = ProjectSiteEntity(
        id: site.id,
        name: name,
        buildingIds: site.buildingIds,
      );
    final stores = current.stores;
    return ProjectCommandCandidate.fromState(
      state: ProjectMutableState(
        engineeringMetadata: current.engineeringMetadata,
        stores: ProjectEntityStores(
          sites: sites,
          buildings: stores.buildings,
          levels: stores.levels,
          zones: stores.zones,
          spaces: stores.spaces,
          openings: stores.openings,
          adjacencies: stores.adjacencies,
          overlays: stores.overlays,
          boundaries: stores.boundaries,
        ),
      ),
    );
  }
}
