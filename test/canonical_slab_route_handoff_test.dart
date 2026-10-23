import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/canonical_slab_route_handoff.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/slab_topology.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CanonicalSlabRouteHandoffPlanner', () {
    test('upward handoff binds lower ceiling to upper floor through one SlabId',
        () {
      final fixture = _Fixture();

      final plan = CanonicalSlabRouteHandoffPlanner.resolve(
        project: fixture.project,
        fromSpaceId: fixture.lowerSpaceId,
        toSpaceId: fixture.upperSpaceId,
      );

      expect(plan, isNotNull);
      expect(plan!.slabId, fixture.slabId);
      expect(plan.direction, CanonicalSlabRouteHandoffDirection.upward);
      expect(plan.fromLevelId, fixture.lowerLevelId);
      expect(plan.toLevelId, fixture.upperLevelId);
      expect(
          plan.fromSurface, RoomSurfaceRef.ceiling(fixture.lowerSpaceId.value));
      expect(plan.toSurface, RoomSurfaceRef.floor(fixture.upperSpaceId.value));
      expect(plan.entryFace, fixture.slab.belowFace);
      expect(plan.exitFace, fixture.slab.aboveFace);
      expect(plan.isUpward, isTrue);
    });

    test('downward handoff reverses surfaces and stable slab faces', () {
      final fixture = _Fixture();

      final plan = CanonicalSlabRouteHandoffPlanner.resolve(
        project: fixture.project,
        fromSpaceId: fixture.upperSpaceId,
        toSpaceId: fixture.lowerSpaceId,
      );

      expect(plan, isNotNull);
      expect(plan!.slabId, fixture.slabId);
      expect(plan.direction, CanonicalSlabRouteHandoffDirection.downward);
      expect(
          plan.fromSurface, RoomSurfaceRef.floor(fixture.upperSpaceId.value));
      expect(
          plan.toSurface, RoomSurfaceRef.ceiling(fixture.lowerSpaceId.value));
      expect(plan.entryFace, fixture.slab.aboveFace);
      expect(plan.exitFace, fixture.slab.belowFace);
      expect(plan.isUpward, isFalse);
    });

    test('fails closed when no physical slab owns the level pair', () {
      final fixture = _Fixture(includeSlab: false);

      expect(
        CanonicalSlabRouteHandoffPlanner.resolve(
          project: fixture.project,
          fromSpaceId: fixture.lowerSpaceId,
          toSpaceId: fixture.upperSpaceId,
        ),
        isNull,
      );
    });

    test('fails closed for two spaces on the same canonical level', () {
      final fixture = _Fixture(includePeerSpace: true);

      expect(
        CanonicalSlabRouteHandoffPlanner.resolve(
          project: fixture.project,
          fromSpaceId: fixture.lowerSpaceId,
          toSpaceId: fixture.peerSpaceId,
        ),
        isNull,
      );
    });

    test('fails closed when either canonical space does not exist', () {
      final fixture = _Fixture();

      expect(
        CanonicalSlabRouteHandoffPlanner.resolve(
          project: fixture.project,
          fromSpaceId: fixture.lowerSpaceId,
          toSpaceId: SpaceId('missing-space'),
        ),
        isNull,
      );
    });
  });
}

final class _Fixture {
  _Fixture({this.includeSlab = true, this.includePeerSpace = false}) {
    slab = ProjectSlab(
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
    project = _project();
  }

  final bool includeSlab;
  final bool includePeerSpace;

  final ProjectId projectId = ProjectId('project');
  final SiteId siteId = SiteId('site');
  final BuildingId buildingId = BuildingId('building');
  final LevelId lowerLevelId = LevelId('level-01');
  final LevelId upperLevelId = LevelId('level-02');
  final SpaceId lowerSpaceId = SpaceId('space-l1');
  final SpaceId peerSpaceId = SpaceId('space-l1-peer');
  final SpaceId upperSpaceId = SpaceId('space-l2');
  final SlabId slabId = SlabId('slab-01-02');

  late final ProjectSlab slab;
  late final ProjectAggregateRoot project;

  ProjectAggregateRoot _project() {
    final lowerSpaces = <SpaceId>[lowerSpaceId];
    final spaces = <SpaceId, ProjectSpaceEntity>{
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
    };
    if (includePeerSpace) {
      lowerSpaces.add(peerSpaceId);
      spaces[peerSpaceId] = ProjectSpaceEntity(
        id: peerSpaceId,
        levelId: lowerLevelId,
        name: 'Lower peer room',
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
            spaceIds: lowerSpaces,
          ),
          upperLevelId: ProjectLevelEntity(
            id: upperLevelId,
            buildingId: buildingId,
            name: 'Level 2',
            levelNumber: 2,
            elevationMm: 3200,
            spaceIds: [upperSpaceId],
          ),
        },
        slabs: includeSlab ? {slabId: slab} : const {},
        spaces: spaces,
      ),
    );
  }
}
