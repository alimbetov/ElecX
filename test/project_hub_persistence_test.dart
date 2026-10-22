import 'package:elecx/src/features/editor/editor_building_workspace.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:elecx/src/features/editor/editor_project_document.dart';
import 'package:elecx/src/features/editor/unified_workspace_editor_screen.dart';
import 'package:elecx/src/features/projects/project_hub_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final class _HubMemoryStore implements EditorProjectStore {
  _HubMemoryStore(this.documents);

  final List<EditorProjectDocument> documents;

  @override
  Future<EditorProjectDocument?> load(String projectId) async {
    for (final document in documents) {
      if (document.projectId == projectId) return document;
    }
    return null;
  }

  @override
  Future<List<EditorProjectDocument>> list() async =>
      List<EditorProjectDocument>.unmodifiable(documents);

  @override
  Future<void> save(EditorProjectDocument document) async {
    final index =
        documents.indexWhere((item) => item.projectId == document.projectId);
    if (index < 0) {
      documents.add(document);
    } else {
      documents[index] = document;
    }
  }
}

void main() {
  testWidgets('project hub discovers persisted project and reopens editor',
      (tester) async {
    final editor = EditorController.demo();
    final workspace = EditorBuildingWorkspace.demo(editor);
    final document = EditorProjectDocument.capture(workspace);
    editor.disposeP2State();
    workspace.dispose();
    editor.dispose();
    final store = _HubMemoryStore([document]);

    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: ProjectHubScreen(projectStore: store)),
    );
    await tester.pumpAndSettle();

    expect(find.text(document.projectName), findsNWidgets(2));
    expect(
      find.byKey(ValueKey('continue-project-${document.projectId}')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey('saved-project-${document.projectId}')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(ValueKey('continue-project-${document.projectId}')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(UnifiedWorkspaceEditorScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('project-save')), findsOneWidget);
  });

  testWidgets('hub creates independent project identities', (tester) async {
    final store = _HubMemoryStore([]);
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: ProjectHubScreen(projectStore: store)),
    );
    await tester.pumpAndSettle();

    Future<void> createAndSave(String name) async {
      await tester.tap(find.byKey(const ValueKey('create-project')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('new-project-name')), name);
      await tester.tap(find.byKey(const ValueKey('create-project-confirm')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('project-save')));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
    }

    await createAndSave('Проект 1');
    await createAndSave('Проект 2');

    expect(store.documents, hasLength(2));
    expect(store.documents[0].projectId, isNot(store.documents[1].projectId));
    expect(store.documents.map((item) => item.projectName),
        containsAll(<String>['Проект 1', 'Проект 2']));
  });
}
