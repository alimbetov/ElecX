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
import 'package:elecx/src/features/editor/project_compass_overlay.dart';
import 'package:elecx/src/features/editor/project_persistence_metadata.dart';
import 'package:elecx/src/features/editor/unified_icon_toolbar.dart';
import 'package:elecx/src/features/editor/unified_workspace_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'ownership publication failure preserves the committed canonical mutation',
    (tester) async {
      _useSurface(tester, const Size(1440, 900));
      final fixture = _fixture('publication-failure');
      var publicationAttempts = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: UnifiedWorkspaceEditorScreen(
            projectStore: fixture.store,
            initialDocument: fixture.document,
            canonicalRuntime: CanonicalEditorProductionRuntimeConfig(
              resolveRuntime: (_, __) => fixture.runtime,
              onProjectNorthCommitted: (_, __) {
                publicationAttempts++;
                throw StateError('simulated owner failure');
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('project-compass-toggle')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('project-compass-action')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('project-north-angle-input')),
        '32.5',
      );
      await tester.tap(find.byKey(const ValueKey('apply-project-north')));
      await tester.pumpAndSettle();

      expect(publicationAttempts, 1);
      expect(fixture.session.project.version.value, 1);
      expect(
        fixture.session.projectNorthEditing.currentProjectNorth?.degrees,
        32.5,
      );
      expect(fixture.mutations.undoDepth, 1);
      expect(
        find.textContaining('persistence owner не подтвердил владение'),
        findsOneWidget,
      );
      expect(
        find.text('Saved'),
        findsOneWidget,
        reason:
            'canonical publication failure must not dirty legacy persistence',
      );

      final undone = fixture.mutations.undo(fixture.session.project.version);
      expect(undone, isNotNull);
      expect(fixture.session.project.engineeringMetadata.projectNorth, isNull);
    },
  );

  testWidgets('compass toggle is keyboard reachable and Space activates it',
      (tester) async {
    _useSurface(tester, const Size(1440, 900));
    final fixture = _fixture('keyboard-toggle');

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

    expect(find.byType(ProjectCompassOverlay), findsNothing);

    var compassFocused = false;
    for (var i = 0; i < 30 && !compassFocused; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      compassFocused = _focusIsInsideKey(
        const ValueKey('project-compass-toggle'),
      );
    }

    expect(compassFocused, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();

    expect(find.byType(ProjectCompassOverlay), findsOneWidget);
    expect(find.bySemanticsLabel('Compass'), findsOneWidget);
  });

  testWidgets('compass overlay stays clear of primary authoring toolbar',
      (tester) async {
    for (final surface in <Size>[
      const Size(1440, 900),
      const Size(820, 900),
      const Size(600, 900),
    ]) {
      _setSurface(tester, surface);
      final fixture = _fixture('layout-${surface.width.toInt()}');

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
      await tester.tap(find.byKey(const ValueKey('project-compass-toggle')));
      await tester.pumpAndSettle();

      final compassRect = tester.getRect(find.byType(ProjectCompassOverlay));
      final toolbarRect = tester.getRect(find.byType(UnifiedEditorIconToolbar));

      expect(
        compassRect.overlaps(toolbarRect),
        isFalse,
        reason: 'surface $surface must keep the compass out of toolbar bounds',
      );
      expect(compassRect.top, greaterThanOrEqualTo(toolbarRect.bottom));
      expect(compassRect.right, lessThanOrEqualTo(surface.width));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });
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
  _setSurface(tester, size);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void _setSurface(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
}

final class _Fixture {
  const _Fixture({
    required this.document,
    required this.store,
    required this.mutations,
    required this.session,
    required this.runtime,
  });

  final EditorProjectDocument document;
  final _MemoryProjectStore store;
  final ProjectMutationSession mutations;
  final ProjectStructureAuthoringSession session;
  final CanonicalEditorResolvedRuntime runtime;
}

_Fixture _fixture(String projectId) {
  final timestamp = DateTime.utc(2026, 10, 21, 18);
  final metadata = EditorProjectMetadata(
    projectId: projectId,
    projectName: 'P5D hardening',
    createdAt: timestamp,
    updatedAt: timestamp,
  );

  final legacyController = EditorController.blank(
    levelId: 'level-$projectId-1',
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
  legacyWorkspace.dispose();
  legacyController.disposeP2State();
  legacyController.dispose();

  final project = _canonicalProject(projectId);
  final mutations = ProjectMutationSession(project);
  final session = ProjectStructureAuthoringSession(
    mutations: mutations,
    idFactory: SecureRandomEntityIdFactory(random: Random(1917)),
  );
  final binding = CanonicalEditorWorkspaceBinding(
    buildingId: BuildingId('canonical-building'),
    legacyBuildingId: 'building-$projectId',
    legacyLevelIds: <LevelId, String>{
      LevelId('canonical-level'): 'level-$projectId-1',
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
    mutations: mutations,
    session: session,
    runtime: runtime,
  );
}

ProjectAggregateRoot _canonicalProject(String projectId) {
  final siteId = SiteId('canonical-site');
  final buildingId = BuildingId('canonical-building');
  final levelId = LevelId('canonical-level');
  return ProjectAggregateRoot(
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
        ),
      },
    ),
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
