import 'dart:math';

import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_structure_authoring.dart';
import 'package:elecx/src/domain/boundary_edge_identity_registry.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_model.dart';
import 'package:elecx/src/domain/project_orientation.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/engine/plan_geometry_editing.dart';
import 'package:elecx/src/features/editor/canonical_editor_runtime_cutover.dart';
import 'package:elecx/src/features/editor/canonical_editor_screen_cutover_binding.dart';
import 'package:elecx/src/features/editor/canonical_editor_workspace_adapter.dart';
import 'package:elecx/src/features/editor/editor_building_workspace.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:elecx/src/features/editor/plan_geometry_editor_actions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'production edge edit commits canonically then rematerializes legacy room',
    () {
      final fixture = _Fixture();
      addTearDown(fixture.dispose);
      final binding = fixture.bind();
      addTearDown(binding.dispose);

      final beforeVersion = fixture.session.project.version;
      final beforeUndo = fixture.mutations.undoDepth;
      final source = fixture.controller.selectedSpace!.boundary;
      final candidate = PlanGeometryEditing.moveEdge(
        boundary: source,
        edgeIndex: 0,
        dragStart: const MmPoint(2000, 0),
        dragCurrent: const MmPoint(2000, 500),
      );
      expect(candidate, isNotNull);

      expect(fixture.controller.commitSelectedBoundary(candidate!), isTrue);
      expect(fixture.session.project.version, beforeVersion.next());
      expect(fixture.mutations.undoDepth, beforeUndo + 1);
      expect(
        fixture.controller.selectedSpace!.boundary.vertices,
        candidate.vertices,
      );

      final topology = fixture.session.project.index.boundary(fixture.spaceId)!;
      expect(topology.orderedEdgeIds, fixture.edgeIds);
      expect(topology.edges[fixture.edgeIds[0]]!.start.yMm, 500);
      expect(topology.edges[fixture.edgeIds[0]]!.end.yMm, 500);
    },
  );

  test('wall-hosted component blocks topology edit until P7A-5', () {
    final fixture = _Fixture();
    addTearDown(fixture.dispose);
    final binding = fixture.bind();
    addTearDown(binding.dispose);

    fixture.controller.p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: RoomSurfaceRef.wall(fixture.legacySpaceId, 0),
      position: const SurfacePointMm(1000, 1200),
    );
    final before = fixture.session.project;
    final source = fixture.controller.selectedSpace!.boundary;
    final candidate = PlanGeometryEditing.moveEdge(
      boundary: source,
      edgeIndex: 0,
      dragStart: const MmPoint(2000, 0),
      dragCurrent: const MmPoint(2000, 500),
    );
    expect(candidate, isNotNull);

    expect(fixture.controller.commitSelectedBoundary(candidate!), isFalse);
    expect(fixture.session.project, same(before));
    expect(
        fixture.controller.selectedSpace!.boundary.vertices, source.vertices);
  });

  test(
    'legacy workspace without canonical runtime keeps transitional edit path',
    () {
      final fixture = _Fixture();
      addTearDown(fixture.dispose);
      final beforeVersion = fixture.session.project.version;
      final source = fixture.controller.selectedSpace!.boundary;
      final candidate = PlanGeometryEditing.moveEdge(
        boundary: source,
        edgeIndex: 0,
        dragStart: const MmPoint(2000, 0),
        dragCurrent: const MmPoint(2000, 500),
      );

      expect(fixture.controller.commitSelectedBoundary(candidate!), isTrue);
      expect(fixture.session.project.version, beforeVersion);
      expect(
        fixture.controller.selectedSpace!.boundary.vertices,
        candidate.vertices,
      );
    },
  );
}

final class _Fixture {
  _Fixture() {
    final polygon = MmPolygon.rectangle(
      const MmPoint(0, 0),
      const MmPoint(4000, 3000),
    );
    final room = EngineeringSpace(
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
        spaces: <EngineeringSpace>[room],
      ),
      openings: const <ArchitecturalOpening>[],
    )..selectSpace(legacySpaceId);
    workspace = EditorBuildingWorkspace.blank(
      controller,
      projectId: 'project',
      projectName: 'P7A-4.5',
    );
    controller.selectSpace(legacySpaceId);

    const points = <BoundaryPointMm>[
      BoundaryPointMm(xMm: 0, yMm: 0),
      BoundaryPointMm(xMm: 4000, yMm: 0),
      BoundaryPointMm(xMm: 4000, yMm: 3000),
      BoundaryPointMm(xMm: 0, yMm: 3000),
    ];
    final topology = SpaceBoundaryTopology(
      spaceId: spaceId,
      orderedEdgeIds: edgeIds,
      edges: <BoundaryEdgeId, ProjectBoundaryEdge>{
        for (var index = 0; index < edgeIds.length; index++)
          edgeIds[index]: ProjectBoundaryEdge(
            id: edgeIds[index],
            spaceId: spaceId,
            start: points[index],
            end: points[(index + 1) % points.length],
          ),
      },
    );
    final boundaries = <SpaceId, SpaceBoundaryTopology>{spaceId: topology};
    final registry = const BoundaryEdgeIdentityRegistry.empty()
        .registerActiveBoundaries(boundaries);
    final project = ProjectAggregateRoot(
      id: ProjectId('project'),
      siteId: siteId,
      version: LocalProjectVersion(0),
      engineeringMetadata: ProjectEngineeringMetadata(
        boundaryEdgeIdentityRegistry: registry,
      ),
      stores: ProjectEntityStores(
        sites: <SiteId, ProjectSiteEntity>{
          siteId: ProjectSiteEntity(
            id: siteId,
            name: 'Site',
            buildingIds: <BuildingId>[buildingId],
          ),
        },
        buildings: <BuildingId, ProjectBuildingEntity>{
          buildingId: ProjectBuildingEntity(
            id: buildingId,
            siteId: siteId,
            name: 'Building',
            levelIds: <LevelId>[levelId],
          ),
        },
        levels: <LevelId, ProjectLevelEntity>{
          levelId: ProjectLevelEntity(
            id: levelId,
            buildingId: buildingId,
            name: 'Level',
            levelNumber: 1,
            elevationMm: 0,
            spaceIds: <SpaceId>[spaceId],
          ),
        },
        spaces: <SpaceId, ProjectSpaceEntity>{
          spaceId: ProjectSpaceEntity(
            id: spaceId,
            levelId: levelId,
            name: 'Room',
          ),
        },
        boundaries: boundaries,
      ),
    );
    mutations = ProjectMutationSession(project);
    session = ProjectStructureAuthoringSession(
      mutations: mutations,
      idFactory: SecureRandomEntityIdFactory(random: Random(745)),
      navigation: ProjectNavigationState.restore(
        project,
        activeBuildingId: buildingId,
        activeLevelId: levelId,
        selectedSpaceId: spaceId,
      ),
    );
  }

  CanonicalEditorScreenCutoverBinding bind() {
    final coordinator = CanonicalEditorRuntimeCutoverCoordinator(
      session: session,
      adapter: CanonicalEditorWorkspaceAdapter(
        workspace: workspace,
        binding: CanonicalEditorWorkspaceBinding(
          buildingId: buildingId,
          legacyBuildingId: workspace.building.building.id,
          legacyLevelIds: <LevelId, String>{levelId: legacyLevelId},
          legacySpaceIds: <SpaceId, String>{spaceId: legacySpaceId},
        ),
      ),
    );
    final binding = CanonicalEditorScreenCutoverBinding(
      coordinator: coordinator,
    );
    binding.start();
    return binding;
  }

  void dispose() {
    controller.disposeP2State();
    workspace.dispose();
    controller.dispose();
  }

  final SiteId siteId = SiteId('site');
  final BuildingId buildingId = BuildingId('building');
  final LevelId levelId = LevelId('level');
  final SpaceId spaceId = SpaceId('space');
  final String legacyLevelId = 'legacy-level';
  final String legacySpaceId = 'legacy-space';
  final List<BoundaryEdgeId> edgeIds = <BoundaryEdgeId>[
    BoundaryEdgeId('edge-a'),
    BoundaryEdgeId('edge-b'),
    BoundaryEdgeId('edge-c'),
    BoundaryEdgeId('edge-d'),
  ];

  late final EditorController controller;
  late final EditorBuildingWorkspace workspace;
  late final ProjectMutationSession mutations;
  late final ProjectStructureAuthoringSession session;
}
