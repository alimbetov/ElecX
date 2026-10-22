import 'package:elecx/src/domain/boundary_edge_identity_registry.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_model.dart';
import 'package:elecx/src/domain/project_orientation.dart';
import 'package:elecx/src/features/editor/canonical_editor_workspace_adapter.dart';
import 'package:elecx/src/features/editor/canonical_room_surface_cutover.dart';
import 'package:elecx/src/features/editor/editor_building_workspace.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P7A-4 production room surface cutover resolver', () {
    test('resolves stable wall selection for exact bound room', () {
      final fixture = _Fixture();
      fixture.controller.showWall(1);

      final adapter = CanonicalRoomSurfaceCutover.resolve(
        project: fixture.project,
        binding: fixture.binding,
        workspace: fixture.workspace,
        spaceId: fixture.spaceId,
      );

      expect(adapter.current().boundaryEdgeId, fixture.edgeIds[1]);
    });

    test('missing canonical boundary refuses legacy ordinal fallback', () {
      final fixture = _Fixture(includeBoundary: false);

      expect(
        () => CanonicalRoomSurfaceCutover.resolve(
          project: fixture.project,
          binding: fixture.binding,
          workspace: fixture.workspace,
          spaceId: fixture.spaceId,
        ),
        throwsA(
          isA<CanonicalRoomSurfaceCutoverException>().having(
            (error) => error.code,
            'code',
            CanonicalRoomSurfaceCutoverIssueCode.boundaryTopologyMissing,
          ),
        ),
      );
    });

    test('canonical space outside bound building fails closed', () {
      final fixture = _Fixture();
      final wrongBuildingBinding = CanonicalEditorWorkspaceBinding(
        buildingId: BuildingId('other-building'),
        legacyBuildingId: fixture.workspace.building.building.id,
        legacyLevelIds: {fixture.levelId: fixture.legacyLevelId},
        legacySpaceIds: {fixture.spaceId: fixture.legacySpaceId},
      );

      expect(
        () => CanonicalRoomSurfaceCutover.resolve(
          project: fixture.project,
          binding: wrongBuildingBinding,
          workspace: fixture.workspace,
          spaceId: fixture.spaceId,
        ),
        throwsA(
          isA<CanonicalRoomSurfaceCutoverException>().having(
            (error) => error.code,
            'code',
            CanonicalRoomSurfaceCutoverIssueCode
                .canonicalSpaceOutsideBoundBuilding,
          ),
        ),
      );
    });

    test('legacy building mismatch fails before level or wall projection', () {
      final fixture = _Fixture();
      final wrongLegacyBuildingBinding = CanonicalEditorWorkspaceBinding(
        buildingId: fixture.buildingId,
        legacyBuildingId: 'other-legacy-building',
        legacyLevelIds: {fixture.levelId: fixture.legacyLevelId},
        legacySpaceIds: {fixture.spaceId: fixture.legacySpaceId},
      );

      expect(
        () => CanonicalRoomSurfaceCutover.resolve(
          project: fixture.project,
          binding: wrongLegacyBuildingBinding,
          workspace: fixture.workspace,
          spaceId: fixture.spaceId,
        ),
        throwsA(
          isA<CanonicalRoomSurfaceCutoverException>().having(
            (error) => error.code,
            'code',
            CanonicalRoomSurfaceCutoverIssueCode.legacyBuildingMismatch,
          ),
        ),
      );
    });

    test('missing legacy level binding fails closed before wall projection',
        () {
      final fixture = _Fixture();
      final incompleteBinding = CanonicalEditorWorkspaceBinding(
        buildingId: fixture.buildingId,
        legacyBuildingId: fixture.workspace.building.building.id,
        legacyLevelIds: const {},
        legacySpaceIds: {fixture.spaceId: fixture.legacySpaceId},
      );

      expect(
        () => CanonicalRoomSurfaceCutover.resolve(
          project: fixture.project,
          binding: incompleteBinding,
          workspace: fixture.workspace,
          spaceId: fixture.spaceId,
        ),
        throwsA(
          isA<CanonicalRoomSurfaceCutoverException>().having(
            (error) => error.code,
            'code',
            CanonicalRoomSurfaceCutoverIssueCode.legacyLevelBindingMissing,
          ),
        ),
      );
    });

    test('wrong active legacy level fails closed before wall projection', () {
      final fixture = _Fixture();
      fixture.controller.level = BuildingLevel(
        id: 'other-legacy-level',
        name: 'Other level',
        elevationMm: 0,
        spaces: fixture.controller.level.spaces,
      );

      expect(
        () => CanonicalRoomSurfaceCutover.resolve(
          project: fixture.project,
          binding: fixture.binding,
          workspace: fixture.workspace,
          spaceId: fixture.spaceId,
        ),
        throwsA(
          isA<CanonicalRoomSurfaceCutoverException>().having(
            (error) => error.code,
            'code',
            CanonicalRoomSurfaceCutoverIssueCode.legacyLevelNotActive,
          ),
        ),
      );
    });

    test('legacy selection drift fails closed', () {
      final fixture = _Fixture();
      fixture.controller.selectSpace(null);

      expect(
        () => CanonicalRoomSurfaceCutover.resolve(
          project: fixture.project,
          binding: fixture.binding,
          workspace: fixture.workspace,
          spaceId: fixture.spaceId,
        ),
        throwsA(
          isA<CanonicalRoomSurfaceCutoverException>().having(
            (error) => error.code,
            'code',
            CanonicalRoomSurfaceCutoverIssueCode.legacySpaceNotSelected,
          ),
        ),
      );
    });
  });
}

final class _Fixture {
  _Fixture({bool includeBoundary = true}) {
    const points = [
      BoundaryPointMm(xMm: 0, yMm: 0),
      BoundaryPointMm(xMm: 4000, yMm: 0),
      BoundaryPointMm(xMm: 4000, yMm: 3000),
      BoundaryPointMm(xMm: 0, yMm: 3000),
    ];
    final polygon = MmPolygon([
      for (final point in points) MmPoint(point.xMm, point.yMm),
    ]);
    final legacySpace = EngineeringSpace(
      id: legacySpaceId,
      name: 'Room',
      type: SpaceType.room,
      boundary: polygon,
      referenceFrame: RoomReferenceFrame(origin: polygon.bounds.center),
    );
    controller = EditorController.restored(
      level: BuildingLevel(
        id: legacyLevelId,
        name: 'Level',
        elevationMm: 0,
        spaces: [legacySpace],
      ),
      openings: const [],
    )..selectSpace(legacySpaceId);
    workspace = EditorBuildingWorkspace.blank(
      controller,
      projectId: 'legacy-project',
      projectName: 'Legacy project',
    );
    workspace.editor.selectSpace(legacySpaceId);

    final edges = <BoundaryEdgeId, ProjectBoundaryEdge>{};
    for (var index = 0; index < edgeIds.length; index++) {
      final edgeId = edgeIds[index];
      edges[edgeId] = ProjectBoundaryEdge(
        id: edgeId,
        spaceId: spaceId,
        start: points[index],
        end: points[(index + 1) % points.length],
      );
    }
    final topology = SpaceBoundaryTopology(
      spaceId: spaceId,
      orderedEdgeIds: edgeIds,
      edges: edges,
    );
    final boundaries = includeBoundary
        ? <SpaceId, SpaceBoundaryTopology>{spaceId: topology}
        : <SpaceId, SpaceBoundaryTopology>{};
    final registry = includeBoundary
        ? const BoundaryEdgeIdentityRegistry.empty()
            .registerActiveBoundaries(boundaries)
        : const BoundaryEdgeIdentityRegistry.empty();

    project = ProjectAggregateRoot(
      id: projectId,
      siteId: siteId,
      version: LocalProjectVersion(0),
      engineeringMetadata: ProjectEngineeringMetadata(
        boundaryEdgeIdentityRegistry: registry,
      ),
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
            levelIds: [levelId],
          ),
        },
        levels: {
          levelId: ProjectLevelEntity(
            id: levelId,
            buildingId: buildingId,
            name: 'Level',
            levelNumber: 1,
            elevationMm: 0,
            spaceIds: [spaceId],
          ),
        },
        spaces: {
          spaceId: ProjectSpaceEntity(
            id: spaceId,
            levelId: levelId,
            name: 'Room',
          ),
        },
        boundaries: boundaries,
      ),
    );
    binding = CanonicalEditorWorkspaceBinding(
      buildingId: buildingId,
      legacyBuildingId: workspace.building.building.id,
      legacyLevelIds: {levelId: legacyLevelId},
      legacySpaceIds: {spaceId: legacySpaceId},
    );
  }

  final ProjectId projectId = ProjectId('project');
  final SiteId siteId = SiteId('site');
  final BuildingId buildingId = BuildingId('building');
  final LevelId levelId = LevelId('level');
  final SpaceId spaceId = SpaceId('space');
  final String legacyLevelId = 'legacy-level';
  final String legacySpaceId = 'legacy-space';
  final List<BoundaryEdgeId> edgeIds = [
    BoundaryEdgeId('edge-a'),
    BoundaryEdgeId('edge-b'),
    BoundaryEdgeId('edge-c'),
    BoundaryEdgeId('edge-d'),
  ];
  late final ProjectAggregateRoot project;
  late final CanonicalEditorWorkspaceBinding binding;
  late final EditorController controller;
  late final EditorBuildingWorkspace workspace;
}
