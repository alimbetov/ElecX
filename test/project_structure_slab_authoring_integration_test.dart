import 'dart:math';

import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_structure_authoring.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/slab_topology.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('project structure session and slab authoring share one mutation history',
      () {
    final fixture = _Fixture();
    final authoring = ProjectStructureAuthoringSession(
      mutations: ProjectMutationSession(fixture.project()),
      idFactory: SecureRandomEntityIdFactory(random: Random(81)),
    );

    final created = authoring.slabAuthoring.create(
      CreateSlabRequest(
        buildingId: fixture.buildingId,
        kind: SlabKind.interLevel,
        belowLevelId: fixture.lowerLevelId,
        aboveLevelId: fixture.upperLevelId,
        bottomElevationMm: 3000,
        thicknessMm: 200,
        materialId: 'reinforced-concrete',
        footprint: _rectangle,
      ),
    );

    expect(authoring.project.version, LocalProjectVersion(1));
    expect(authoring.project.index.slab(created.slabId), isNotNull);
    expect(authoring.canUndoCanonicalMutation, isTrue);

    final undo = authoring.undoCanonicalMutation();
    expect(undo, isNotNull);
    expect(authoring.project.version, LocalProjectVersion(2));
    expect(authoring.project.index.slab(created.slabId), isNull);
    expect(authoring.canRedoCanonicalMutation, isTrue);

    final redo = authoring.redoCanonicalMutation();
    expect(redo, isNotNull);
    expect(authoring.project.version, LocalProjectVersion(3));
    expect(authoring.project.index.slab(created.slabId), isNotNull);
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

const _rectangle = <BoundaryPointMm>[
  BoundaryPointMm(xMm: 0, yMm: 0),
  BoundaryPointMm(xMm: 6000, yMm: 0),
  BoundaryPointMm(xMm: 6000, yMm: 4000),
  BoundaryPointMm(xMm: 0, yMm: 4000),
];
