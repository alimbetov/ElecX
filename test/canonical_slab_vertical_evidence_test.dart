import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/canonical_slab_route_handoff.dart';
import 'package:elecx/src/domain/canonical_slab_vertical_evidence.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/slab_topology.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CanonicalSlabVerticalEvidenceResolver', () {
    test('proves exact upward ceiling to slab to upper floor Z geometry', () {
      final fixture = _Fixture();
      final plan = fixture.upwardPlan;

      final evidence = CanonicalSlabVerticalEvidenceResolver.resolve(
        project: fixture.project,
        plan: plan,
        fromLevelElevationMm: 0,
        toLevelElevationMm: 3200,
        fromRoomHeightMm: 3000,
        toRoomHeightMm: 3000,
      );

      expect(evidence, isNotNull);
      expect(evidence!.slabId, fixture.slabId);
      expect(evidence.physicalGapMm, 200);
      expect(evidence.slabThicknessMm, 200);
    });

    test('proves reverse floor to ceiling using the same slab geometry', () {
      final fixture = _Fixture();
      final plan = CanonicalSlabRouteHandoffPlanner.resolve(
        project: fixture.project,
        fromSpaceId: fixture.upperSpaceId,
        toSpaceId: fixture.lowerSpaceId,
      )!;

      final evidence = CanonicalSlabVerticalEvidenceResolver.resolve(
        project: fixture.project,
        plan: plan,
        fromLevelElevationMm: 3200,
        toLevelElevationMm: 0,
        fromRoomHeightMm: 3000,
        toRoomHeightMm: 3000,
      );

      expect(evidence, isNotNull);
      expect(evidence!.slabId, fixture.slabId);
      expect(evidence.physicalGapMm, 200);
    });

    test('fails closed when a historical 3000 mm assumption is physically wrong',
        () {
      final fixture = _Fixture(
        slabBottomElevationMm: 3100,
        upperLevelElevationMm: 3300,
      );

      expect(
        CanonicalSlabVerticalEvidenceResolver.resolve(
          project: fixture.project,
          plan: fixture.upwardPlan,
          fromLevelElevationMm: 0,
          toLevelElevationMm: 3300,
          fromRoomHeightMm: 3000,
          toRoomHeightMm: 3000,
        ),
        isNull,
      );

      final proven = CanonicalSlabVerticalEvidenceResolver.resolve(
        project: fixture.project,
        plan: fixture.upwardPlan,
        fromLevelElevationMm: 0,
        toLevelElevationMm: 3300,
        fromRoomHeightMm: 3100,
        toRoomHeightMm: 3000,
      );
      expect(proven, isNotNull);
      expect(proven!.physicalGapMm, 200);
    });

    test('fails closed when materialized level elevation drifts from canonical',
        () {
      final fixture = _Fixture();

      expect(
        CanonicalSlabVerticalEvidenceResolver.resolve(
          project: fixture.project,
          plan: fixture.upwardPlan,
          fromLevelElevationMm: 0,
          toLevelElevationMm: 3210,
          fromRoomHeightMm: 3000,
          toRoomHeightMm: 3000,
        ),
        isNull,
      );
    });

    test('permits bounded integer-mm projection tolerance only', () {
      final fixture = _Fixture();

      final evidence = CanonicalSlabVerticalEvidenceResolver.resolve(
        project: fixture.project,
        plan: fixture.upwardPlan,
        fromLevelElevationMm: 1,
        toLevelElevationMm: 3201,
        fromRoomHeightMm: 2999,
        toRoomHeightMm: 3000,
        verticalToleranceMm: 2,
      );

      expect(evidence, isNotNull);
      expect(evidence!.physicalGapMm, 201);
    });
  });
}

final class _Fixture {
  _Fixture({
    this.slabBottomElevationMm = 3000,
    this.upperLevelElevationMm = 3200,
  }) {
    final slab = ProjectSlab(
      id: slabId,
      buildingId: buildingId,
      kind: SlabKind.interLevel,
      belowLevelId: lowerLevelId,
      aboveLevelId: upperLevelId,
      bottomElevationMm: slabBottomElevationMm,
      thicknessMm: 200,
      materialId: 'reinforced-concrete',
      footprint: const [
        BoundaryPointMm(xMm: 0, yMm: 0),
        BoundaryPointMm(xMm: 6000, yMm: 0),
        BoundaryPointMm(xMm: 6000, yMm: 4000),
        BoundaryPointMm(xMm: 0, yMm: 4000),
      ],
    );
    project = ProjectAggregateRoot(
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
            name: 'Lower',
            levelNumber: 1,
            elevationMm: 0,
            spaceIds: [lowerSpaceId],
          ),
          upperLevelId: ProjectLevelEntity(
            id: upperLevelId,
            buildingId: buildingId,
            name: 'Upper',
            levelNumber: 2,
            elevationMm: upperLevelElevationMm,
            spaceIds: [upperSpaceId],
          ),
        },
        slabs: {slabId: slab},
        spaces: {
          lowerSpaceId: ProjectSpaceEntity(
            id: lowerSpaceId,
            levelId: lowerLevelId,
            name: 'Lower room',
          ),
          upperSpaceId: ProjectSpaceEntity(
            id: upperSpaceId,
            levelId: upperLevelId,
            name: 'Upper room',
          ),
        },
      ),
    );
  }

  final int slabBottomElevationMm;
  final int upperLevelElevationMm;

  final ProjectId projectId = ProjectId('project');
  final SiteId siteId = SiteId('site');
  final BuildingId buildingId = BuildingId('building');
  final LevelId lowerLevelId = LevelId('level-01');
  final LevelId upperLevelId = LevelId('level-02');
  final SpaceId lowerSpaceId = SpaceId('space-l1');
  final SpaceId upperSpaceId = SpaceId('space-l2');
  final SlabId slabId = SlabId('slab-01-02');

  late final ProjectAggregateRoot project;

  CanonicalSlabRouteHandoffPlan get upwardPlan =>
      CanonicalSlabRouteHandoffPlanner.resolve(
        project: project,
        fromSpaceId: lowerSpaceId,
        toSpaceId: upperSpaceId,
      )!;
}
