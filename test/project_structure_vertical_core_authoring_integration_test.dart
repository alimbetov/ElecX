import 'dart:math';

import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_structure_authoring.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/slab_topology.dart';
import 'package:elecx/src/domain/vertical_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('slab and VerticalCore authoring share one canonical history', () {
    final fixture = _Fixture();
    final authoring = ProjectStructureAuthoringSession(
      mutations: ProjectMutationSession(fixture.project()),
      idFactory: SecureRandomEntityIdFactory(random: Random(91)),
    );

    final slab = authoring.slabAuthoring.create(
      CreateSlabRequest(
        buildingId: fixture.buildingId,
        kind: SlabKind.interLevel,
        belowLevelId: fixture.lowerLevelId,
        aboveLevelId: fixture.upperLevelId,
        bottomElevationMm: 3000,
        thicknessMm: 200,
        materialId: 'reinforced-concrete',
        footprint: _buildingFootprint,
      ),
    );
    final core = authoring.verticalCoreAuthoring.create(
      CreateVerticalCoreRequest(
        buildingId: fixture.buildingId,
        kind: VerticalCoreKind.riser,
        levelIds: {fixture.lowerLevelId, fixture.upperLevelId},
        footprint: _coreFootprint,
        name: 'Main riser',
      ),
    );

    expect(authoring.project.version, LocalProjectVersion(2));
    expect(authoring.project.index.slab(slab.slabId), isNotNull);
    expect(
        authoring.project.index.verticalCore(core.verticalCoreId), isNotNull);

    final undoCore = authoring.undoCanonicalMutation();
    expect(undoCore, isNotNull);
    expect(authoring.project.version, LocalProjectVersion(3));
    expect(authoring.project.index.verticalCore(core.verticalCoreId), isNull);
    expect(authoring.project.index.slab(slab.slabId), isNotNull);

    final undoSlab = authoring.undoCanonicalMutation();
    expect(undoSlab, isNotNull);
    expect(authoring.project.version, LocalProjectVersion(4));
    expect(authoring.project.index.slab(slab.slabId), isNull);

    final redoSlab = authoring.redoCanonicalMutation();
    expect(redoSlab, isNotNull);
    expect(authoring.project.index.slab(slab.slabId), isNotNull);

    final redoCore = authoring.redoCanonicalMutation();
    expect(redoCore, isNotNull);
    expect(
        authoring.project.index.verticalCore(core.verticalCoreId), isNotNull);
  });
}

final class _Fixture {
  final ProjectId projectId = ProjectId('project');
  final SiteId siteId = SiteId('site');
  final BuildingId buildingId = BuildingId('building');
  final LevelId lowerLevelId = LevelId('level-01');
  final LevelId upperLevelId = LevelId('level-02');

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

const _buildingFootprint = <BoundaryPointMm>[
  BoundaryPointMm(xMm: 0, yMm: 0),
  BoundaryPointMm(xMm: 6000, yMm: 0),
  BoundaryPointMm(xMm: 6000, yMm: 4000),
  BoundaryPointMm(xMm: 0, yMm: 4000),
];

const _coreFootprint = <BoundaryPointMm>[
  BoundaryPointMm(xMm: 1000, yMm: 1000),
  BoundaryPointMm(xMm: 1400, yMm: 1000),
  BoundaryPointMm(xMm: 1400, yMm: 1400),
  BoundaryPointMm(xMm: 1000, yMm: 1400),
];
