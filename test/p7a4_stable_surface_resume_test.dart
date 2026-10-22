import 'dart:math';

import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_structure_authoring.dart';
import 'package:elecx/src/domain/boundary_edge_identity_registry.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_model.dart';
import 'package:elecx/src/domain/project_orientation.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/features/editor/canonical_editor_runtime_cutover.dart';
import 'package:elecx/src/features/editor/canonical_editor_screen_cutover_binding.dart';
import 'package:elecx/src/features/editor/canonical_editor_workspace_adapter.dart';
import 'package:elecx/src/features/editor/canonical_room_surface_resume.dart';
import 'package:elecx/src/features/editor/canonical_room_surface_runtime_registry.dart';
import 'package:elecx/src/features/editor/editor_building_workspace.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_project_document.dart';
import 'package:elecx/src/features/editor/project_persistence_metadata.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stable wall resume survives save reopen by BoundaryEdgeId only', () {
    final fixture = _Fixture();
    addTearDown(fixture.dispose);
    final runtime = fixture.bind(fixture.workspace);
    addTearDown(runtime.dispose);

    expect(
      CanonicalRoomSurfaceRuntimeRegistry.resolve(
        fixture.controller,
        fixture.spaceId,
      )?.showBoundaryEdge(fixture.edgeIds[2]),
      isTrue,
    );

    final document = EditorProjectDocument.capture(
      fixture.workspace,
      metadata: fixture.metadata,
    );
    final resumeJson =
        ((document.toJson()['workspace']! as Map)['resume']! as Map);
    final canonicalJson = resumeJson['canonicalSurface']! as Map;

    expect(document.schemaVersion, 5);
    expect(document.resume.activeSurface, isNull);
    expect(document.resume.canonicalSurface?.spaceId, fixture.spaceId);
    expect(
      document.resume.canonicalSurface?.boundaryEdgeId,
      fixture.edgeIds[2],
    );
    expect(resumeJson['activeSurface'], isNull);
    expect(canonicalJson['boundaryEdgeId'], fixture.edgeIds[2].value);
    expect(canonicalJson.containsKey('wallIndex'), isFalse);

    runtime.dispose();
    final decoded = EditorProjectDocument.fromJson(document.toJson());
    final restored = decoded.restore();
    addTearDown(restored.workspace.dispose);
    addTearDown(restored.editor.disposeP2State);
    addTearDown(restored.editor.dispose);

    expect(restored.editor.viewMode, EditorViewMode.plan);
    expect(restored.editor.activeSurface, isNull);

    final reopened = fixture.bind(restored.workspace);
    addTearDown(reopened.dispose);

    final selection = CanonicalRoomSurfaceRuntimeRegistry.resolve(
      restored.editor,
      fixture.spaceId,
    )?.current();
    expect(selection?.boundaryEdgeId, fixture.edgeIds[2]);
    expect(restored.editor.activeSurface?.type, SurfacePlaneType.wall);
    expect(restored.editor.activeSurface?.wallIndex, 2);

    final savedAgain = EditorProjectDocument.capture(
      restored.workspace,
      metadata: fixture.metadata,
    );
    expect(savedAgain.resume.activeSurface, isNull);
    expect(
      savedAgain.resume.canonicalSurface?.boundaryEdgeId,
      fixture.edgeIds[2],
    );
  });

  test('unknown stable resume edge fails closed to Plan after attach', () {
    final fixture = _Fixture();
    addTearDown(fixture.dispose);
    CanonicalRoomSurfaceRuntimeRegistry.stageResume(
      fixture.controller,
      CanonicalRoomSurfaceResume(
        spaceId: fixture.spaceId,
        kind: CanonicalRoomSurfaceResumeKind.wall,
        boundaryEdgeId: BoundaryEdgeId('removed-edge'),
      ),
    );

    final runtime = fixture.bind(fixture.workspace);
    addTearDown(runtime.dispose);

    expect(fixture.controller.viewMode, EditorViewMode.plan);
    expect(fixture.controller.activeSurface, isNull);
  });

  test('projection is reconstructed after canonical project version changes',
      () {
    final fixture = _Fixture();
    addTearDown(fixture.dispose);
    final runtime = fixture.bind(fixture.workspace);
    addTearDown(runtime.dispose);

    final first = CanonicalRoomSurfaceRuntimeRegistry.resolve(
      fixture.controller,
      fixture.spaceId,
    );
    expect(first, isNotNull);
    expect(first!.showBoundaryEdge(fixture.edgeIds[1]), isTrue);
    final versionBefore = fixture.session.project.version;

    final mutation = fixture.session.projectNorthEditing.setProjectNorth(
      ProjectEngineeringNorth.fromDegrees(17),
      expectedVersion: versionBefore,
    );
    expect(mutation, isNotNull);
    expect(fixture.session.project.version, versionBefore.next());

    final second = CanonicalRoomSurfaceRuntimeRegistry.resolve(
      fixture.controller,
      fixture.spaceId,
    );
    expect(second, isNotNull);
    expect(identical(first, second), isFalse);
    expect(second!.current().boundaryEdgeId, fixture.edgeIds[1]);
  });

  test('schema v4 migration never invents BoundaryEdgeId from wallIndex', () {
    final fixture = _Fixture();
    addTearDown(fixture.dispose);
    fixture.controller.showWall(1);
    final legacy = EditorProjectDocument.capture(
      fixture.workspace,
      metadata: fixture.metadata,
    ).toJson();
    final workspace = Map<String, Object?>.from(legacy['workspace']! as Map);
    final resume = Map<String, Object?>.from(workspace['resume']! as Map);
    resume.remove('canonicalSurface');
    workspace['resume'] = resume;
    final v4 = <String, Object?>{
      ...legacy,
      'schemaVersion': 4,
      'workspace': workspace,
    };

    final migrated = EditorProjectDocument.fromJson(v4);
    expect(migrated.schemaVersion, 5);
    expect(migrated.resume.canonicalSurface, isNull);
    expect(migrated.resume.activeSurface?.wallIndex, 1);
  });
}

final class _Fixture {
  _Fixture() {
    const points = <BoundaryPointMm>[
      BoundaryPointMm(xMm: 0, yMm: 0),
      BoundaryPointMm(xMm: 4000, yMm: 0),
      BoundaryPointMm(xMm: 4000, yMm: 3000),
      BoundaryPointMm(xMm: 0, yMm: 3000),
    ];
    final polygon = MmPolygon(<MmPoint>[
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
        spaces: <EngineeringSpace>[legacySpace],
      ),
      openings: const <ArchitecturalOpening>[],
    )..selectSpace(legacySpaceId);
    workspace = EditorBuildingWorkspace.blank(
      controller,
      projectId: legacyProjectId,
      projectName: 'Stable Resume',
    );
    controller.selectSpace(legacySpaceId);

    final edges = <BoundaryEdgeId, ProjectBoundaryEdge>{
      for (var index = 0; index < edgeIds.length; index++)
        edgeIds[index]: ProjectBoundaryEdge(
          id: edgeIds[index],
          spaceId: spaceId,
          start: points[index],
          end: points[(index + 1) % points.length],
        ),
    };
    final topology = SpaceBoundaryTopology(
      spaceId: spaceId,
      orderedEdgeIds: edgeIds,
      edges: edges,
    );
    final boundaries = <SpaceId, SpaceBoundaryTopology>{spaceId: topology};
    final registry = const BoundaryEdgeIdentityRegistry.empty()
        .registerActiveBoundaries(boundaries);

    project = ProjectAggregateRoot(
      id: projectId,
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
    navigation = ProjectNavigationState.restore(
      project,
      activeBuildingId: buildingId,
      activeLevelId: levelId,
      selectedSpaceId: spaceId,
    );
    session = ProjectStructureAuthoringSession(
      mutations: ProjectMutationSession(project),
      idFactory: SecureRandomEntityIdFactory(random: Random(704)),
      navigation: navigation,
    );
    metadata = EditorProjectMetadata(
      projectId: legacyProjectId,
      projectName: 'Stable Resume',
      createdAt: DateTime.utc(2026, 10, 22, 10),
      updatedAt: DateTime.utc(2026, 10, 22, 10),
    );
  }

  CanonicalEditorScreenCutoverBinding bind(EditorBuildingWorkspace target) {
    final targetBinding = CanonicalEditorWorkspaceBinding(
      buildingId: buildingId,
      legacyBuildingId: target.building.building.id,
      legacyLevelIds: <LevelId, String>{levelId: legacyLevelId},
      legacySpaceIds: <SpaceId, String>{spaceId: legacySpaceId},
    );
    final coordinator = CanonicalEditorRuntimeCutoverCoordinator(
      session: session,
      adapter: CanonicalEditorWorkspaceAdapter(
        workspace: target,
        binding: targetBinding,
      ),
    );
    final result = CanonicalEditorScreenCutoverBinding(
      coordinator: coordinator,
    );
    result.start();
    return result;
  }

  void dispose() {
    workspace.dispose();
    controller.disposeP2State();
    controller.dispose();
  }

  static const String legacyProjectId = 'legacy-project';
  final ProjectId projectId = ProjectId('project');
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
  late final ProjectAggregateRoot project;
  late final ProjectNavigationState navigation;
  late final ProjectStructureAuthoringSession session;
  late final EditorProjectMetadata metadata;
}
