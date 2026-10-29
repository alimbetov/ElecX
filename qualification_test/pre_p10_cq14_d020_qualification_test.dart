import 'dart:math';

import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_structure_authoring.dart';
import 'package:elecx/src/application/project/wizard/project_wizard_mutation_port.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_orientation.dart';
import 'package:elecx/src/features/editor/canonical_editor_production_runtime.dart';
import 'package:elecx/src/features/editor/canonical_editor_workspace_adapter.dart';
import 'package:elecx/src/features/editor/editor_project_document.dart';
import 'package:elecx/src/features/editor/editor_project_recovery.dart';
import 'package:elecx/src/features/editor/initial_editor_project_document.dart';
import 'package:elecx/src/features/editor/project_persistence_metadata.dart';
import 'package:elecx/src/features/editor/unified_workspace_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'PRE10-CQ14.1/4/5 D020 accepted commit Undo Redo advance recovery once each',
    (tester) async {
      _useDesktopSurface(tester);
      final fixture = _fixture('d020-replay-lifecycle');
      final recovery = _RecordingRecoveryStore();
      var ownerCalls = 0;
      var featureHookCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: UnifiedWorkspaceEditorScreen(
            projectStore: fixture.store,
            recoveryStore: recovery,
            autosaveDelay: const Duration(milliseconds: 10),
            initialDocument: fixture.document,
            canonicalRuntime: CanonicalEditorProductionRuntimeConfig(
              resolveRuntime: (_, __) => fixture.runtime,
              onCanonicalMutationCommitted: (_, __) {
                ownerCalls++;
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

      expect(find.text('Saved'), findsOneWidget);
      expect(recovery.revisions, isEmpty);
      expect(fixture.session.project.version.value, 0);

      await _setProjectNorth(tester, '32.5');
      await _pumpAutosave(tester);

      expect(ownerCalls, 1);
      expect(featureHookCalls, 1);
      expect(fixture.session.project.version.value, 1);
      expect(
        fixture.session.project.engineeringMetadata.projectNorth?.degrees,
        32.5,
      );
      expect(find.text('Modified'), findsOneWidget);
      expect(recovery.revisions, [1]);
      expect(recovery.snapshot?.revision, 1);

      final undo = find.widgetWithIcon(IconButton, Icons.undo);
      expect(undo, findsOneWidget);
      await tester.ensureVisible(undo);
      await tester.tap(undo);
      await tester.pumpAndSettle();
      await _pumpAutosave(tester);

      expect(ownerCalls, 2);
      expect(featureHookCalls, 1);
      expect(fixture.session.project.version.value, 2);
      expect(fixture.session.project.engineeringMetadata.projectNorth, isNull);
      expect(find.text('Modified'), findsOneWidget);
      expect(recovery.revisions, [1, 2]);
      expect(recovery.snapshot?.revision, 2);

      final redo = find.widgetWithIcon(IconButton, Icons.redo);
      expect(redo, findsOneWidget);
      await tester.ensureVisible(redo);
      await tester.tap(redo);
      await tester.pumpAndSettle();
      await _pumpAutosave(tester);

      expect(ownerCalls, 3);
      expect(featureHookCalls, 1);
      expect(fixture.session.project.version.value, 3);
      expect(
        fixture.session.project.engineeringMetadata.projectNorth?.degrees,
        32.5,
      );
      expect(find.text('Modified'), findsOneWidget);
      expect(recovery.revisions, [1, 2, 3]);
      expect(recovery.snapshot?.revision, 3);
    },
  );

  testWidgets('PRE10-CQ14.2 D020 canonical no-op creates no recovery revision',
      (tester) async {
    _useDesktopSurface(tester);
    final fixture = _fixture('d020-no-op');
    final seeded = fixture.session.projectNorthEditing.setProjectNorth(
      ProjectEngineeringNorth.fromDegrees(32.5),
    );
    expect(seeded, isNotNull);
    final canonicalVersionBefore = fixture.session.project.version;
    final recovery = _RecordingRecoveryStore();
    var ownerCalls = 0;
    var featureHookCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: UnifiedWorkspaceEditorScreen(
          projectStore: fixture.store,
          recoveryStore: recovery,
          autosaveDelay: const Duration(milliseconds: 10),
          initialDocument: fixture.document,
          canonicalRuntime: CanonicalEditorProductionRuntimeConfig(
            resolveRuntime: (_, __) => fixture.runtime,
            onCanonicalMutationCommitted: (_, __) {
              ownerCalls++;
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

    expect(find.text('Saved'), findsOneWidget);
    expect(recovery.revisions, isEmpty);

    await _setProjectNorth(tester, '392.5');
    await _pumpAutosave(tester);

    expect(ownerCalls, 0);
    expect(featureHookCalls, 0);
    expect(fixture.session.project.version, canonicalVersionBefore);
    expect(
      fixture.session.project.engineeringMetadata.projectNorth?.degrees,
      32.5,
    );
    expect(find.text('Saved'), findsOneWidget);
    expect(recovery.revisions, isEmpty);
    expect(recovery.snapshot, isNull);
  });

  testWidgets(
    'PRE10-CQ14.3 D020 post-commit owner failure stays dirty and recoverable',
    (tester) async {
      _useDesktopSurface(tester);
      const sentinel = 'CQ14_PRIVATE_OWNER_FAILURE';
      final fixture = _fixture('d020-owner-failure');
      final recovery = _RecordingRecoveryStore();
      var ownerCalls = 0;
      var featureHookCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: UnifiedWorkspaceEditorScreen(
            projectStore: fixture.store,
            recoveryStore: recovery,
            autosaveDelay: const Duration(milliseconds: 10),
            initialDocument: fixture.document,
            canonicalRuntime: CanonicalEditorProductionRuntimeConfig(
              resolveRuntime: (_, __) => fixture.runtime,
              onCanonicalMutationCommitted: (_, __) {
                ownerCalls++;
                throw StateError(sentinel);
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

      await _setProjectNorth(tester, '27.5');
      await _pumpAutosave(tester);

      expect(ownerCalls, 1);
      expect(featureHookCalls, 0);
      expect(fixture.session.project.version.value, 1);
      expect(
        fixture.session.project.engineeringMetadata.projectNorth?.degrees,
        27.5,
      );
      expect(find.text('Modified'), findsOneWidget);
      expect(recovery.revisions, [1]);
      expect(recovery.snapshot?.revision, 1);
      expect(find.textContaining('PX-EDITOR-004'), findsOneWidget);
      expect(find.textContaining(sentinel), findsNothing);
    },
  );
}

Future<void> _setProjectNorth(WidgetTester tester, String degrees) async {
  await tester.tap(find.byKey(const ValueKey('project-compass-toggle')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('project-compass-action')));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const ValueKey('project-north-angle-input')),
    degrees,
  );
  await tester.tap(find.byKey(const ValueKey('apply-project-north')));
  await tester.pumpAndSettle();
}

Future<void> _pumpAutosave(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 20));
  await tester.pumpAndSettle();
}

void _useDesktopSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

final class _RecordingRecoveryStore implements EditorProjectRecoveryStore {
  EditorProjectRecoverySnapshot? snapshot;
  final List<int> revisions = <int>[];

  @override
  Future<void> save(EditorProjectRecoverySnapshot snapshot) async {
    this.snapshot = snapshot;
    revisions.add(snapshot.revision);
  }

  @override
  Future<EditorProjectRecoverySnapshot?> load(String projectId) async =>
      snapshot?.projectId == projectId ? snapshot : null;

  @override
  Future<List<EditorProjectRecoverySnapshot>> list() async =>
      snapshot == null ? const [] : <EditorProjectRecoverySnapshot>[snapshot!];

  @override
  Future<void> discard(String projectId) async {
    if (snapshot?.projectId == projectId) snapshot = null;
  }
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

_Fixture _fixture(String projectId) {
  final metadata = EditorProjectMetadata.create(
    projectName: 'CQ14 $projectId',
    projectId: projectId,
    now: DateTime.utc(2026, 10, 29, 3),
  );
  final document = createInitialEditorProjectDocument(metadata);
  final siteId = SiteId('canonical-site');
  final buildingId = BuildingId('canonical-building');
  final levelId = LevelId('canonical-level');
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
        ),
      },
    ),
  );
  final mutations = ProjectMutationSession(project);
  final idFactory = SecureRandomEntityIdFactory(random: Random(1420));
  final session = ProjectStructureAuthoringSession(
    mutations: mutations,
    idFactory: idFactory,
  );
  final binding = CanonicalEditorWorkspaceBinding(
    buildingId: buildingId,
    legacyBuildingId: 'building-$projectId',
    legacyLevelIds: <LevelId, String>{levelId: 'level-$projectId-1'},
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

  return _Fixture(
    document: document,
    store: _MemoryProjectStore(document),
    session: session,
    runtime: runtime,
  );
}
