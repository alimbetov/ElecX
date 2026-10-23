import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_structure_authoring.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/building_composition.dart';
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
import 'package:elecx/src/features/editor/canonical_slab_route_handoff_runtime.dart';
import 'package:elecx/src/features/editor/editor_building_workspace.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CanonicalSlabRouteHandoffRuntime', () {
    test('applies proven handoff to canonical navigation and legacy workspace',
        () {
      final fixture = _Fixture();
      final runtime = CanonicalSlabRouteHandoffRuntime(
        coordinator: fixture.coordinator,
      );

      final prepared = runtime.prepare(
        routeId: 'C-103',
        toSpaceId: fixture.upperSpaceId,
        fromLevelElevationMm: 0,
        toLevelElevationMm: 3200,
        fromRoomHeightMm: 3000,
        toRoomHeightMm: 3000,
      );

      expect(prepared.intent.slabId, fixture.slabId);
      expect(fixture.workspace.editor.level.id, 'legacy-level-1');

      final plan = runtime.applyNavigation();

      expect(plan.slabId, fixture.slabId);
      expect(fixture.session.navigation.selectedSpaceId, fixture.upperSpaceId);
      expect(fixture.workspace.editor.level.id, 'legacy-level-2');
      expect(fixture.workspace.editor.selectedSpaceId, 'legacy-space-2');
      expect(runtime.prepared, isNull);
    });

    test('blocks level switch while transient route draft is still live', () {
      final fixture = _Fixture();
      final runtime = CanonicalSlabRouteHandoffRuntime(
        coordinator: fixture.coordinator,
      );
      runtime.prepare(
        routeId: 'C-103',
        toSpaceId: fixture.upperSpaceId,
        fromLevelElevationMm: 0,
        toLevelElevationMm: 3200,
        fromRoomHeightMm: 3000,
        toRoomHeightMm: 3000,
      );
      fixture.workspace.editor.routeSegments.add(
        SurfaceRouteSegmentDraft(
          surface: RoomSurfaceRef.ceiling('legacy-space-1'),
          points: const [SurfacePointMm(1000, 1000)],
        ),
      );

      expect(
        runtime.applyNavigation,
        throwsA(
          isA<CanonicalSlabRouteHandoffRuntimeException>().having(
            (error) => error.code,
            'code',
            CanonicalSlabRouteHandoffRuntimeIssueCode
                .transientRouteDraftNotExternalized,
          ),
        ),
      );
      expect(fixture.session.navigation.selectedSpaceId, fixture.lowerSpaceId);
      expect(fixture.workspace.editor.level.id, 'legacy-level-1');
      expect(runtime.prepared, isNotNull);
    });

    test('prepare fails closed when target legacy geometry is not bound', () {
      final fixture = _Fixture(bindUpperSpace: false);
      final runtime = CanonicalSlabRouteHandoffRuntime(
        coordinator: fixture.coordinator,
      );

      expect(
        () => runtime.prepare(
          routeId: 'C-103',
          toSpaceId: fixture.upperSpaceId,
          fromLevelElevationMm: 0,
          toLevelElevationMm: 3200,
          fromRoomHeightMm: 3000,
          toRoomHeightMm: 3000,
        ),
        throwsA(
          isA<CanonicalSlabRouteHandoffRuntimeException>().having(
            (error) => error.code,
            'code',
            CanonicalSlabRouteHandoffRuntimeIssueCode.targetNotMaterialized,
          ),
        ),
      );
      expect(fixture.session.navigation.selectedSpaceId, fixture.lowerSpaceId);
      expect(fixture.workspace.editor.level.id, 'legacy-level-1');
      expect(runtime.prepared, isNull);
    });
  });
}

final class _Fixture {
  _Fixture({this.bindUpperSpace = true}) {
    final project = _project();
    session = ProjectStructureAuthoringSession(
      mutations: ProjectMutationSession(project),
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
        if (bindUpperSpace) upperSpaceId: 'legacy-space-2',
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
  }

  final bool bindUpperSpace;

  final ProjectId projectId = ProjectId('project');
  final SiteId siteId = SiteId('site');
  final BuildingId buildingId = BuildingId('building');
  final LevelId lowerLevelId = LevelId('level-01');
  final LevelId upperLevelId = LevelId('level-02');
  final SpaceId lowerSpaceId = SpaceId('space-l1');
  final SpaceId upperSpaceId = SpaceId('space-l2');
  final SlabId slabId = SlabId('slab-01-02');

  late final ProjectStructureAuthoringSession session;
  late final EditorBuildingWorkspace workspace;
  late final CanonicalEditorRuntimeCutoverCoordinator coordinator;

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
    final lowerGeometry = _legacyLevel(
      id: 'legacy-level-1',
      name: 'Lower',
      elevationMm: 0,
      spaceId: 'legacy-space-1',
    );
    final upperGeometry = _legacyLevel(
      id: 'legacy-level-2',
      name: 'Upper',
      elevationMm: 3200,
      spaceId: 'legacy-space-2',
    );
    final lower = ComposedBuildingLevel(
      level: lowerGeometry,
      levelNumber: 1,
      kind: BuildingLevelKind.residential,
    );
    final upper = ComposedBuildingLevel(
      level: upperGeometry,
      levelNumber: 2,
      kind: BuildingLevelKind.residential,
    );
    final buildingGeometry = Building(
      id: 'legacy-building',
      name: 'Building',
      levels: [lowerGeometry, upperGeometry],
    );
    final building = ComposedBuilding(
      building: buildingGeometry,
      levels: [lower, upper],
    );
    final editor = EditorController.restored(
      level: lowerGeometry,
      openings: const [],
    );
    final site = ComposedProjectSite(
      site: ProjectSite(
        id: 'legacy-site',
        name: 'Site',
        buildings: [buildingGeometry],
      ),
    );
    return EditorBuildingWorkspace(
      editor: editor,
      building: building,
      site: site,
      initialLevelNumber: 1,
    );
  }
}

BuildingLevel _legacyLevel({
  required String id,
  required String name,
  required int elevationMm,
  required String spaceId,
}) {
  final boundary = MmPolygon.rectangle(
    const MmPoint(0, 0),
    const MmPoint(6000, 4000),
  );
  return BuildingLevel(
    id: id,
    name: name,
    elevationMm: elevationMm,
    spaces: [
      EngineeringSpace(
        id: spaceId,
        name: name,
        type: SpaceType.room,
        boundary: boundary,
        referenceFrame: RoomReferenceFrame(origin: boundary.bounds.center),
      ),
    ],
  );
}
