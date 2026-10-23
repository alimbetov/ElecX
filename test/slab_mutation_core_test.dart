import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_entity_stores_copy.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/slab_topology.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SlabId mutation core', () {
    test('entity diff detects slab add update and remove', () {
      final fixture = _Fixture();
      final empty = fixture.project().stores;
      final slab = fixture.slab();
      final added = empty.copyWith(slabs: {slab.id: slab});
      final changedSlab = fixture.slab(thicknessMm: 240);
      final changed = empty.copyWith(slabs: {changedSlab.id: changedSlab});

      final addDiff = ProjectEntityDiff.between(empty, added);
      expect(addDiff.addedEntityIds, {fixture.slabId});
      expect(addDiff.updatedEntityIds, isEmpty);
      expect(addDiff.removedEntityIds, isEmpty);

      final updateDiff = ProjectEntityDiff.between(added, changed);
      expect(updateDiff.addedEntityIds, isEmpty);
      expect(updateDiff.updatedEntityIds, {fixture.slabId});
      expect(updateDiff.removedEntityIds, isEmpty);

      final removeDiff = ProjectEntityDiff.between(changed, empty);
      expect(removeDiff.addedEntityIds, isEmpty);
      expect(removeDiff.updatedEntityIds, isEmpty);
      expect(removeDiff.removedEntityIds, {fixture.slabId});
    });

    test('pure slab mutation commits and survives undo redo', () {
      final fixture = _Fixture();
      final session = ProjectMutationSession(fixture.project());
      final slab = fixture.slab();

      final create = session.commit(
        ProjectMutationRequest(
          expectedVersion: session.current.version,
          command: _ReplaceSlabsCommand({slab.id: slab}),
        ),
      );

      expect(create, isNotNull);
      expect(create!.project.version, LocalProjectVersion(1));
      expect(create.changeSet.addedEntityIds, {fixture.slabId});
      expect(create.project.index.slab(fixture.slabId), same(slab));
      expect(session.undoDepth, 1);

      final undo = session.undo(session.current.version);
      expect(undo, isNotNull);
      expect(undo!.project.version, LocalProjectVersion(2));
      expect(undo.changeSet.removedEntityIds, {fixture.slabId});
      expect(undo.project.index.slab(fixture.slabId), isNull);
      expect(session.redoDepth, 1);

      final redo = session.redo(session.current.version);
      expect(redo, isNotNull);
      expect(redo!.project.version, LocalProjectVersion(3));
      expect(redo.changeSet.addedEntityIds, {fixture.slabId});
      expect(redo.project.index.slab(fixture.slabId), isNotNull);
    });

    test('legacy stores-only command cannot erase an existing slab store', () {
      final fixture = _Fixture();
      final slab = fixture.slab();
      final project = fixture.project(slabs: {slab.id: slab});
      final legacyStores = ProjectEntityStores(
        sites: project.stores.sites,
        buildings: project.stores.buildings,
        levels: project.stores.levels,
      );
      final candidate = ProjectCommandCandidate(stores: legacyStores);

      final resolved = candidate.resolveState(project);

      expect(resolved.stores.slabs, hasLength(1));
      expect(resolved.stores.slabs[fixture.slabId], same(slab));
    });
  });
}

final class _ReplaceSlabsCommand implements ProjectCommand {
  const _ReplaceSlabsCommand(this.slabs);

  final Map<SlabId, ProjectSlab> slabs;

  @override
  String get commandType => 'test.slab.replace';

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) =>
      ProjectCommandCandidate.fromState(
        state: ProjectMutableState(
          engineeringMetadata: current.engineeringMetadata,
          stores: current.stores.copyWith(slabs: slabs),
        ),
        affectedEntityIds: slabs.keys,
      );
}

final class _Fixture {
  final ProjectId projectId = ProjectId('project');
  final SiteId siteId = SiteId('site');
  final BuildingId buildingId = BuildingId('building');
  final LevelId lowerLevelId = LevelId('level-01');
  final LevelId upperLevelId = LevelId('level-02');
  final SlabId slabId = SlabId('slab-01-02');

  ProjectSlab slab({int thicknessMm = 200}) => ProjectSlab(
        id: slabId,
        buildingId: buildingId,
        kind: SlabKind.interLevel,
        belowLevelId: lowerLevelId,
        aboveLevelId: upperLevelId,
        bottomElevationMm: 3000,
        thicknessMm: thicknessMm,
        materialId: 'reinforced-concrete',
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
