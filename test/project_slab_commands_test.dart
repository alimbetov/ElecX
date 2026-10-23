import 'package:elecx/src/application/project/project_authoring_error.dart';
import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_slab_commands.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/slab_topology.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('canonical slab CRUD commands', () {
    test('create commits one SlabId and reports it in ChangeSet', () {
      final fixture = _Fixture();
      final session = ProjectMutationSession(fixture.project());
      final slab = fixture.slab();

      final result = session.commit(
        ProjectMutationRequest(
          expectedVersion: session.current.version,
          command: CreateSlabCommand(slab: slab),
        ),
      );

      expect(result, isNotNull);
      expect(result!.changeSet.commandType, 'project.slab.create');
      expect(result.changeSet.addedEntityIds, {fixture.slabId});
      expect(result.project.index.slab(fixture.slabId), same(slab));
      expect(result.project.version, LocalProjectVersion(1));
    });

    test('update preserves SlabId and invalidates old physical values', () {
      final fixture = _Fixture();
      final before = fixture.slab();
      final session = ProjectMutationSession(
        fixture.project(slabs: {before.id: before}),
      );
      final after = fixture.slab(
        bottomElevationMm: 2980,
        thicknessMm: 220,
        materialId: 'reinforced-concrete-c30',
      );

      final result = session.commit(
        ProjectMutationRequest(
          expectedVersion: session.current.version,
          command: UpdateSlabCommand(slab: after),
        ),
      );

      expect(result, isNotNull);
      expect(result!.changeSet.updatedEntityIds, {fixture.slabId});
      final committed = result.project.index.slab(fixture.slabId)!;
      expect(committed.id, fixture.slabId);
      expect(committed.bottomElevationMm, 2980);
      expect(committed.topElevationMm, 3200);
      expect(committed.thicknessMm, 220);
      expect(committed.materialId, 'reinforced-concrete-c30');
    });

    test('remove releases level slab indexes and participates in undo redo', () {
      final fixture = _Fixture();
      final slab = fixture.slab();
      final session = ProjectMutationSession(
        fixture.project(slabs: {slab.id: slab}),
      );

      final removed = session.commit(
        ProjectMutationRequest(
          expectedVersion: session.current.version,
          command: RemoveSlabCommand(slabId: fixture.slabId),
        ),
      );

      expect(removed, isNotNull);
      expect(removed!.changeSet.removedEntityIds, {fixture.slabId});
      expect(removed.project.index.slabsForLevel(fixture.lowerLevelId), isEmpty);
      expect(removed.project.index.slabsForLevel(fixture.upperLevelId), isEmpty);

      final undo = session.undo(session.current.version);
      expect(undo, isNotNull);
      expect(undo!.changeSet.addedEntityIds, {fixture.slabId});
      expect(undo.project.index.slab(fixture.slabId), isNotNull);

      final redo = session.redo(session.current.version);
      expect(redo, isNotNull);
      expect(redo!.changeSet.removedEntityIds, {fixture.slabId});
      expect(redo.project.index.slab(fixture.slabId), isNull);
    });

    test('create rejects duplicate SlabId before aggregate mutation', () {
      final fixture = _Fixture();
      final slab = fixture.slab();
      final project = fixture.project(slabs: {slab.id: slab});

      expect(
        () => CreateSlabCommand(slab: slab).buildCandidate(project),
        throwsA(
          isA<ProjectAuthoringException>().having(
            (error) => error.code,
            'code',
            ProjectAuthoringIssueCode.slabAlreadyExists,
          ),
        ),
      );
    });

    test('update and remove reject unknown SlabId', () {
      final fixture = _Fixture();
      final project = fixture.project();

      expect(
        () => UpdateSlabCommand(slab: fixture.slab()).buildCandidate(project),
        throwsA(
          isA<ProjectAuthoringException>().having(
            (error) => error.code,
            'code',
            ProjectAuthoringIssueCode.slabNotFound,
          ),
        ),
      );
      expect(
        () => RemoveSlabCommand(slabId: fixture.slabId)
            .buildCandidate(project),
        throwsA(
          isA<ProjectAuthoringException>().having(
            (error) => error.code,
            'code',
            ProjectAuthoringIssueCode.slabNotFound,
          ),
        ),
      );
    });

    test('stale expected version rejects slab mutation', () {
      final fixture = _Fixture();
      final session = ProjectMutationSession(fixture.project());
      session.commit(
        ProjectMutationRequest(
          expectedVersion: session.current.version,
          command: CreateSlabCommand(slab: fixture.slab()),
        ),
      );

      expect(
        () => session.commit(
          ProjectMutationRequest(
            expectedVersion: LocalProjectVersion(0),
            command: RemoveSlabCommand(slabId: fixture.slabId),
          ),
        ),
        throwsA(isA<StaleProjectMutationException>()),
      );
    });
  });
}

final class _Fixture {
  final ProjectId projectId = ProjectId('project');
  final SiteId siteId = SiteId('site');
  final BuildingId buildingId = BuildingId('building');
  final LevelId lowerLevelId = LevelId('level-01');
  final LevelId upperLevelId = LevelId('level-02');
  final SlabId slabId = SlabId('slab-01-02');

  ProjectSlab slab({
    int bottomElevationMm = 3000,
    int thicknessMm = 200,
    String materialId = 'reinforced-concrete',
  }) =>
      ProjectSlab(
        id: slabId,
        buildingId: buildingId,
        kind: SlabKind.interLevel,
        belowLevelId: lowerLevelId,
        aboveLevelId: upperLevelId,
        bottomElevationMm: bottomElevationMm,
        thicknessMm: thicknessMm,
        materialId: materialId,
        footprint: const [
          BoundaryPointMm(xMm: 0, yMm: 0),
          BoundaryPointMm(xMm: 6000, yMm: 0),
          BoundaryPointMm(xMm: 6000, yMm: 4000),
          BoundaryPointMm(xMm: 0, yMm: 4000),
        ],
      );

  ProjectAggregateRoot project({
    Map<SlabId, ProjectSlab> slabs = const {},
  }) =>
      ProjectAggregateRoot(
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
              levelIds: [lowerLevelId, upperLevelId],
            ),
          },
          levels: {
            lowerLevelId: ProjectLevelEntity(
              id: lowerLevelId,
              buildingId: buildingId,
              name: 'Level 1',
              levelNumber: 1,
              elevationMm: 0,
            ),
            upperLevelId: ProjectLevelEntity(
              id: upperLevelId,
              buildingId: buildingId,
              name: 'Level 2',
              levelNumber: 2,
              elevationMm: 3200,
            ),
          },
          slabs: slabs,
        ),
      );
}
