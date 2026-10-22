import 'package:elecx/src/application/project/project_destructive_commands.dart';
import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P7A-2 canonical aggregate ownership', () {
    test('aggregate owns and indexes stable boundary topology', () {
      final fixture = _Fixture();
      final project = fixture.project(boundary: fixture.initialBoundary());

      expect(project.stores.boundaries[fixture.spaceId], isNotNull);
      expect(
        project.index.boundary(fixture.spaceId)?.orderedEdgeIds,
        fixture.edgeIds,
      );
      for (final edgeId in fixture.edgeIds) {
        expect(project.index.boundaryEdge(edgeId)?.id, edgeId);
        expect(project.index.spaceByBoundaryEdgeId[edgeId], fixture.spaceId);
      }
      expect(project.index.isConsistentWith(project.stores), isTrue);
    });

    test(
      'boundary geometry changes participate in canonical diff and undo',
      () {
        final fixture = _Fixture();
        final initial = fixture.project(boundary: fixture.initialBoundary());
        final session = ProjectMutationSession(initial);

        final result = session.commit(
          ProjectMutationRequest(
            expectedVersion: initial.version,
            command: _ReplaceBoundaryCommand(fixture.changedBoundary()),
          ),
        );

        expect(result, isNotNull);
        expect(result!.project.version, LocalProjectVersion(1));
        expect(result.changeSet.updatedEntityIds, contains(fixture.spaceId));
        expect(result.changeSet.updatedEntityIds, contains(fixture.edgeA));
        expect(result.changeSet.updatedEntityIds, contains(fixture.edgeB));
        expect(
          result.project.index.boundaryEdge(fixture.edgeA)?.end,
          const BoundaryPointMm(xMm: 1200, yMm: 0),
        );

        final undone = session.undo(result.project.version);
        expect(undone, isNotNull);
        expect(undone!.project.version, LocalProjectVersion(2));
        expect(
          undone.project.index.boundaryEdge(fixture.edgeA)?.end,
          const BoundaryPointMm(xMm: 1000, yMm: 0),
        );
        expect(undone.changeSet.updatedEntityIds, contains(fixture.spaceId));
        expect(undone.changeSet.updatedEntityIds, contains(fixture.edgeA));
      },
    );

    test(
      'invalid boundary candidate fails before authoritative state changes',
      () {
        final fixture = _Fixture();
        final initial = fixture.project(boundary: fixture.initialBoundary());
        final session = ProjectMutationSession(initial);
        final foreignSpace = SpaceId('foreign-space');
        final invalid = fixture.boundaryFor(foreignSpace);

        expect(
          () => session.commit(
            ProjectMutationRequest(
              expectedVersion: initial.version,
              command: _ReplaceBoundaryCommand(invalid),
            ),
          ),
          throwsA(
            isA<ProjectCandidateValidationException>().having(
              (error) => error.issues.map((issue) => issue.code),
              'issue codes',
              anyOf(
                contains(ProjectAggregateIssueCode.boundarySpaceKeyMismatch),
                contains(ProjectAggregateIssueCode.danglingBoundarySpace),
              ),
            ),
          ),
        );

        expect(session.current, same(initial));
        expect(session.current.version, LocalProjectVersion(0));
        expect(
          session.current.index.boundaryEdge(fixture.edgeA)?.end,
          const BoundaryPointMm(xMm: 1000, yMm: 0),
        );
        expect(session.undoDepth, 0);
      },
    );

    test('legacy stores-only commands cannot erase P7A boundary state', () {
      final fixture = _Fixture();
      final initial = fixture.project(boundary: fixture.initialBoundary());
      final session = ProjectMutationSession(initial);

      final result = session.commit(
        ProjectMutationRequest(
          expectedVersion: initial.version,
          command: _LegacyRenameSpaceCommand(fixture.spaceId),
        ),
      );

      expect(result, isNotNull);
      expect(
        result!.project.index.space(fixture.spaceId)?.name,
        'Room renamed',
      );
      expect(
        result.project.index.boundary(fixture.spaceId)?.orderedEdgeIds,
        fixture.edgeIds,
      );
      expect(result.project.index.boundaryEdge(fixture.edgeA), isNotNull);
    });

    test('removing a space atomically removes its owned boundary and undo restores it', () {
      final fixture = _Fixture();
      final initial = fixture.project(boundary: fixture.initialBoundary());
      final session = ProjectMutationSession(initial);

      final result = session.commit(
        ProjectMutationRequest(
          expectedVersion: initial.version,
          command: RemoveSpaceCommand(spaceId: fixture.spaceId),
        ),
      );

      expect(result, isNotNull);
      expect(result!.project.index.space(fixture.spaceId), isNull);
      expect(result.project.index.boundary(fixture.spaceId), isNull);
      for (final edgeId in fixture.edgeIds) {
        expect(result.project.index.boundaryEdge(edgeId), isNull);
        expect(result.changeSet.removedEntityIds, contains(edgeId));
      }
      expect(result.changeSet.removedEntityIds, contains(fixture.spaceId));

      final undone = session.undo(result.project.version);
      expect(undone, isNotNull);
      expect(undone!.project.index.space(fixture.spaceId), isNotNull);
      expect(
        undone.project.index.boundary(fixture.spaceId)?.orderedEdgeIds,
        fixture.edgeIds,
      );
      for (final edgeId in fixture.edgeIds) {
        expect(undone.project.index.boundaryEdge(edgeId), isNotNull);
      }
    });
  });
}

final class _ReplaceBoundaryCommand implements ProjectCommand {
  _ReplaceBoundaryCommand(this.boundary);

  final SpaceBoundaryTopology boundary;

  @override
  String get commandType => 'replaceBoundaryTopology';

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) {
    return ProjectCommandCandidate.fromState(
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
          boundaries: {
            ...current.stores.boundaries,
            current.stores.spaces.keys.single: boundary,
          },
        ),
      ),
    );
  }
}

final class _LegacyRenameSpaceCommand implements ProjectCommand {
  _LegacyRenameSpaceCommand(this.spaceId);

  final SpaceId spaceId;

  @override
  String get commandType => 'legacyRenameSpace';

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) {
    final currentSpace = current.stores.spaces[spaceId]!;
    return ProjectCommandCandidate(
      stores: ProjectEntityStores(
        sites: current.stores.sites,
        buildings: current.stores.buildings,
        levels: current.stores.levels,
        zones: current.stores.zones,
        spaces: {
          ...current.stores.spaces,
          spaceId: ProjectSpaceEntity(
            id: currentSpace.id,
            levelId: currentSpace.levelId,
            name: 'Room renamed',
            usage: currentSpace.usage,
          ),
        },
      ),
    );
  }
}

final class _Fixture {
  final projectId = ProjectId('project-p7a');
  final siteId = SiteId('site-p7a');
  final buildingId = BuildingId('building-p7a');
  final levelId = LevelId('level-p7a');
  final spaceId = SpaceId('space-p7a');

  final edgeA = BoundaryEdgeId('edge-a');
  final edgeB = BoundaryEdgeId('edge-b');
  final edgeC = BoundaryEdgeId('edge-c');
  final edgeD = BoundaryEdgeId('edge-d');

  List<BoundaryEdgeId> get edgeIds => [edgeA, edgeB, edgeC, edgeD];

  ProjectAggregateRoot project({required SpaceBoundaryTopology boundary}) {
    return ProjectAggregateRoot(
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
        boundaries: {spaceId: boundary},
      ),
    );
  }

  SpaceBoundaryTopology initialBoundary() => boundaryFor(spaceId);

  SpaceBoundaryTopology changedBoundary() {
    const p0 = BoundaryPointMm(xMm: 0, yMm: 0);
    const p1 = BoundaryPointMm(xMm: 1200, yMm: 0);
    const p2 = BoundaryPointMm(xMm: 1000, yMm: 1000);
    const p3 = BoundaryPointMm(xMm: 0, yMm: 1000);
    return _topology(spaceId, [p0, p1, p2, p3]);
  }

  SpaceBoundaryTopology boundaryFor(SpaceId owner) {
    const p0 = BoundaryPointMm(xMm: 0, yMm: 0);
    const p1 = BoundaryPointMm(xMm: 1000, yMm: 0);
    const p2 = BoundaryPointMm(xMm: 1000, yMm: 1000);
    const p3 = BoundaryPointMm(xMm: 0, yMm: 1000);
    return _topology(owner, [p0, p1, p2, p3]);
  }

  SpaceBoundaryTopology _topology(
    SpaceId owner,
    List<BoundaryPointMm> points,
  ) {
    final ids = edgeIds;
    final edges = <BoundaryEdgeId, ProjectBoundaryEdge>{};
    for (var index = 0; index < ids.length; index++) {
      edges[ids[index]] = ProjectBoundaryEdge(
        id: ids[index],
        spaceId: owner,
        start: points[index],
        end: points[(index + 1) % points.length],
      );
    }
    return SpaceBoundaryTopology(
      spaceId: owner,
      orderedEdgeIds: ids,
      edges: edges,
    );
  }
}
