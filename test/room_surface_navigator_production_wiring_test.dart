import 'dart:math';

import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_structure_authoring.dart';
import 'package:elecx/src/application/project/wizard/project_wizard_mutation_port.dart';
import 'package:elecx/src/domain/boundary_edge_identity_registry.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_orientation.dart';
import 'package:elecx/src/features/editor/canonical_editor_production_runtime.dart';
import 'package:elecx/src/features/editor/canonical_editor_workspace_adapter.dart';
import 'package:elecx/src/features/editor/canonical_project_navigator.dart';
import 'package:elecx/src/features/editor/canonical_room_surface_runtime_registry.dart';
import 'package:elecx/src/features/editor/editor_building_workspace.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:elecx/src/features/editor/editor_project_document.dart';
import 'package:elecx/src/features/editor/project_persistence_metadata.dart';
import 'package:elecx/src/features/editor/room_surface_navigator.dart';
import 'package:elecx/src/features/editor/spatial_canvas.dart';
import 'package:elecx/src/features/editor/surface_canvas.dart';
import 'package:elecx/src/features/editor/unified_workspace_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'production navigator selects walls by stable BoundaryEdgeId',
    (tester) async {
      _useDesktopSurface(tester);
      final fixture = _fixture(selectRoom: true);

      await _pumpScreen(tester, fixture);

      expect(find.byType(CanonicalProjectNavigator), findsOneWidget);
      expect(find.byType(RoomSurfaceNavigator), findsOneWidget);
      expect(find.byType(SpatialCanvas), findsOneWidget);
      expect(find.text('Saved'), findsOneWidget);

      final controller = _navigatorController(tester);
      final initial = CanonicalRoomSurfaceRuntimeRegistry.resolve(
        controller,
        fixture.spaceId,
      );
      expect(initial, isNotNull);
      expect(initial!.projection.edgeIdAtOrdinal(0), fixture.edgeIds[0]);

      await tester.tap(find.byKey(const ValueKey('room-surface-floor')));
      await tester.pumpAndSettle();
      expect(find.byType(SurfaceCanvas), findsOneWidget);
      expect(find.text('Current surface: Floor'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('room-surface-wall-next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('room-surface-wall-next')));
      await tester.pumpAndSettle();

      expect(find.text('Current surface: Wall 2'), findsOneWidget);
      expect(
        CanonicalRoomSurfaceRuntimeRegistry.resolve(
          controller,
          fixture.spaceId,
        )?.current().boundaryEdgeId,
        fixture.edgeIds[1],
      );
      expect(fixture.session.navigation.selectedSpaceId, fixture.spaceId);
      expect(find.text('Saved'), findsOneWidget);
    },
  );

  testWidgets(
    'mouse button and keyboard wall actions converge on stable edge identity',
    (tester) async {
      _useDesktopSurface(tester);
      final fixture = _fixture(selectRoom: true);
      await _pumpScreen(tester, fixture);

      final controller = _navigatorController(tester);

      await tester.tap(find.byKey(const ValueKey('room-surface-wall-0')));
      await tester.pump();
      expect(
        CanonicalRoomSurfaceRuntimeRegistry.resolve(
          controller,
          fixture.spaceId,
        )?.current().boundaryEdgeId,
        fixture.edgeIds[0],
      );

      final focus = tester.widget<Focus>(
        find.byKey(const ValueKey('room-surface-mini-focus')),
      );
      focus.focusNode!.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(
        CanonicalRoomSurfaceRuntimeRegistry.resolve(
          controller,
          fixture.spaceId,
        )?.current().boundaryEdgeId,
        fixture.edgeIds[1],
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(
        CanonicalRoomSurfaceRuntimeRegistry.resolve(
          controller,
          fixture.spaceId,
        )?.current().boundaryEdgeId,
        fixture.edgeIds[0],
      );
    },
  );

  testWidgets(
    'canonical runtime capture carries BoundaryEdgeId and no wall ordinal',
    (tester) async {
      _useDesktopSurface(tester);
      final fixture = _fixture(selectRoom: true);
      await _pumpScreen(tester, fixture);

      final controller = _navigatorController(tester);
      await tester.tap(find.byKey(const ValueKey('room-surface-wall-0')));
      await tester.pump();

      final resume = CanonicalRoomSurfaceRuntimeRegistry.capture(controller);
      expect(resume, isNotNull);
      expect(resume!.spaceId, fixture.spaceId);
      expect(resume.boundaryEdgeId, fixture.edgeIds[0]);
      final json = resume.toJson();
      expect(json['boundaryEdgeId'], fixture.edgeIds[0].value);
      expect(json.containsKey('wallIndex'), isFalse);
    },
  );

  testWidgets(
    'collapse stays presentation-only and preserves canonical navigation',
    (tester) async {
      _useDesktopSurface(tester);
      final fixture = _fixture(selectRoom: true);
      final versionBefore = fixture.session.project.version;
      final navigationBefore = fixture.session.navigation;
      await _pumpScreen(tester, fixture);

      await tester.tap(find.byKey(const ValueKey('room-surface-collapse')));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('room-surface-mini-view')),
        findsNothing,
      );
      expect(fixture.session.project.version, versionBefore);
      expect(fixture.session.navigation, navigationBefore);
      expect(find.text('Saved'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('room-surface-collapse')));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('room-surface-mini-view')),
        findsOneWidget,
      );
      expect(fixture.session.project.version, versionBefore);
      expect(fixture.session.navigation, navigationBefore);
    },
  );

  testWidgets(
    'canonical level-only context keeps Room Surface Navigator hidden',
    (tester) async {
      _useDesktopSurface(tester);
      final fixture = _fixture(selectRoom: false);
      await _pumpScreen(tester, fixture);

      expect(find.byType(CanonicalProjectNavigator), findsOneWidget);
      expect(
        find.byKey(const ValueKey('room-surface-navigator')),
        findsNothing,
      );
    },
  );
}

Future<void> _pumpScreen(WidgetTester tester, _Fixture fixture) async {
  await tester.pumpWidget(
    MaterialApp(
      home: UnifiedWorkspaceEditorScreen(
        projectStore: fixture.store,
        initialDocument: fixture.document,
        canonicalRuntime: CanonicalEditorProductionRuntimeConfig(
          resolveRuntime: (_, __) => fixture.runtime,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

EditorController _navigatorController(WidgetTester tester) => tester
    .widget<RoomSurfaceNavigator>(find.byType(RoomSurfaceNavigator))
    .controller;

void _useDesktopSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

final class _Fixture {
  const _Fixture({
    required this.document,
    required this.store,
    required this.session,
    required this.runtime,
    required this.spaceId,
    required this.edgeIds,
  });

  final EditorProjectDocument document;
  final _MemoryProjectStore store;
  final ProjectStructureAuthoringSession session;
  final CanonicalEditorResolvedRuntime runtime;
  final SpaceId spaceId;
  final List<BoundaryEdgeId> edgeIds;
}

_Fixture _fixture({required bool selectRoom}) {
  const projectId = 'p5e-production';
  final timestamp = DateTime.utc(2026, 10, 21, 19);
  final metadata = EditorProjectMetadata(
    projectId: projectId,
    projectName: 'P5E Production',
    createdAt: timestamp,
    updatedAt: timestamp,
  );

  final legacyController = EditorController.demo();
  final legacyRoom = legacyController.level.spaces.firstWhere(
    (space) => space.id == 'room-101',
  );
  final legacyWorkspace = EditorBuildingWorkspace.blank(
    legacyController,
    projectId: projectId,
    projectName: metadata.projectName,
  );
  final document = EditorProjectDocument.capture(
    legacyWorkspace,
    metadata: metadata,
  );

  final siteId = SiteId('canonical-site');
  final buildingId = BuildingId('canonical-building');
  final levelId = LevelId('canonical-level');
  final spaceId = SpaceId('canonical-room-101');
  final points = <BoundaryPointMm>[
    for (final point in legacyRoom.boundary.vertices)
      BoundaryPointMm(xMm: point.x, yMm: point.y),
  ];
  final edgeIds = <BoundaryEdgeId>[
    for (var index = 0; index < points.length; index++)
      BoundaryEdgeId('p7a-production-edge-$index'),
  ];
  final edges = <BoundaryEdgeId, ProjectBoundaryEdge>{
    for (var index = 0; index < points.length; index++)
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

  final project = ProjectAggregateRoot(
    id: ProjectId(projectId),
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
          name: 'Floor 1',
          levelNumber: 1,
          elevationMm: 0,
          spaceIds: <SpaceId>[spaceId],
        ),
      },
      spaces: <SpaceId, ProjectSpaceEntity>{
        spaceId: ProjectSpaceEntity(
          id: spaceId,
          levelId: levelId,
          name: 'Room 101',
        ),
      },
      boundaries: boundaries,
    ),
  );
  final navigation = ProjectNavigationState.restore(
    project,
    activeBuildingId: buildingId,
    activeLevelId: levelId,
    selectedSpaceId: selectRoom ? spaceId : null,
  );
  final mutations = ProjectMutationSession(project);
  final idFactory = SecureRandomEntityIdFactory(random: Random(205));
  final session = ProjectStructureAuthoringSession(
    mutations: mutations,
    idFactory: idFactory,
    navigation: navigation,
  );
  final binding = CanonicalEditorWorkspaceBinding(
    buildingId: buildingId,
    legacyBuildingId: 'building-$projectId',
    legacyLevelIds: <LevelId, String>{levelId: 'level-1'},
    legacySpaceIds: <SpaceId, String>{spaceId: 'room-101'},
  );
  final runtime = CanonicalEditorResolvedRuntime(
    session: session,
    wizardMutations: SharedProjectWizardMutationPort(
      mutations: mutations,
      idFactory: idFactory,
    ),
    binding: binding,
    persistenceOwnerProjectId: ProjectId(projectId),
  );

  legacyWorkspace.dispose();
  legacyController.disposeP2State();
  legacyController.dispose();

  return _Fixture(
    document: document,
    store: _MemoryProjectStore(document),
    session: session,
    runtime: runtime,
    spaceId: spaceId,
    edgeIds: edgeIds,
  );
}

final class _MemoryProjectStore implements EditorProjectStore {
  _MemoryProjectStore(this.document);

  EditorProjectDocument? document;

  @override
  Future<EditorProjectDocument?> load(String projectId) async {
    final current = document;
    if (current == null || current.projectId != projectId) return null;
    return current;
  }

  @override
  Future<List<EditorProjectDocument>> list() async =>
      document == null ? const [] : <EditorProjectDocument>[document!];

  @override
  Future<void> save(EditorProjectDocument document) async {
    this.document = document;
  }
}
