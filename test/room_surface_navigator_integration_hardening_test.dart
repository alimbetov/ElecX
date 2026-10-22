import 'dart:math';

import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_structure_authoring.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/features/editor/canonical_editor_production_runtime.dart';
import 'package:elecx/src/features/editor/canonical_editor_workspace_adapter.dart';
import 'package:elecx/src/features/editor/editor_building_workspace.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:elecx/src/features/editor/editor_project_document.dart';
import 'package:elecx/src/features/editor/project_persistence_metadata.dart';
import 'package:elecx/src/features/editor/room_surface_navigator.dart';
import 'package:elecx/src/features/editor/unified_workspace_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'local wall navigation preserves canonical project-tree location',
    (tester) async {
      _useSurface(tester, const Size(1440, 900));
      final fixture = _fixture();
      final navigationBefore = fixture.session.navigation;
      final versionBefore = fixture.session.project.version;

      await _pumpScreen(tester, fixture);
      await tester.tap(find.byKey(const ValueKey('room-surface-wall-next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('room-surface-wall-next')));
      await tester.pumpAndSettle();

      expect(fixture.session.navigation, same(navigationBefore));
      expect(fixture.session.project.version, versionBefore);
      expect(find.text('Current surface: Wall 2'), findsOneWidget);
    },
  );

  testWidgets(
    'switching canonical Room rebuilds the single local surface projection',
    (tester) async {
      _useSurface(tester, const Size(1440, 900));
      final fixture = _fixture();

      await _pumpScreen(tester, fixture);
      expect(find.byType(RoomSurfaceNavigator), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'Room surface preview, Plan, canonical room ${fixture.roomId.value}',
        ),
        findsOneWidget,
      );

      final corridorNode = find.byKey(
        ValueKey('project-node-space-${fixture.corridorId.value}'),
      );
      await tester.ensureVisible(corridorNode);
      await tester.pumpAndSettle();
      await tester.tap(corridorNode);
      await tester.pumpAndSettle();

      expect(fixture.session.navigation.selectedSpaceId, fixture.corridorId);
      expect(find.byType(RoomSurfaceNavigator), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'Room surface preview, Plan, canonical room ${fixture.corridorId.value}',
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          'Room surface preview, Plan, canonical room ${fixture.roomId.value}',
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'Tab reaches Room Surface Navigator and Space activates focused surface',
    (tester) async {
      _useSurface(tester, const Size(1440, 900));
      final fixture = _fixture();

      await _pumpScreen(tester, fixture);

      var floorFocused = false;
      for (var i = 0; i < 80 && !floorFocused; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        floorFocused = _focusIsInsideKey(
          const ValueKey('room-surface-floor'),
        );
      }

      expect(floorFocused, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();

      expect(find.text('Current surface: Floor'), findsOneWidget);
      expect(fixture.session.navigation.selectedSpaceId, fixture.roomId);
    },
  );

  testWidgets(
    'compact drawer uses the same Room Surface Navigator selection semantics',
    (tester) async {
      _useSurface(tester, const Size(600, 900));
      final fixture = _fixture();

      await _pumpScreen(tester, fixture);
      expect(find.byType(RoomSurfaceNavigator), findsNothing);

      final scaffold = tester.state<ScaffoldState>(find.byType(Scaffold).first);
      scaffold.openDrawer();
      await tester.pumpAndSettle();

      expect(find.byType(RoomSurfaceNavigator), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('room-surface-ceiling')));
      await tester.pumpAndSettle();

      expect(find.text('Current surface: Ceiling'), findsOneWidget);
      expect(fixture.session.navigation.selectedSpaceId, fixture.roomId);
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

bool _focusIsInsideKey(Key key) {
  Element? current = FocusManager.instance.primaryFocus?.context as Element?;
  while (current != null) {
    if (current.widget.key == key) return true;
    Element? parent;
    current.visitAncestorElements((ancestor) {
      parent = ancestor;
      return false;
    });
    current = parent;
  }
  return false;
}

void _useSurface(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
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
    required this.roomId,
    required this.corridorId,
  });

  final EditorProjectDocument document;
  final _MemoryProjectStore store;
  final ProjectStructureAuthoringSession session;
  final CanonicalEditorResolvedRuntime runtime;
  final SpaceId roomId;
  final SpaceId corridorId;
}

_Fixture _fixture() {
  const projectId = 'p5e-hardening';
  final timestamp = DateTime.utc(2026, 10, 21, 20);
  final metadata = EditorProjectMetadata(
    projectId: projectId,
    projectName: 'P5E Hardening',
    createdAt: timestamp,
    updatedAt: timestamp,
  );

  final legacyController = EditorController.demo();
  final legacyWorkspace = EditorBuildingWorkspace.blank(
    legacyController,
    projectId: projectId,
    projectName: metadata.projectName,
  );
  final document = EditorProjectDocument.capture(
    legacyWorkspace,
    metadata: metadata,
  );
  legacyWorkspace.dispose();
  legacyController.disposeP2State();
  legacyController.dispose();

  final siteId = SiteId('canonical-site');
  final buildingId = BuildingId('canonical-building');
  final levelId = LevelId('canonical-level');
  final roomId = SpaceId('canonical-room-101');
  final corridorId = SpaceId('canonical-corridor-1');
  final project = ProjectAggregateRoot(
    id: ProjectId(projectId),
    siteId: siteId,
    version: LocalProjectVersion(0),
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
          spaceIds: <SpaceId>[roomId, corridorId],
        ),
      },
      spaces: <SpaceId, ProjectSpaceEntity>{
        roomId: ProjectSpaceEntity(
          id: roomId,
          levelId: levelId,
          name: 'Room 101',
        ),
        corridorId: ProjectSpaceEntity(
          id: corridorId,
          levelId: levelId,
          name: 'Corridor',
        ),
      },
    ),
  );
  final navigation = ProjectNavigationState.restore(
    project,
    activeBuildingId: buildingId,
    activeLevelId: levelId,
    selectedSpaceId: roomId,
  );
  final session = ProjectStructureAuthoringSession(
    mutations: ProjectMutationSession(project),
    idFactory: SecureRandomEntityIdFactory(random: Random(219)),
    navigation: navigation,
  );
  final binding = CanonicalEditorWorkspaceBinding(
    buildingId: buildingId,
    legacyBuildingId: 'building-$projectId',
    legacyLevelIds: <LevelId, String>{levelId: 'level-1'},
    legacySpaceIds: <SpaceId, String>{
      roomId: 'room-101',
      corridorId: 'corridor-1',
    },
  );
  final runtime = CanonicalEditorResolvedRuntime(
    session: session,
    binding: binding,
    persistenceOwnerProjectId: ProjectId(projectId),
  );

  return _Fixture(
    document: document,
    store: _MemoryProjectStore(document),
    session: session,
    runtime: runtime,
    roomId: roomId,
    corridorId: corridorId,
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
