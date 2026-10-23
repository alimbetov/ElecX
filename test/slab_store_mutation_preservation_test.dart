import 'package:elecx/src/application/project/project_authoring_error.dart';
import 'package:elecx/src/application/project/project_building_commands.dart';
import 'package:elecx/src/application/project/project_destructive_commands.dart';
import 'package:elecx/src/application/project/project_level_commands.dart';
import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_space_commands.dart';
import 'package:elecx/src/application/project/project_space_semantics_commands.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_space_semantics.dart';
import 'package:elecx/src/domain/slab_topology.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('slab store mutation preservation', () {
    test('building mutations preserve pre-existing slab store', () {
      final fixture = _Fixture();
      final project = fixture.project();

      _expectSlabPreserved(
        project,
        RenameBuildingCommand(
          buildingId: fixture.buildingId,
          name: 'Renamed building',
        ),
        fixture.slab,
      );
      _expectSlabPreserved(
        project,
        CreateBuildingCommand(
          buildingId: BuildingId('building-new'),
          name: 'New building',
        ),
        fixture.slab,
      );
    });

    test('level mutations preserve pre-existing slab store', () {
      final fixture = _Fixture();
      final project = fixture.project();

      _expectSlabPreserved(
        project,
        RenameLevelCommand(
          levelId: fixture.lowerLevelId,
          name: 'Renamed level',
        ),
        fixture.slab,
      );
      _expectSlabPreserved(
        project,
        RenumberLevelCommand(
          levelId: fixture.lowerLevelId,
          levelNumber: 10,
        ),
        fixture.slab,
      );
      _expectSlabPreserved(
        project,
        ReorderLevelCommand(
          levelId: fixture.lowerLevelId,
          displayOrder: 9,
        ),
        fixture.slab,
      );
      _expectSlabPreserved(
        project,
        CreateLevelCommand(
          levelId: LevelId('level-03'),
          buildingId: fixture.buildingId,
          name: 'Level 3',
          levelNumber: 3,
          elevationMm: 6400,
        ),
        fixture.slab,
      );
    });

    test('space and semantic mutations preserve pre-existing slab store', () {
      final fixture = _Fixture(includeSpace: true);
      final project = fixture.project();

      _expectSlabPreserved(
        project,
        RenameSpaceCommand(
          spaceId: fixture.spaceId,
          name: 'Renamed room',
        ),
        fixture.slab,
      );
      _expectSlabPreserved(
        project,
        SetSpaceUsageCommand(
          spaceId: fixture.spaceId,
          usage: SpaceUsage.livingRoom,
        ),
        fixture.slab,
      );
      _expectSlabPreserved(
        project,
        CreateSpaceCommand(
          spaceId: SpaceId('space-new'),
          levelId: fixture.lowerLevelId,
          name: 'New room',
        ),
        fixture.slab,
      );
      _expectSlabPreserved(
        project,
        RemoveSpaceCommand(spaceId: fixture.spaceId),
        fixture.slab,
      );
    });

    test('level removal fails closed while a physical slab references it', () {
      final fixture = _Fixture();
      final project = fixture.project();

      expect(
        () => RemoveLevelCommand(levelId: fixture.lowerLevelId)
            .buildCandidate(project),
        throwsA(
          isA<ProjectAuthoringException>()
              .having(
                (error) => error.code,
                'code',
                ProjectAuthoringIssueCode.levelHasPhysicalSlabs,
              )
              .having(
                (error) => error.blockingEntityIds,
                'blocking slab ids',
                contains(fixture.slabId),
              ),
        ),
      );
    });
  });
}

void _expectSlabPreserved(
  ProjectAggregateRoot project,
  ProjectCommand command,
  ProjectSlab slab,
) {
  final candidate = command.buildCandidate(project);
  final nextStores = candidate.resolveState(project).stores;

  expect(nextStores.slabs, hasLength(1));
  expect(nextStores.slabs[slab.id], same(slab));
}

final class _Fixture {
  _Fixture({this.includeSpace = false});

  final bool includeSpace;
  final ProjectId projectId = ProjectId('project');
  final SiteId siteId = SiteId('site');
  final BuildingId buildingId = BuildingId('building');
  final LevelId lowerLevelId = LevelId('level-01');
  final LevelId upperLevelId = LevelId('level-02');
  final SpaceId spaceId = SpaceId('space-l1');
  final SlabId slabId = SlabId('slab-01-02');

  late final ProjectSlab slab = ProjectSlab(
    id: slabId,
    buildingId: buildingId,
    kind: SlabKind.interLevel,
    belowLevelId: lowerLevelId,
    aboveLevelId: upperLevelId,
    bottomElevationMm: 3000,
    thicknessMm: 200,
    materialId: 'reinforced-concrete',
    footprint: const [
      BoundaryPointMm(xMm: 0, yMm: 0),
      BoundaryPointMm(xMm: 6000, yMm: 0),
      BoundaryPointMm(xMm: 6000, yMm: 4000),
      BoundaryPointMm(xMm: 0, yMm: 4000),
    ],
  );

  ProjectAggregateRoot project() {
    final currentSlab = slab;
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
            spaceIds: includeSpace ? [spaceId] : const <SpaceId>[],
          ),
          upperLevelId: ProjectLevelEntity(
            id: upperLevelId,
            buildingId: buildingId,
            name: 'Level 2',
            levelNumber: 2,
            elevationMm: 3200,
          ),
        },
        slabs: {currentSlab.id: currentSlab},
        spaces: includeSpace
            ? {
                spaceId: ProjectSpaceEntity(
                  id: spaceId,
                  levelId: lowerLevelId,
                  name: 'Room',
                ),
              }
            : const {},
      ),
    );
  }
}
