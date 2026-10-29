import 'package:elecx/src/features/editor/editor_building_workspace.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_project_document.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:elecx/src/features/editor/editor_project_recovery.dart';
import 'package:elecx/src/features/editor/project_persistence_metadata.dart';
import 'package:elecx/src/features/editor/unified_workspace_editor_screen.dart';
import 'package:elecx/src/features/projects/project_hub_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final class _MemoryProjectStore implements EditorProjectStore {
  final Map<String, EditorProjectDocument> documents = {};

  @override
  Future<void> save(EditorProjectDocument document) async {
    documents[document.projectId] = document;
  }

  @override
  Future<EditorProjectDocument?> load(String projectId) async =>
      documents[projectId];

  @override
  Future<List<EditorProjectDocument>> list() async =>
      List.unmodifiable(documents.values);
}

final class _MemoryRecoveryStore implements EditorProjectRecoveryStore {
  final Map<String, EditorProjectRecoverySnapshot> snapshots = {};

  @override
  Future<void> save(EditorProjectRecoverySnapshot snapshot) async {
    snapshots[snapshot.projectId] = snapshot;
  }

  @override
  Future<EditorProjectRecoverySnapshot?> load(String projectId) async =>
      snapshots[projectId];

  @override
  Future<List<EditorProjectRecoverySnapshot>> list() async =>
      List.unmodifiable(snapshots.values);

  @override
  Future<void> discard(String projectId) async {
    snapshots.remove(projectId);
  }
}

EditorProjectRecoverySnapshot _orphanRecovery() {
  final controller = EditorController.demo();
  final workspace = EditorBuildingWorkspace.demo(controller);
  final metadata = EditorProjectMetadata.create(
    projectName: 'Несохранённый проект',
    now: DateTime.utc(2026, 10, 20, 10),
  );
  final document = EditorProjectDocument.capture(workspace, metadata: metadata);
  workspace.dispose();
  controller.disposeP2State();
  controller.dispose();
  return EditorProjectRecoverySnapshot(
    capturedAt: DateTime.utc(2026, 10, 20, 10, 5),
    revision: 4,
    document: document,
  );
}

void main() {
  testWidgets(
    'hub exposes orphan recovery and opens it as Modified until explicit Save',
    (tester) async {
      final projects = _MemoryProjectStore();
      final recoveryStore = _MemoryRecoveryStore();
      final recovery = _orphanRecovery();
      recoveryStore.snapshots[recovery.projectId] = recovery;

      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: ProjectHubScreen(
            projectStore: projects,
            recoveryStore: recoveryStore,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Аварийное восстановление'), findsOneWidget);
      expect(
        find.byKey(ValueKey('recovery-project-${recovery.projectId}')),
        findsOneWidget,
      );
      expect(projects.documents, isEmpty);

      await tester.tap(
        find.byKey(ValueKey('recovery-project-${recovery.projectId}')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(UnifiedWorkspaceEditorScreen), findsOneWidget);
      expect(find.text('Modified'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('project-recovery-dialog')),
        findsNothing,
      );

      await tester.tap(find.byKey(const ValueKey('project-save')));
      await tester.pumpAndSettle();
      expect(find.text('Saved'), findsOneWidget);
      expect(projects.documents, hasLength(1));
      expect(recoveryStore.snapshots, isEmpty);
    },
  );

  testWidgets('hub can discard orphan recovery without creating a project', (
    tester,
  ) async {
    final projects = _MemoryProjectStore();
    final recoveryStore = _MemoryRecoveryStore();
    final recovery = _orphanRecovery();
    recoveryStore.snapshots[recovery.projectId] = recovery;

    await tester.pumpWidget(
      MaterialApp(
        home: ProjectHubScreen(
          projectStore: projects,
          recoveryStore: recoveryStore,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(ValueKey('discard-recovery-${recovery.projectId}')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('discard-recovery-confirmation-dialog')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('confirm-discard-recovery')),
    );
    await tester.pumpAndSettle();
    expect(recoveryStore.snapshots, isEmpty);
    expect(find.text('Аварийное восстановление'), findsNothing);
    expect(projects.documents, isEmpty);
  });
}
