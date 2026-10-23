import 'package:elecx/src/domain/boundary_penetration.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/canonical_slab_transition_resolver.dart';
import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_model.dart';
import 'package:elecx/src/domain/slab_topology.dart';
import 'package:elecx/src/domain/surface_transition_graph.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CanonicalSlabTransitionResolver', () {
    test('resolves upward ceiling to floor through one stable SlabId', () {
      final fixture = _Fixture();

      final transition = fixture.resolveUp();

      expect(transition, isNotNull);
      expect(transition!.kind, SurfaceTransitionKind.levelPenetration);
      expect(transition.fromSurface, RoomSurfaceRef.ceiling('legacy-l1-room'));
      expect(transition.toSurface, RoomSurfaceRef.floor('legacy-l2-room'));
      expect(transition.requiresPenetration, isTrue);
      expect(
        transition.penetrationRequirement!.hostKind,
        BoundaryPenetrationHostKind.slab,
      );
      expect(
        transition.penetrationRequirement!.slabId,
        SlabId('slab-01-02'),
      );
      expect(transition.penetrationRequirement!.hostThicknessMm, 200);
      expect(
        transition.penetrationRequirement!.materialId,
        'reinforced-concrete',
      );

      final penetration = transition.createPenetration(
        penetrationId: 'p-1',
        routeId: 'C-201',
      );
      expect(penetration.slabId, SlabId('slab-01-02'));
      expect(penetration.hasStableSlabHostIdentity, isTrue);
    });

    test('resolves reverse floor to ceiling through the same SlabId', () {
      final fixture = _Fixture();

      final transition = CanonicalSlabTransitionResolver.resolve(
        project: fixture.project,
        buildingLevels: fixture.legacyLevels,
        fromLevel: fixture.legacyUpper,
        fromSpace: fixture.legacyUpper.spaces.single,
        fromSurface: RoomSurfaceRef.floor('legacy-l2-room'),
        point: const SurfacePointMm(1600, 1200),
        fromRoomHeightMm: 3000,
        toLevel: fixture.legacyLower,
        toSpace: fixture.legacyLower.spaces.single,
        toRoomHeightMm: 3000,
        canonicalSpaceIdResolver: fixture.canonicalSpaceId,
      );

      expect(transition, isNotNull);
      expect(transition!.toSurface, RoomSurfaceRef.ceiling('legacy-l1-room'));
      expect(
        transition.penetrationRequirement!.slabId,
        SlabId('slab-01-02'),
      );
    });

    test('fails closed when canonical project has no slab for level pair', () {
      final fixture = _Fixture(includeSlab: false);

      expect(fixture.resolveUp(), isNull);
    });

    test('fails closed when physical vertical gap disagrees with slab thickness',
        () {
      final fixture = _Fixture(legacyUpperElevationMm: 3300);

      expect(fixture.resolveUp(), isNull);
    });

    test('fails closed when target room does not overlap penetration plan point',
        () {
      final fixture = _Fixture(upperRoomOffsetMm: 10000);

      expect(fixture.resolveUp(), isNull);
    });

    test('fails closed when surface space cannot resolve canonically', () {
      final fixture = _Fixture();

      final transition = CanonicalSlabTransitionResolver.resolve(
        project: fixture.project,
        buildingLevels: fixture.legacyLevels,
        fromLevel: fixture.legacyLower,
        fromSpace: fixture.legacyLower.spaces.single,
        fromSurface: RoomSurfaceRef.ceiling('legacy-l1-room'),
        point: const SurfacePointMm(1600, 1200),
        fromRoomHeightMm: 3000,
        toLevel: fixture.legacyUpper,
        toSpace: fixture.legacyUpper.spaces.single,
        toRoomHeightMm: 3000,
        canonicalSpaceIdResolver: (_) => null,
      );

      expect(transition, isNull);
    });
  });
}

final class _Fixture {
  _Fixture({
    this.includeSlab = true,
    this.legacyUpperElevationMm = 3200,
    this.upperRoomOffsetMm = 0,
  }) {
    legacyLower = _legacyLevel(
      id: 'legacy-level-1',
      elevationMm: 0,
      spaceId: 'legacy-l1-room',
      offsetMm: 0,
    );
    legacyUpper = _legacyLevel(
      id: 'legacy-level-2',
      elevationMm: legacyUpperElevationMm,
      spaceId: 'legacy-l2-room',
      offsetMm: upperRoomOffsetMm,
    );
    legacyLevels = [legacyLower, legacyUpper];
    project = _project();
  }

  final bool includeSlab;
  final int legacyUpperElevationMm;
  final int upperRoomOffsetMm;

  final ProjectId projectId = ProjectId('project');
  final SiteId siteId = SiteId('site');
  final BuildingId buildingId = BuildingId('building');
  final LevelId lowerLevelId = LevelId('level-01');
  final LevelId upperLevelId = LevelId('level-02');
  final SpaceId lowerSpaceId = SpaceId('space-l1');
  final SpaceId upperSpaceId = SpaceId('space-l2');
  final SlabId slabId = SlabId('slab-01-02');

  late final BuildingLevel legacyLower;
  late final BuildingLevel legacyUpper;
  late final List<BuildingLevel> legacyLevels;
  late final ProjectAggregateRoot project;

  SpaceId? canonicalSpaceId(String surfaceSpaceId) => switch (surfaceSpaceId) {
        'legacy-l1-room' => lowerSpaceId,
        'legacy-l2-room' => upperSpaceId,
        _ => null,
      };

  SurfaceTransitionCandidate? resolveUp() =>
      CanonicalSlabTransitionResolver.resolve(
        project: project,
        buildingLevels: legacyLevels,
        fromLevel: legacyLower,
        fromSpace: legacyLower.spaces.single,
        fromSurface: RoomSurfaceRef.ceiling('legacy-l1-room'),
        point: const SurfacePointMm(1600, 1200),
        fromRoomHeightMm: 3000,
        toLevel: legacyUpper,
        toSpace: legacyUpper.spaces.single,
        toRoomHeightMm: 3000,
        canonicalSpaceIdResolver: canonicalSpaceId,
      );

  ProjectAggregateRoot _project() {
    final slabs = <SlabId, ProjectSlab>{};
    if (includeSlab) {
      slabs[slabId] = ProjectSlab(
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
            spaceIds: [lowerSpaceId],
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
        slabs: slabs,
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
}

BuildingLevel _legacyLevel({
  required String id,
  required int elevationMm,
  required String spaceId,
  required int offsetMm,
}) {
  final polygon = MmPolygon.rectangle(
    MmPoint(offsetMm, offsetMm),
    MmPoint(offsetMm + 6000, offsetMm + 4000),
  );
  return BuildingLevel(
    id: id,
    name: id,
    elevationMm: elevationMm,
    spaces: [
      EngineeringSpace(
        id: spaceId,
        name: spaceId,
        type: SpaceType.room,
        boundary: polygon,
        referenceFrame: RoomReferenceFrame(origin: polygon.bounds.center),
      ),
    ],
  );
}
