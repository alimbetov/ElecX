import 'dart:math';

import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_slab_authoring.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/slab_topology.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProjectSlabAuthoringSession', () {
    test('allocates SlabId and commits canonical physical slab', () {
      final fixture = _Fixture();
      final mutations = ProjectMutationSession(fixture.project());
      final authoring = ProjectSlabAuthoringSession(
        mutations: mutations,
        idFactory: SecureRandomEntityIdFactory(random: Random(71)),
      );

      final result = authoring.create(
        fixture.createRequest(),
        expectedVersion: LocalProjectVersion(0),
      );

      expect(result.slabId, isA<SlabId>());
      expect(result.project.version, LocalProjectVersion(1));
      expect(result.changeSet.addedEntityIds, {result.slabId});
      final slab = result.project.index.slab(result.slabId)!;
      expect(slab.belowLevelId, fixture.lowerLevelId);
      expect(slab.aboveLevelId, fixture.upperLevelId);
      expect(slab.bottomElevationMm, 3000);
      expect(slab.topElevationMm, 3200);
    });

    test('update keeps SlabId and commits construction change', () {
      final fixture = _Fixture();
      final mutations = ProjectMutationSession(fixture.project());
      final authoring = ProjectSlabAuthoringSession(
        mutations: mutations,
        idFactory: SecureRandomEntityIdFactory(random: Random(72)),
      );
      final created = authoring.create(fixture.createRequest());

      final updated = authoring.update(
        UpdateSlabRequest(
          slabId: created.slabId,
          buildingId: fixture.buildingId,
          kind: SlabKind.interLevel,
          belowLevelId: fixture.lowerLevelId,
          aboveLevelId: fixture.upperLevelId,
          bottomElevationMm: 2980,
          thicknessMm: 220,
          materialId: 'reinforced-concrete-c30',
          footprint: _rectangle,
        ),
        expectedVersion: LocalProjectVersion(1),
      );

      expect(updated.slabId, created.slabId);
      expect(updated.changeSet.updatedEntityIds, {created.slabId});
      final slab = updated.project.index.slab(created.slabId)!;
      expect(slab.bottomElevationMm, 2980);
      expect(slab.topElevationMm, 3200);
      expect(slab.thicknessMm, 220);
    });

    test('remove commits SlabId deletion and leaves levels intact', () {
      final fixture = _Fixture();
      final mutations = ProjectMutationSession(fixture.project());
      final authoring = ProjectSlabAuthoringSession(
        mutations: mutations,
        idFactory: SecureRandomEntityIdFactory(random: Random(73)),
      );
      final created = authoring.create(fixture.createRequest());

      final removed = authoring.remove(
        created.slabId,
        expectedVersion: LocalProjectVersion(1),
      );

      expect(removed.changeSet.removedEntityIds, {created.slabId});
      expect(removed.project.index.slab(created.slabId), isNull);
      expect(removed.project.index.level(fixture.lowerLevelId), isNotNull);
      expect(removed.project.index.level(fixture.upperLevelId), isNotNull);
    });

    test('stale slab authoring context fails closed', () {
      final fixture = _Fixture();
      final mutations = ProjectMutationSession(fixture.project());
      final authoring = ProjectSlabAuthoringSession(
        mutations: mutations,
        idFactory: SecureRandomEntityIdFactory(random: Random(74)),
      );
      authoring.create(fixture.createRequest());

      expect(
        () => authoring.remove(
          mutations.current.stores.slabs.keys.single,
          expectedVersion: LocalProjectVersion(0),
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

  CreateSlabRequest createRequest() => CreateSlabRequest(
        buildingId: buildingId,
        kind: SlabKind.interLevel,
        belowLevelId: lowerLevelId,
        aboveLevelId: upperLevelId,
        bottomElevationMm: 3000,
        thicknessMm: 200,
        materialId: 'reinforced-concrete',
        footprint: _rectangle,
      );

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
        ),
      );
}

const _rectangle = <BoundaryPointMm>[
  BoundaryPointMm(xMm: 0, yMm: 0),
  BoundaryPointMm(xMm: 6000, yMm: 0),
  BoundaryPointMm(xMm: 6000, yMm: 4000),
  BoundaryPointMm(xMm: 0, yMm: 4000),
];
