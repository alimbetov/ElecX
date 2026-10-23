import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/slab_topology.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('canonical slab aggregate integration', () {
    test('indexes one inter-level slab by identity, building and both levels',
        () {
      final fixture = _SlabAggregateFixture();
      final project = fixture.projectWith(
        slabs: {fixture.slab.id: fixture.slab},
      );

      expect(project.index.slab(fixture.slab.id), same(fixture.slab));
      expect(
        project.index.slabsForBuilding(fixture.buildingId),
        {fixture.slab.id},
      );
      expect(
        project.index.slabsForLevel(fixture.lowerLevelId),
        {fixture.slab.id},
      );
      expect(
        project.index.slabsForLevel(fixture.upperLevelId),
        {fixture.slab.id},
      );
      expect(project.index.isConsistentWith(project.stores), isTrue);
    });

    test('rejects slab whose building does not exist', () {
      final fixture = _SlabAggregateFixture();
      final slab = ProjectSlab(
        id: SlabId('slab-missing-building'),
        buildingId: BuildingId('missing-building'),
        kind: SlabKind.interLevel,
        belowLevelId: fixture.lowerLevelId,
        aboveLevelId: fixture.upperLevelId,
        bottomElevationMm: 3000,
        thicknessMm: 200,
        materialId: 'reinforced-concrete',
        footprint: _rectangle,
      );

      expect(
        () => fixture.projectWith(slabs: {slab.id: slab}),
        _throwsIssue(ProjectAggregateIssueCode.danglingSlabBuilding),
      );
    });

    test('rejects slab with missing adjacent level', () {
      final fixture = _SlabAggregateFixture();
      final slab = ProjectSlab(
        id: SlabId('slab-missing-level'),
        buildingId: fixture.buildingId,
        kind: SlabKind.interLevel,
        belowLevelId: fixture.lowerLevelId,
        aboveLevelId: LevelId('missing-level'),
        bottomElevationMm: 3000,
        thicknessMm: 200,
        materialId: 'reinforced-concrete',
        footprint: _rectangle,
      );

      expect(
        () => fixture.projectWith(slabs: {slab.id: slab}),
        _throwsIssue(ProjectAggregateIssueCode.danglingSlabLevel),
      );
    });

    test('rejects slab level owned by another building', () {
      final fixture = _SlabAggregateFixture(withSecondBuilding: true);
      final slab = ProjectSlab(
        id: SlabId('slab-cross-building'),
        buildingId: fixture.buildingId,
        kind: SlabKind.interLevel,
        belowLevelId: fixture.lowerLevelId,
        aboveLevelId: fixture.otherBuildingLevelId,
        bottomElevationMm: 3000,
        thicknessMm: 200,
        materialId: 'reinforced-concrete',
        footprint: _rectangle,
      );

      expect(
        () => fixture.projectWith(slabs: {slab.id: slab}),
        _throwsIssue(ProjectAggregateIssueCode.slabLevelBuildingMismatch),
      );
    });

    test('rejects inverted canonical level order', () {
      final fixture = _SlabAggregateFixture(invertElevations: true);

      expect(
        () => fixture.projectWith(slabs: {fixture.slab.id: fixture.slab}),
        _throwsIssue(ProjectAggregateIssueCode.slabLevelOrderMismatch),
      );
    });

    test('rejects duplicate physical level-side pair', () {
      final fixture = _SlabAggregateFixture();
      final duplicate = ProjectSlab(
        id: SlabId('slab-duplicate'),
        buildingId: fixture.buildingId,
        kind: SlabKind.interLevel,
        belowLevelId: fixture.lowerLevelId,
        aboveLevelId: fixture.upperLevelId,
        bottomElevationMm: 3000,
        thicknessMm: 250,
        materialId: 'reinforced-concrete',
        footprint: _rectangle,
      );

      expect(
        () => fixture.projectWith(
          slabs: {
            fixture.slab.id: fixture.slab,
            duplicate.id: duplicate,
          },
        ),
        _throwsIssue(ProjectAggregateIssueCode.invalidSlabTopology),
      );
    });
  });
}

Matcher _throwsIssue(ProjectAggregateIssueCode code) => throwsA(
      isA<ProjectAggregateValidationException>().having(
        (error) => error.issues.map((issue) => issue.code),
        'issue codes',
        contains(code),
      ),
    );

final class _SlabAggregateFixture {
  _SlabAggregateFixture({
    this.withSecondBuilding = false,
    this.invertElevations = false,
  });

  final bool withSecondBuilding;
  final bool invertElevations;

  final ProjectId projectId = ProjectId('project');
  final SiteId siteId = SiteId('site');
  final BuildingId buildingId = BuildingId('building-a');
  final BuildingId otherBuildingId = BuildingId('building-b');
  final LevelId lowerLevelId = LevelId('level-01');
  final LevelId upperLevelId = LevelId('level-02');
  final LevelId otherBuildingLevelId = LevelId('level-b-02');

  late final ProjectSlab slab = ProjectSlab(
    id: SlabId('slab-01-02'),
    buildingId: buildingId,
    kind: SlabKind.interLevel,
    belowLevelId: lowerLevelId,
    aboveLevelId: upperLevelId,
    bottomElevationMm: 3000,
    thicknessMm: 200,
    materialId: 'reinforced-concrete',
    footprint: _rectangle,
  );

  ProjectAggregateRoot projectWith({
    Map<SlabId, ProjectSlab> slabs = const {},
  }) {
    final buildings = <BuildingId, ProjectBuildingEntity>{
      buildingId: ProjectBuildingEntity(
        id: buildingId,
        siteId: siteId,
        name: 'Building A',
        levelIds: [lowerLevelId, upperLevelId],
      ),
    };
    final levels = <LevelId, ProjectLevelEntity>{
      lowerLevelId: ProjectLevelEntity(
        id: lowerLevelId,
        buildingId: buildingId,
        name: 'Level 1',
        levelNumber: 1,
        elevationMm: invertElevations ? 3200 : 0,
      ),
      upperLevelId: ProjectLevelEntity(
        id: upperLevelId,
        buildingId: buildingId,
        name: 'Level 2',
        levelNumber: 2,
        elevationMm: invertElevations ? 0 : 3200,
      ),
    };
    final siteBuildings = <BuildingId>[buildingId];
    if (withSecondBuilding) {
      siteBuildings.add(otherBuildingId);
      buildings[otherBuildingId] = ProjectBuildingEntity(
        id: otherBuildingId,
        siteId: siteId,
        name: 'Building B',
        levelIds: [otherBuildingLevelId],
      );
      levels[otherBuildingLevelId] = ProjectLevelEntity(
        id: otherBuildingLevelId,
        buildingId: otherBuildingId,
        name: 'Building B Level 2',
        levelNumber: 2,
        elevationMm: 3200,
      );
    }

    return ProjectAggregateRoot(
      id: projectId,
      siteId: siteId,
      version: LocalProjectVersion(0),
      stores: ProjectEntityStores(
        sites: {
          siteId: ProjectSiteEntity(
            id: siteId,
            name: 'Site',
            buildingIds: siteBuildings,
          ),
        },
        buildings: buildings,
        levels: levels,
        slabs: slabs,
      ),
    );
  }
}

const _rectangle = <BoundaryPointMm>[
  BoundaryPointMm(xMm: 0, yMm: 0),
  BoundaryPointMm(xMm: 6000, yMm: 0),
  BoundaryPointMm(xMm: 6000, yMm: 4000),
  BoundaryPointMm(xMm: 0, yMm: 4000),
];
