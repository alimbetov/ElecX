import 'dart:math';

import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_structure_authoring.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_orientation.dart';
import 'package:elecx/src/features/editor/canonical_editor_production_runtime.dart';
import 'package:elecx/src/features/editor/canonical_editor_workspace_adapter.dart';
import 'package:elecx/src/features/editor/editor_building_workspace.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:elecx/src/features/editor/editor_project_document.dart';
import 'package:elecx/src/features/editor/project_compass_overlay.dart';
import 'package:elecx/src/features/editor/project_persistence_metadata.dart';
import 'package:elecx/src/features/editor/unified_workspace_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'production compass toggles opt-in and commits through canonical owner',
    (tester) async {
      _useDesktopSurface(tester);
      final fixture = _fixture(projectId: 'p5d-screen');
      var canonicalOwnershipReceipts = 0;
      var featureHookCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: UnifiedWorkspaceEditorScreen(
            projectStore: fixture.store,
            initialDocument: fixture.document,
            canonicalRuntime: CanonicalEditorProductionRuntimeConfig(
              resolveRuntime: (_, __) => fixture.runtime,
              onCanonicalMutationCommitted: (session, result) {
                canonicalOwnershipReceipts++;
                expect(session.project, same(result.project));
                return const CanonicalAuthoringOwnershipReceipt.accepted();
              },
              onProjectNorthCommitted: (_, __) {
                featureHookCalls++;
                return const CanonicalAuthoringOwnershipReceipt.accepted();
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ProjectCompassOverlay), findsNothing);
      expect(find.text('Saved'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('project-compass-toggle')));
      await tester.pumpAndSettle();

      expect(find.byType(ProjectCompassOverlay), findsOneWidget);
      expect(
        find.bySemanticsLabel('Compass, Project North not set'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('project-compass-action')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('project-compass-action')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('project-north-dialog')),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const ValueKey('project-north-angle-input')),
        '32.5',
      );
      await tester.tap(find.byKey(const ValueKey('apply-project-north')));
      await tester.pumpAndSettle();

      expect(canonicalOwnershipReceipts, 1);
      expect(featureHookCalls, 1);
      expect(
        fixture.session.project.engineeringMetadata.projectNorth?.degrees,
        32.5,
      );
      expect(
        find.bySemanticsLabel(
          'Compass, Project North 32.5 degrees clockwise from project up',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Saved'),
        findsOneWidget,
        reason: 'canonical Project North must not dirty legacy editor state',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'project identity mismatch keeps compass projection fail closed',
    (tester) async {
      _useDesktopSurface(tester);
      final fixture = _fixture(
        projectId: 'screen-project',
        canonicalProjectId: 'different-canonical-project',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: UnifiedWorkspaceEditorScreen(
            projectStore: fixture.store,
            initialDocument: fixture.document,
            canonicalRuntime: CanonicalEditorProductionRuntimeConfig(
              resolveRuntime: (_, __) => fixture.runtime,
              onCanonicalMutationCommitted: (_, __) =>
                  const CanonicalAuthoringOwnershipReceipt.accepted(),
              onProjectNorthCommitted: (_, __) =>
                  const CanonicalAuthoringOwnershipReceipt.accepted(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('project-compass-toggle')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('project-compass-paint')), findsNothing);
      expect(
        find.byKey(const ValueKey('project-compass-action')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('persistence owner mismatch keeps canonical compass read only', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    final fixture = _fixture(
      projectId: 'owner-mismatch',
      persistenceOwnerProjectId: 'another-owner',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: UnifiedWorkspaceEditorScreen(
          projectStore: fixture.store,
          initialDocument: fixture.document,
          canonicalRuntime: CanonicalEditorProductionRuntimeConfig(
            resolveRuntime: (_, __) => fixture.runtime,
            onCanonicalMutationCommitted: (_, __) =>
                const CanonicalAuthoringOwnershipReceipt.accepted(),
            onProjectNorthCommitted: (_, __) =>
                const CanonicalAuthoringOwnershipReceipt.accepted(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('project-compass-toggle')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('project-compass-paint')),
      findsOneWidget,
      reason: 'ownership controls editing, not read-only projection',
    );
    expect(
      find.byKey(const ValueKey('project-compass-read-only')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('project-compass-action')), findsNothing);
    expect(fixture.session.project.version.value, 0);
  });

  testWidgets('missing ownership callback keeps canonical compass read only', (
    tester,
  ) async {
    _useDesktopSurface(tester);
    final fixture = _fixture(projectId: 'no-owner-callback');

    await tester.pumpWidget(
      MaterialApp(
        home: UnifiedWorkspaceEditorScreen(
          projectStore: fixture.store,
          initialDocument: fixture.document,
          canonicalRuntime: CanonicalEditorProductionRuntimeConfig(
            resolveRuntime: (_, __) => fixture.runtime,
            onProjectNorthCommitted: (_, __) =>
                const CanonicalAuthoringOwnershipReceipt.accepted(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('project-compass-toggle')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('project-compass-read-only')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('project-compass-action')), findsNothing);
  });

  testWidgets(
    'same Project North value is a no-op and does not transfer ownership',
    (tester) async {
      _useDesktopSurface(tester);
      final fixture = _fixture(projectId: 'north-no-op');
      expect(
        fixture.session.projectNorthEditing.setProjectNorth(
          ProjectEngineeringNorth.fromDegrees(32.5),
        ),
        isNotNull,
      );
      final versionBefore = fixture.session.project.version;
      var canonicalOwnershipReceipts = 0;
      var featureHookCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: UnifiedWorkspaceEditorScreen(
            projectStore: fixture.store,
            initialDocument: fixture.document,
            canonicalRuntime: CanonicalEditorProductionRuntimeConfig(
              resolveRuntime: (_, __) => fixture.runtime,
              onCanonicalMutationCommitted: (_, __) {
                canonicalOwnershipReceipts++;
                return const CanonicalAuthoringOwnershipReceipt.accepted();
              },
              onProjectNorthCommitted: (_, __) {
                featureHookCalls++;
                return const CanonicalAuthoringOwnershipReceipt.accepted();
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
        '392.5',
      );
      await tester.tap(find.byKey(const ValueKey('apply-project-north')));
      await tester.pumpAndSettle();

      expect(canonicalOwnershipReceipts, 0);
      expect(featureHookCalls, 0);
      expect(fixture.session.project.version, versionBefore);
      expect(
        fixture.session.project.engineeringMetadata.projectNorth?.degrees,
        32.5,
      );
    },
  );

  testWidgets(
    'canonical version drift while dialog is open rejects stale edit',
    (tester) async {
      _useDesktopSurface(tester);
      final fixture = _fixture(projectId: 'north-stale-dialog');
      var canonicalOwnershipReceipts = 0;
      var featureHookCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: UnifiedWorkspaceEditorScreen(
            projectStore: fixture.store,
            initialDocument: fixture.document,
            canonicalRuntime: CanonicalEditorProductionRuntimeConfig(
              resolveRuntime: (_, __) => fixture.runtime,
              onCanonicalMutationCommitted: (_, __) {
                canonicalOwnershipReceipts++;
                return const CanonicalAuthoringOwnershipReceipt.accepted();
              },
              onProjectNorthCommitted: (_, __) {
                featureHookCalls++;
                return const CanonicalAuthoringOwnershipReceipt.accepted();
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

      expect(
        fixture.session.projectNorthEditing.setProjectNorth(
          ProjectEngineeringNorth.fromDegrees(15),
        ),
        isNotNull,
      );
      expect(fixture.session.project.version.value, 1);

      await tester.enterText(
        find.byKey(const ValueKey('project-north-angle-input')),
        '30',
      );
      await tester.tap(find.byKey(const ValueKey('apply-project-north')));
      await tester.pumpAndSettle();

      expect(canonicalOwnershipReceipts, 0);
      expect(featureHookCalls, 0);
      expect(fixture.session.project.version.value, 1);
      expect(
        fixture.session.project.engineeringMetadata.projectNorth?.degrees,
        15,
      );
      expect(
        find.textContaining('canonical edit context изменился'),
        findsOneWidget,
      );
    },
  );
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
  });

  final EditorProjectDocument document;
  final _MemoryProjectStore store;
  final ProjectStructureAuthoringSession session;
  final CanonicalEditorResolvedRuntime runtime;
}

_Fixture _fixture({
  required String projectId,
  String? canonicalProjectId,
  String? persistenceOwnerProjectId,
}) {
  final timestamp = DateTime.utc(2026, 10, 21, 16);
  final metadata = EditorProjectMetadata(
    projectId: projectId,
    projectName: 'P5D Compass',
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

  final canonicalId = canonicalProjectId ?? projectId;
  final project = _canonicalProject(canonicalId);
  final session = ProjectStructureAuthoringSession(
    mutations: ProjectMutationSession(project),
    idFactory: SecureRandomEntityIdFactory(random: Random(91)),
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
    persistenceOwnerProjectId: ProjectId(
      persistenceOwnerProjectId ?? canonicalId,
    ),
  );
  return _Fixture(
    document: document,
    store: _MemoryProjectStore(document),
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
