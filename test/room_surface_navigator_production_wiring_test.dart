import 'dart:math';

import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_structure_authoring.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/features/editor/canonical_editor_production_runtime.dart';
import 'package:elecx/src/features/editor/canonical_editor_workspace_adapter.dart';
import 'package:elecx/src/features/editor/canonical_project_navigator.dart';
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
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'canonical selected room renders one production Room Surface Navigator',
    (tester) async {
      _useDesktopSurface(tester);
      final fixture = _fixture(selectRoom: true);

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

      expect(find.byType(CanonicalProjectNavigator), findsOneWidget);
      expect(find.byType(RoomSurfaceNavigator), findsOneWidget);
      expect(
        find.byKey(const ValueKey('room-surface-navigator')),
        findsOneWidget,
      );
      expect(find.byType(SpatialCanvas), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('room-surface-floor')));
      await tester.pumpAndSettle();

      expect(find.byType(SurfaceCanvas), findsOneWidget);
      expect(find.text('Current surface: Floor'), findsOneWidget);
      expect(fixture.session.navigation.selectedSpaceId, fixture.spaceId);

      await tester.tap(find.byKey(const ValueKey('room-surface-plan')));
      await tester.pumpAndSettle();

      expect(find.byType(SpatialCanvas), findsOneWidget);
      expect(find.text('Current surface: Plan'), findsOneWidget);
    },
  );

  testWidgets(
    'collapse stays presentation-only and preserves canonical navigation',
    (tester) async {
      _useDesktopSurface(tester);
      final fixture = _fixture(selectRoom: true);
      final versionBefore = fixture.session.project.version;
      final navigationBefore = fixture.session.navigation;

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

      await tester.tap(find.byKey(const ValueKey('room-surface-collapse')));
      await tester.pump();

      expect(find.byType(RoomSurfaceNavigator), findsOneWidget);
      expect(
          find.byKey(const ValueKey('room-surface-mini-view')), findsNothing);
      expect(fixture.session.project.version, versionBefore);
      expect(fixture.session.navigation, navigationBefore);

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

    expect(find.byType(CanonicalProjectNavigator), findsOneWidget);
    expect(
      find.byKey(const ValueKey('room-surface-navigator')),
      findsNothing,
    );
  });
}

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
  });

  final EditorProjectDocument document;
  final _MemoryProjectStore store;
  final ProjectStructureAuthoringSession session;
  final CanonicalEditorResolvedRuntime runtime;
  final SpaceId spaceId;
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
  final spaceId = SpaceId('canonical-room-101');
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
    ),
  );
  final navigation = ProjectNavigationState.restore(
    project,
    activeBuildingId: buildingId,
    activeLevelId: levelId,
    selectedSpaceId: selectRoom ? spaceId : null,
  );
  final session = ProjectStructureAuthoringSession(
    mutations: ProjectMutationSession(project),
    idFactory: SecureRandomEntityIdFactory(random: Random(205)),
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
    binding: binding,
    persistenceOwnerProjectId: ProjectId(projectId),
  );
  return _Fixture(
    document: document,
    store: _MemoryProjectStore(document),
    session: session,
    runtime: runtime,
    spaceId: spaceId,
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
