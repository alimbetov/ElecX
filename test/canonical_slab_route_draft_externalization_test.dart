import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_structure_authoring.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/building_composition.dart';
import 'package:elecx/src/domain/canonical_slab_transition_resolver.dart';
import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_model.dart';
import 'package:elecx/src/domain/site_outdoor_model.dart';
import 'package:elecx/src/domain/slab_topology.dart';
import 'package:elecx/src/domain/surface_routing.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/features/editor/canonical_editor_runtime_cutover.dart';
import 'package:elecx/src/features/editor/canonical_editor_workspace_adapter.dart';
import 'package:elecx/src/features/editor/canonical_room_surface_runtime_registry.dart';
import 'package:elecx/src/features/editor/canonical_slab_route_draft_externalization.dart';
import 'package:elecx/src/features/editor/canonical_slab_route_handoff_runtime.dart';
import 'package:elecx/src/features/editor/editor_building_workspace.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('live ceiling draft survives canonical slab level cutover without P2 mutation',
      () {
    final fixture = _Fixture();
    addTearDown(fixture.dispose);

    final runtime = CanonicalSlabRouteHandoffRuntime(
      coordinator: fixture.coordinator,
    );
    final prepared = runtime.prepare(
      routeId: 'C-vertical-01',
      toSpaceId: fixture.upperSpaceId,
      fromLevelElevationMm: 0,
      toLevelElevationMm: 3200,
      fromRoomHeightMm: 3000,
      toRoomHeightMm: 3000,
    );

    fixture.editor.setTool(EditorTool.cableRoute);
    fixture.editor.showCeiling();
    final sourceSurface = fixture.editor.activeSurface!;
    fixture.editor.routeSegments.add(
      SurfaceRouteSegmentDraft(
        surface: sourceSurface,
        points: const [
          SurfacePointMm(600, 1200),
          SurfacePointMm(1500, 1200),
        ],
      ),
    );

    final transition = CanonicalSlabTransitionResolver.resolve(
      project: fixture.session.project,
      buildingLevels: fixture.legacyLevels,
      fromLevel: fixture.legacyLower,
      fromSpace: fixture.legacyLower.spaces.single,
      fromSurface: sourceSurface,
      point: const SurfacePointMm(1500, 1200),
      fromRoomHeightMm: 3000,
      toLevel: fixture.legacyUpper,
      toSpace: fixture.legacyUpper.spaces.single,
      toRoomHeightMm: 3000,
      canonicalSpaceIdResolver: fixture.canonicalSpaceId,
    );
    expect(transition, isNotNull);
    expect(transition!.penetrationRequirement!.slabId, fixture.slabId);

    final beforeP2Revision = fixture.editor.p2.history.mutationRevision;
    final externalized = CanonicalSlabRouteDraftExternalization.externalize(
      editor: fixture.editor,
      intent: prepared.intent,
      transition: transition,
    );

    expect(fixture.editor.routeSegments, isEmpty);
    expect(fixture.editor.p2.history.mutationRevision, beforeP2Revision);
    expect(externalized.isRestored, isFalse);

    final plan = runtime.applyNavigation(externalizedDraft: externalized);

    expect(plan.slabId, fixture.slabId);
    expect(externalized.isRestored, isTrue);
    expect(fixture.session.navigation.selectedSpaceId, fixture.upperSpaceId);
    expect(fixture.editor.level.id, 'legacy-level-2');
    expect(fixture.editor.selectedSpaceId, 'legacy-space-2');
    expect(fixture.editor.tool, EditorTool.cableRoute);
    expect(fixture.editor.activeSurface, RoomSurfaceRef.floor('legacy-space-2'));
    expect(fixture.editor.routeSegments, hasLength(2));
    expect(fixture.editor.routeSegments.first.surface, sourceSurface);
    expect(
      fixture.editor.routeSegments.first.points,
      const [
        SurfacePointMm(600, 1200),
        SurfacePointMm(1500, 1200),
      ],
    );
    expect(
      fixture.editor.routeSegments.last.surface,
      RoomSurfaceRef.floor('legacy-space-2'),
    );
    expect(
      fixture.editor.routeSegments.last.points,
      [transition.toPoint],
    );
    expect(fixture.editor.p2.history.mutationRevision, beforeP2Revision);
  });
}

final class _Fixture {
  _Fixture() {
    legacyLower = _legacyLevel(
      id: 'legacy-level-1',
      elevationMm: 0,
      spaceId: 'legacy-space-1',
    );
    legacyUpper = _legacyLevel(
      id: 'legacy-level-2',
      elevationMm: 3200,
      spaceId: 'legacy-space-2',
    );
    legacyLevels = [legacyLower, legacyUpper];

    session = ProjectStructureAuthoringSession(
      mutations: ProjectMutationSession(_project()),
      idFactory: SecureRandomEntityIdFactory(),
    );
    session.selectRoom(lowerSpaceId);
    workspace = _workspace();
    final binding = CanonicalEditorWorkspaceBinding(
      buildingId: buildingId,
      legacyBuildingId: 'legacy-building',
      legacyLevelIds: {
        lowerLevelId: 'legacy-level-1',
        upperLevelId: 'legacy-level-2',
      },
      legacySpaceIds: {
        lowerSpaceId: 'legacy-space-1',
        upperSpaceId: 'legacy-space-2',
      },
    );
    coordinator = CanonicalEditorRuntimeCutoverCoordinator(
      session: session,
      adapter: CanonicalEditorWorkspaceAdapter(
        workspace: workspace,
        binding: binding,
      ),
    );
    coordinator.pushCanonicalToEditor();
    CanonicalRoomSurfaceRuntimeRegistry.attach(coordinator);
  }

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
  late final ProjectStructureAuthoringSession session;
  late final EditorBuildingWorkspace workspace;
  late final CanonicalEditorRuntimeCutoverCoordinator coordinator;

  EditorController get editor => workspace.editor;

  SpaceId? canonicalSpaceId(String surfaceSpaceId) => switch (surfaceSpaceId) {
        'legacy-space-1' => lowerSpaceId,
        'legacy-space-2' => upperSpaceId,
        'space-l1' => lowerSpaceId,
        'space-l2' => upperSpaceId,
        _ => null,
      };

  void dispose() {
    CanonicalRoomSurfaceRuntimeRegistry.detach(coordinator);
    editor.disposeP2State();
    editor.dispose();
  }

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

  EditorBuildingWorkspace _workspace() {
    final lower = ComposedBuildingLevel(
      level: legacyLower,
      levelNumber: 1,
      kind: BuildingLevelKind.residential,
    );
    final upper = ComposedBuildingLevel(
      level: legacyUpper,
      levelNumber: 2,
      kind: BuildingLevelKind.residential,
    );
    final buildingGeometry = Building(
      id: 'legacy-building',
      name: 'Building',
      levels: [legacyLower, legacyUpper],
    );
    final building = ComposedBuilding(
      building: buildingGeometry,
      levels: [lower, upper],
    );
    final site = ComposedProjectSite(
      site: ProjectSite(
        id: 'legacy-site',
        name: 'Site',
        buildings: [buildingGeometry],
      ),
    );
    return EditorBuildingWorkspace(
      editor: EditorController.restored(level: legacyLower, openings: const []),
      building: building,
      site: site,
      initialLevelNumber: 1,
    );
  }
}

BuildingLevel _legacyLevel({
  required String id,
  required int elevationMm,
  required String spaceId,
}) {
  final boundary = MmPolygon.rectangle(
    const MmPoint(0, 0),
    const MmPoint(6000, 4000),
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
        boundary: boundary,
        referenceFrame: RoomReferenceFrame(origin: boundary.bounds.center),
      ),
    ],
  );
}
