import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_structure_authoring.dart';
import 'package:elecx/src/domain/boundary_penetration.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/building_composition.dart';
import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/electrical_routing.dart';
import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_model.dart';
import 'package:elecx/src/domain/route_host.dart';
import 'package:elecx/src/domain/site_outdoor_model.dart';
import 'package:elecx/src/domain/slab_topology.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/engine/route_interaction_engine.dart';
import 'package:elecx/src/features/editor/canonical_editor_runtime_cutover.dart';
import 'package:elecx/src/features/editor/canonical_editor_workspace_adapter.dart';
import 'package:elecx/src/features/editor/canonical_room_surface_runtime_registry.dart';
import 'package:elecx/src/features/editor/editor_building_workspace.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:elecx/src/features/editor/route_selection_session.dart';
import 'package:elecx/src/features/editor/surface_transition_navigator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('canvas-facing selected route projects and follows slab marker safely', () {
    final fixture = _Fixture();
    addTearDown(fixture.dispose);
    final route = fixture.editor.p2.routes.single;
    final beforeRevision = fixture.editor.p2.history.mutationRevision;

    fixture.editor.routeSelection.select(route.id);
    final hosted = fixture.editor.routeSelection.selectedHostedRoute!;
    final currentHost = RouteHostRef.indoor(fixture.legacyLowerCeiling);
    final transitions = RouteInteractionEngine.transitionsOnHost(
      route: hosted,
      host: currentHost,
    );

    expect(transitions, hasLength(1));
    final projected = transitions.single;
    expect(projected.kind, RouteHostTransitionKind.levelPenetration);
    expect(projected.slabId, fixture.slabId);
    expect(projected.fromHost, currentHost);
    expect(projected.toHost.surface, fixture.canonicalUpperFloor);

    expect(
      SurfaceTransitionNavigator.navigate(
        fixture.editor,
        projected.toHost.surface!,
      ),
      isTrue,
    );

    expect(fixture.session.navigation.selectedSpaceId, fixture.upperSpaceId);
    expect(fixture.editor.level.id, fixture.legacyUpperLevelId);
    expect(fixture.editor.activeSurface, fixture.legacyUpperFloor);
    expect(fixture.editor.p2.history.mutationRevision, beforeRevision);
    expect(fixture.editor.p2.routes.single.id, route.id);
    expect(
      fixture.editor.p2.routes.single.penetrations.single.slabId,
      fixture.slabId,
    );
  });
}

final class _Fixture {
  _Fixture() {
    legacyLower = _legacyLevel(
      id: legacyLowerLevelId,
      elevationMm: 0,
      spaceId: legacyLowerSpaceId,
    );
    legacyUpper = _legacyLevel(
      id: legacyUpperLevelId,
      elevationMm: 3200,
      spaceId: legacyUpperSpaceId,
    );
    session = ProjectStructureAuthoringSession(
      mutations: ProjectMutationSession(_project()),
      idFactory: SecureRandomEntityIdFactory(),
    );
    session.selectRoom(lowerSpaceId);
    workspace = _workspace();
    coordinator = CanonicalEditorRuntimeCutoverCoordinator(
      session: session,
      adapter: CanonicalEditorWorkspaceAdapter(
        workspace: workspace,
        binding: CanonicalEditorWorkspaceBinding(
          buildingId: buildingId,
          legacyBuildingId: 'legacy-building',
          legacyLevelIds: {
            lowerLevelId: legacyLowerLevelId,
            upperLevelId: legacyUpperLevelId,
          },
          legacySpaceIds: {
            lowerSpaceId: legacyLowerSpaceId,
            upperSpaceId: legacyUpperSpaceId,
          },
        ),
      ),
    );
    coordinator.pushCanonicalToEditor();
    CanonicalRoomSurfaceRuntimeRegistry.attach(coordinator);
    editor.showCeiling();

    final source = ElectricalComponentPlacement(
      id: 'source',
      type: ElectricalComponentType.powerSource,
      surface: canonicalLowerCeiling,
      position: const SurfacePointMm(300, 1200),
      label: 'Source',
      ports: const [
        ElectricalPortDefinition(id: 'out', kind: ElectricalPortKind.powerOut),
      ],
    );
    final target = ElectricalComponentPlacement(
      id: 'target',
      type: ElectricalComponentType.socketOutlet,
      surface: canonicalUpperFloor,
      position: const SurfacePointMm(2400, 1200),
      label: 'Target',
      ports: const [
        ElectricalPortDefinition(id: 'in', kind: ElectricalPortKind.powerIn),
      ],
    );
    final penetration = BoundaryPenetration.normal(
      id: 'penetration-slab',
      hostKind: BoundaryPenetrationHostKind.slab,
      entrySurface: canonicalLowerCeiling,
      entryPoint: const SurfacePointMm(1500, 1200),
      exitSurface: canonicalUpperFloor,
      exitPoint: const SurfacePointMm(1500, 1200),
      hostThicknessMm: 200,
      routeId: 'C-vertical',
      materialId: 'reinforced-concrete',
      slabId: slabId,
    );
    final route = ElectricalCableRoute(
      id: 'C-vertical',
      source: const ElectricalEndpointRef(componentId: 'source', portId: 'out'),
      target: const ElectricalEndpointRef(componentId: 'target', portId: 'in'),
      segments: [
        ElectricalRouteSegment(
          surface: canonicalLowerCeiling,
          points: const [
            SurfacePointMm(300, 1200),
            SurfacePointMm(1500, 1200),
          ],
        ),
        ElectricalRouteSegment(
          surface: canonicalUpperFloor,
          points: const [
            SurfacePointMm(1500, 1200),
            SurfacePointMm(2400, 1200),
          ],
        ),
      ],
      penetrations: [penetration],
    );
    editor.p2.history.replaceState(
      EditorP2State(components: [source, target], routes: [route]),
      clearHistory: true,
    );
  }

  final SiteId siteId = SiteId('site');
  final BuildingId buildingId = BuildingId('building');
  final LevelId lowerLevelId = LevelId('level-01');
  final LevelId upperLevelId = LevelId('level-02');
  final SpaceId lowerSpaceId = SpaceId('space-l1');
  final SpaceId upperSpaceId = SpaceId('space-l2');
  final SlabId slabId = SlabId('slab-01-02');
  final String legacyLowerLevelId = 'legacy-level-1';
  final String legacyUpperLevelId = 'legacy-level-2';
  final String legacyLowerSpaceId = 'legacy-space-1';
  final String legacyUpperSpaceId = 'legacy-space-2';

  RoomSurfaceRef get canonicalLowerCeiling =>
      RoomSurfaceRef.ceiling(lowerSpaceId.value);
  RoomSurfaceRef get canonicalUpperFloor =>
      RoomSurfaceRef.floor(upperSpaceId.value);
  RoomSurfaceRef get legacyLowerCeiling =>
      RoomSurfaceRef.ceiling(legacyLowerSpaceId);
  RoomSurfaceRef get legacyUpperFloor =>
      RoomSurfaceRef.floor(legacyUpperSpaceId);

  late final BuildingLevel legacyLower;
  late final BuildingLevel legacyUpper;
  late final ProjectStructureAuthoringSession session;
  late final EditorBuildingWorkspace workspace;
  late final CanonicalEditorRuntimeCutoverCoordinator coordinator;

  EditorController get editor => workspace.editor;

  void dispose() {
    CanonicalRoomSurfaceRuntimeRegistry.detach(coordinator);
    workspace.dispose();
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
        BoundaryPointMm(xMm: 4000, yMm: 0),
        BoundaryPointMm(xMm: 4000, yMm: 3000),
        BoundaryPointMm(xMm: 0, yMm: 3000),
      ],
    );
    return ProjectAggregateRoot(
      id: ProjectId('project'),
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
    final site = ComposedProjectSite(
      site: ProjectSite(
        id: 'legacy-site',
        name: 'Site',
        buildings: [buildingGeometry],
      ),
    );
    return EditorBuildingWorkspace(
      editor: EditorController.restored(level: legacyLower, openings: const []),
      building: ComposedBuilding(
        building: buildingGeometry,
        levels: [lower, upper],
      ),
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
    const MmPoint(4000, 3000),
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
