import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_structure_authoring.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/building_composition.dart';
import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/electrical_routing.dart';
import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_model.dart';
import 'package:elecx/src/domain/site_outdoor_model.dart';
import 'package:elecx/src/domain/slab_topology.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/features/editor/canonical_editor_runtime_cutover.dart';
import 'package:elecx/src/features/editor/canonical_editor_workspace_adapter.dart';
import 'package:elecx/src/features/editor/canonical_room_surface_runtime_registry.dart';
import 'package:elecx/src/features/editor/canonical_slab_cable_handoff_authoring.dart';
import 'package:elecx/src/features/editor/canonical_slab_route_handoff_runtime.dart';
import 'package:elecx/src/features/editor/editor_building_workspace.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:elecx/src/features/editor/physical_cable_route_committer.dart';
import 'package:elecx/src/features/editor/physical_manual_cable_draft_persistence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'existing canonical C-103 continues across slab with same route id and one P2 transaction',
    () {
      final fixture = _Fixture();
      addTearDown(fixture.dispose);
      final original = fixture.route;
      final revisionBeforeBegin = fixture.editor.p2.history.mutationRevision;

      expect(fixture.editor.beginPhysicalRouteContinuation(original.id), isTrue);
      expect(fixture.editor.physicalRouteContinuationId, 'C-103');
      expect(
        fixture.editor.activeSurface,
        RoomSurfaceRef.ceiling(fixture.legacyLowerSpaceId),
      );

      fixture.editor.surfaceTap(const SurfacePointMm(1500, 1200));

      final handoff = CanonicalSlabCableHandoffAuthoring(
        runtime: CanonicalSlabRouteHandoffRuntime(
          coordinator: fixture.coordinator,
        ),
      ).continueAcrossSlab(
        routeId: original.id,
        toSpaceId: fixture.upperSpaceId,
        fromRoomHeightMm: 3000,
        toRoomHeightMm: 3000,
      );

      expect(handoff.routeId, original.id);
      expect(handoff.slabId, fixture.slabId);
      expect(fixture.session.navigation.selectedSpaceId, fixture.upperSpaceId);
      expect(fixture.editor.level.id, fixture.legacyUpperLevelId);
      expect(
        fixture.editor.activeSurface,
        RoomSurfaceRef.floor(fixture.legacyUpperSpaceId),
      );
      expect(
        fixture.editor.p2.history.mutationRevision,
        revisionBeforeBegin,
      );

      fixture.editor.surfaceTap(const SurfacePointMm(2400, 1200));
      expect(
        fixture.editor.finishPhysicalRouteContinuation(
          resolveTransition: handoff.resolverFor(fixture.editor),
        ),
        isTrue,
      );

      expect(fixture.editor.p2.routes, hasLength(1));
      final committed = fixture.editor.p2.routes.single;
      expect(committed.id, 'C-103');
      expect(committed.target.componentId, 'target-b');
      expect(committed.segments, hasLength(3));
      expect(committed.penetrations, hasLength(1));
      expect(committed.penetrations.single.slabId, fixture.slabId);
      expect(committed.penetrations.single.routeId, 'C-103');
      expect(committed.penetrations.single.hostThicknessMm, 200);
      expect(
        fixture.editor.p2.history.mutationRevision,
        revisionBeforeBegin + 1,
      );
      expect(fixture.editor.hasPhysicalRouteContinuation, isFalse);
      expect(fixture.editor.routeSegments, isEmpty);

      expect(committed.segments[0].surface, fixture.canonicalLowerCeiling);
      expect(committed.segments[1].surface, fixture.canonicalLowerCeiling);
      expect(committed.segments[2].surface, fixture.canonicalUpperFloor);
      for (final segment in committed.segments) {
        expect(segment.anchorIds, hasLength(segment.points.length));
        expect(segment.surface.wallIndex, isNull);
      }

      fixture.editor.p2.undo();
      expect(fixture.editor.p2.routes.single, same(original));
      expect(fixture.editor.p2.routes.single.penetrations, isEmpty);

      fixture.editor.p2.redo();
      expect(fixture.editor.p2.routes.single.id, 'C-103');
      expect(
        fixture.editor.p2.routes.single.penetrations.single.slabId,
        fixture.slabId,
      );
    },
  );
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
    final targetA = ElectricalComponentPlacement(
      id: 'target-a',
      type: ElectricalComponentType.socketOutlet,
      surface: canonicalLowerCeiling,
      position: const SurfacePointMm(900, 1200),
      label: 'Target A',
      ports: const [
        ElectricalPortDefinition(id: 'in', kind: ElectricalPortKind.powerIn),
      ],
    );
    final targetB = ElectricalComponentPlacement(
      id: 'target-b',
      type: ElectricalComponentType.socketOutlet,
      surface: canonicalUpperFloor,
      position: const SurfacePointMm(2400, 1200),
      label: 'Target B',
      ports: const [
        ElectricalPortDefinition(id: 'in', kind: ElectricalPortKind.powerIn),
      ],
    );
    editor.p2.history.replaceState(
      EditorP2State(components: [source, targetA, targetB]),
      clearHistory: true,
    );
    route = ElectricalCableRoute(
      id: 'C-103',
      source: const ElectricalEndpointRef(componentId: 'source', portId: 'out'),
      target: const ElectricalEndpointRef(componentId: 'target-a', portId: 'in'),
      segments: [
        ElectricalRouteSegment(
          surface: canonicalLowerCeiling,
          points: const [
            SurfacePointMm(300, 1200),
            SurfacePointMm(900, 1200),
          ],
          anchorIds: [
            RouteAnchorId('anchor-source'),
            RouteAnchorId('anchor-target-a'),
          ],
        ),
      ],
    );
    if (!editor.p2.commitPhysicalCableRoute(route)) {
      throw StateError('Fixture route must commit.');
    }
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

  late final BuildingLevel legacyLower;
  late final BuildingLevel legacyUpper;
  late final ProjectStructureAuthoringSession session;
  late final EditorBuildingWorkspace workspace;
  late final CanonicalEditorRuntimeCutoverCoordinator coordinator;
  late final ElectricalCableRoute route;

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
