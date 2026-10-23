import 'dart:math';

import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_structure_authoring.dart';
import 'package:elecx/src/domain/boundary_edge_identity_registry.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/electrical_routing.dart';
import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_model.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/features/editor/canonical_editor_runtime_cutover.dart';
import 'package:elecx/src/features/editor/canonical_editor_workspace_adapter.dart';
import 'package:elecx/src/features/editor/canonical_room_surface_runtime_registry.dart';
import 'package:elecx/src/features/editor/editor_building_workspace.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:elecx/src/features/editor/physical_manual_cable_draft_persistence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('canonical continuation keeps SpaceId/BoundaryEdgeId and durable anchors',
      () {
    final fixture = _Fixture();
    addTearDown(fixture.dispose);

    expect(
      fixture.controller.beginPhysicalRouteContinuation(fixture.route.id),
      isTrue,
    );
    expect(fixture.controller.activeSurface?.isLegacyWall, isTrue);
    expect(fixture.controller.routeSegments.single.surface.isLegacyWall, isTrue);

    fixture.controller.surfaceTap(const SurfacePointMm(1200, 1000));
    fixture.controller.surfaceTap(const SurfacePointMm(1500, 1000));

    expect(
      fixture.controller.finishPhysicalRouteContinuation(
        resolveTransition: (_, __, ___, ____) => null,
      ),
      isTrue,
    );

    final committed = fixture.controller.p2.routes.single;
    expect(committed.id, 'C-103');
    expect(committed.segments, hasLength(2));
    for (final segment in committed.segments) {
      expect(segment.surface.spaceId, fixture.spaceId.value);
      expect(segment.surface.boundaryEdgeId, fixture.edgeId);
      expect(segment.surface.wallIndex, isNull);
      expect(segment.anchorIds, hasLength(segment.points.length));
    }
    expect(
      committed.segments.expand((segment) => segment.anchorIds).toSet(),
      hasLength(5),
    );
    expect(committed.target.componentId, 'target-b');
  });
}

final class _Fixture {
  _Fixture() {
    final polygon = MmPolygon.rectangle(
      const MmPoint(0, 0),
      const MmPoint(4000, 3000),
    );
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
      projectId: 'project',
      projectName: 'Canonical continuation identity',
    );
    controller.selectSpace(legacySpaceId);

    const points = <BoundaryPointMm>[
      BoundaryPointMm(xMm: 0, yMm: 0),
      BoundaryPointMm(xMm: 4000, yMm: 0),
      BoundaryPointMm(xMm: 4000, yMm: 3000),
      BoundaryPointMm(xMm: 0, yMm: 3000),
    ];
    final edgeIds = <BoundaryEdgeId>[
      edgeId,
      BoundaryEdgeId('edge-b'),
      BoundaryEdgeId('edge-c'),
      BoundaryEdgeId('edge-d'),
    ];
    final topology = SpaceBoundaryTopology(
      spaceId: spaceId,
      orderedEdgeIds: edgeIds,
      edges: {
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
    final identity = const BoundaryEdgeIdentityRegistry.empty()
        .registerActiveBoundaries(boundaries);
    final project = ProjectAggregateRoot(
      id: ProjectId('project'),
      siteId: siteId,
      version: LocalProjectVersion(0),
      engineeringMetadata: ProjectEngineeringMetadata(
        boundaryEdgeIdentityRegistry: identity,
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
    session = ProjectStructureAuthoringSession(
      mutations: ProjectMutationSession(project),
      idFactory: SecureRandomEntityIdFactory(random: Random(83)),
      navigation: ProjectNavigationState.restore(
        project,
        activeBuildingId: buildingId,
        activeLevelId: levelId,
        selectedSpaceId: spaceId,
      ),
    );
    coordinator = CanonicalEditorRuntimeCutoverCoordinator(
      session: session,
      adapter: CanonicalEditorWorkspaceAdapter(
        workspace: workspace,
        binding: CanonicalEditorWorkspaceBinding(
          buildingId: buildingId,
          legacyBuildingId: workspace.building.building.id,
          legacyLevelIds: {levelId: legacyLevelId},
          legacySpaceIds: {spaceId: legacySpaceId},
        ),
      ),
    );
    CanonicalRoomSurfaceRuntimeRegistry.attach(coordinator);

    final canonicalSurface =
        RoomSurfaceRef.wallByBoundaryEdge(spaceId.value, edgeId);
    final source = ElectricalComponentPlacement(
      id: 'source',
      type: ElectricalComponentType.powerSource,
      surface: canonicalSurface,
      position: const SurfacePointMm(100, 1000),
      label: 'Source',
      ports: const [
        ElectricalPortDefinition(
          id: 'out',
          kind: ElectricalPortKind.powerOut,
        ),
      ],
    );
    final targetA = ElectricalComponentPlacement(
      id: 'target-a',
      type: ElectricalComponentType.socketOutlet,
      surface: canonicalSurface,
      position: const SurfacePointMm(900, 1000),
      label: 'Target A',
      ports: const [
        ElectricalPortDefinition(
          id: 'in',
          kind: ElectricalPortKind.powerIn,
        ),
      ],
    );
    final targetB = ElectricalComponentPlacement(
      id: 'target-b',
      type: ElectricalComponentType.socketOutlet,
      surface: canonicalSurface,
      position: const SurfacePointMm(1500, 1000),
      label: 'Target B',
      ports: const [
        ElectricalPortDefinition(
          id: 'in',
          kind: ElectricalPortKind.powerIn,
        ),
      ],
    );
    controller.p2.history.replaceState(
      EditorP2State(components: [source, targetA, targetB]),
      clearHistory: true,
    );
    route = ElectricalCableRoute(
      id: 'C-103',
      source: const ElectricalEndpointRef(
        componentId: 'source',
        portId: 'out',
      ),
      target: const ElectricalEndpointRef(
        componentId: 'target-a',
        portId: 'in',
      ),
      segments: [
        ElectricalRouteSegment(
          surface: canonicalSurface,
          points: const [
            SurfacePointMm(100, 1000),
            SurfacePointMm(900, 1000),
          ],
          anchorIds: [
            RouteAnchorId('anchor-source'),
            RouteAnchorId('anchor-target-a'),
          ],
        ),
      ],
    );
    if (!controller.p2.commitPhysicalCableRoute(route)) {
      throw StateError('Fixture route must commit.');
    }
  }

  final SiteId siteId = SiteId('site');
  final BuildingId buildingId = BuildingId('building');
  final LevelId levelId = LevelId('level');
  final SpaceId spaceId = SpaceId('canonical-space');
  final BoundaryEdgeId edgeId = BoundaryEdgeId('edge-a');
  final String legacyLevelId = 'legacy-level';
  final String legacySpaceId = 'legacy-space';

  late final EditorController controller;
  late final EditorBuildingWorkspace workspace;
  late final ProjectStructureAuthoringSession session;
  late final CanonicalEditorRuntimeCutoverCoordinator coordinator;
  late final ElectricalCableRoute route;

  void dispose() {
    CanonicalRoomSurfaceRuntimeRegistry.detach(coordinator);
    workspace.dispose();
    controller.disposeP2State();
    controller.dispose();
  }
}
