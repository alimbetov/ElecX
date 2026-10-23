import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_slab_route_handoff.dart';
import 'package:elecx/src/application/project/project_structure_authoring.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/slab_topology.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProjectSlabRouteHandoffSession', () {
    test('preserves route identity and moves canonical navigation after commit',
        () {
      final fixture = _Fixture();
      final handoff = ProjectSlabRouteHandoffSession(fixture.structure);
      final beforeVersion = fixture.structure.project.version;

      final intent = handoff.prepare(
        routeId: ' C-103 ',
        fromSpaceId: fixture.lowerSpaceId,
        toSpaceId: fixture.upperSpaceId,
      );

      expect(intent.routeId, 'C-103');
      expect(intent.slabId, fixture.slabId);
      expect(intent.expectedVersion, beforeVersion);
      expect(
          fixture.structure.navigation.selectedSpaceId, fixture.lowerSpaceId);

      final plan = handoff.commitNavigation();

      expect(plan.slabId, fixture.slabId);
      expect(
          fixture.structure.navigation.selectedSpaceId, fixture.upperSpaceId);
      expect(fixture.structure.project.version, beforeVersion);
      expect(handoff.hasPending, isFalse);
    });

    test('stale project version blocks target navigation fail closed', () {
      final fixture = _Fixture();
      final handoff = ProjectSlabRouteHandoffSession(fixture.structure);
      handoff.prepare(
        routeId: 'C-103',
        fromSpaceId: fixture.lowerSpaceId,
        toSpaceId: fixture.upperSpaceId,
      );

      fixture.structure.createRoom(const CreateRoomRequest(name: 'Late room'));

      expect(
        handoff.commitNavigation,
        throwsA(
          isA<ProjectSlabRouteHandoffException>().having(
            (error) => error.code,
            'code',
            ProjectSlabRouteHandoffIssueCode.projectChanged,
          ),
        ),
      );
      expect(
        fixture.structure.navigation.selectedSpaceId,
        isNot(fixture.upperSpaceId),
      );
      expect(handoff.hasPending, isTrue);
    });

    test('navigation drift blocks the prepared handoff without guessing', () {
      final fixture = _Fixture();
      final handoff = ProjectSlabRouteHandoffSession(fixture.structure);
      handoff.prepare(
        routeId: 'C-103',
        fromSpaceId: fixture.lowerSpaceId,
        toSpaceId: fixture.upperSpaceId,
      );

      fixture.structure.clearSelection();

      expect(
        handoff.commitNavigation,
        throwsA(
          isA<ProjectSlabRouteHandoffException>().having(
            (error) => error.code,
            'code',
            ProjectSlabRouteHandoffIssueCode.navigationChanged,
          ),
        ),
      );
      expect(fixture.structure.navigation.selectedSpaceId, isNull);
      expect(handoff.hasPending, isTrue);
    });

    test(
        'cancel clears only the handoff intent and leaves navigation untouched',
        () {
      final fixture = _Fixture();
      final handoff = ProjectSlabRouteHandoffSession(fixture.structure);
      handoff.prepare(
        routeId: 'C-103',
        fromSpaceId: fixture.lowerSpaceId,
        toSpaceId: fixture.upperSpaceId,
      );

      handoff.cancel();

      expect(handoff.hasPending, isFalse);
      expect(
          fixture.structure.navigation.selectedSpaceId, fixture.lowerSpaceId);
      expect(
        handoff.commitNavigation,
        throwsA(
          isA<ProjectSlabRouteHandoffException>().having(
            (error) => error.code,
            'code',
            ProjectSlabRouteHandoffIssueCode.handoffNotPending,
          ),
        ),
      );
    });
  });
}

final class _Fixture {
  _Fixture() {
    final mutations = ProjectMutationSession(_project());
    structure = ProjectStructureAuthoringSession(
      mutations: mutations,
      idFactory: SecureRandomEntityIdFactory(),
    );
    structure.selectRoom(lowerSpaceId);
  }

  final ProjectId projectId = ProjectId('project');
  final SiteId siteId = SiteId('site');
  final BuildingId buildingId = BuildingId('building');
  final LevelId lowerLevelId = LevelId('level-01');
  final LevelId upperLevelId = LevelId('level-02');
  final SpaceId lowerSpaceId = SpaceId('space-l1');
  final SpaceId upperSpaceId = SpaceId('space-l2');
  final SlabId slabId = SlabId('slab-01-02');

  late final ProjectStructureAuthoringSession structure;

  ProjectAggregateRoot _project() {
    final slab = ProjectSlab(
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
}
